// supabase/functions/school-summary/index.ts
import { callQwenChatCompletion } from '../_shared/ai.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/cors.ts';
import { requireAuthenticatedUser } from '../_shared/supabase.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const auth = await requireAuthenticatedUser(req);
  if (!auth) {
    return errorResponse('unauthorized', 'Harus masuk terlebih dahulu.', 401);
  }

  const body = await req.json().catch(() => ({}));
  const periodRaw = typeof body?.period === 'string' ? body.period.trim() : '7d';
  const periodMatch = periodRaw.match(/^(\d+)d$/);
  const parsedDays = periodMatch ? Number.parseInt(periodMatch[1], 10) : 7;
  const periodDays = Number.isFinite(parsedDays) ? Math.min(Math.max(parsedDays, 1), 90) : 7;
  const period = `${periodDays}d`;

  const [{ data: profile }, { data: staffMembership }] = await Promise.all([
    auth.adminClient
      .from('profiles')
      .select('school_id, role')
      .eq('id', auth.user.id)
      .maybeSingle(),
    auth.adminClient
      .from('staff')
      .select('school_id')
      .eq('user_id', auth.user.id)
      .maybeSingle(),
  ]);

  const role = typeof profile?.role === 'string' ? profile.role : '';
  const isStaff = role === 'guru_bk' || role === 'wali_kelas' || Boolean(staffMembership?.school_id);
  if (!isStaff) {
    return errorResponse(
      'forbidden',
      'Hanya Guru BK atau Wali Kelas yang dapat mengakses ringkasan sekolah.',
      403
    );
  }

  let schoolId: string | null = staffMembership?.school_id ?? profile?.school_id ?? null;
  if (!schoolId) {
    const slug =
      typeof body?.school_slug === 'string' && body.school_slug !== 'private-mode'
        ? body.school_slug
        : 'sman1-nusantara';
    const { data: school } = await auth.adminClient
      .from('schools')
      .select('id')
      .eq('slug', slug)
      .maybeSingle();
    schoolId = school?.id ?? null;
  }

  if (!schoolId) {
    return jsonResponse({
      summary: {
        risk_cases: 0,
        online_cases: 0,
        total_reports: 0,
        top_location: 'Area Sekolah',
        summary_text: 'Data sekolah belum tersedia untuk mengagregasi tren laporan.',
        recommendation: 'Pastikan data sekolah awal sudah dijalankan di Supabase.',
        generated_at: new Date().toISOString(),
      },
    });
  }

  const lookbackStart = new Date(Date.now() - periodDays * 24 * 60 * 60 * 1000).toISOString();
  const { data: reports } = await auth.adminClient
    .from('reports')
    .select('types, location, status, occurred_at, created_at')
    .eq('school_id', schoolId)
    .gte('created_at', lookbackStart);

  const list = reports ?? [];
  const riskCases = list.filter((r: { types: string[] }) =>
    Array.isArray(r.types) && (r.types.includes('fisik') || r.types.includes('verbal'))
  ).length;
  const onlineCases = list.filter((r: { types: string[] }) =>
    Array.isArray(r.types) && r.types.includes('siber')
  ).length;

  const locationCounts: Record<string, number> = {};
  for (const r of list) {
    const loc = (r as { location?: string }).location || 'Lainnya';
    locationCounts[loc] = (locationCounts[loc] || 0) + 1;
  }
  const topLocation =
    Object.entries(locationCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'Area Sekolah';

  let summaryText =
    list.length === 0
      ? `Dalam ${periodDays} hari terakhir belum ada laporan masuk pada sekolah ini.`
      : `Dari ${list.length} laporan teragregasi ${periodDays} hari terakhir (tanpa identitas pelapor): ${riskCases} kasus fisik/verbal dan ${onlineCases} kasus siber, paling sering dilaporkan di area ${topLocation}.`;
  let recommendation =
    list.length === 0
      ? 'Pertahankan sosialisasi rutin pencegahan bullying dan pastikan akses pelaporan tetap mudah.'
      : `Prioritaskan pendampingan dan pemantauan guru piket di area ${topLocation} serta edukasi etika digital.`;

  if (list.length > 0) {
    const prompt = `Data agregat anonim ${periodDays} hari terakhir:
Total laporan: ${list.length}
Fisik/Verbal: ${riskCases}
Siber: ${onlineCases}
Lokasi terbanyak: ${JSON.stringify(locationCounts)}
Buat JSON valid murni (tanpa teks tambahan atau markdown) dengan key "summary_text" (maks 2 kalimat) dan "recommendation" (maks 1 rekomendasi aksi Guru BK). Jangan pernah menyebut identitas siswa.`;

    const aiResult = await callQwenChatCompletion({
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      maxTokens: 260,
      jsonMode: true,
    });

    if (aiResult.ok) {
      try {
        const jsonMatch = aiResult.content.match(/\{[\s\S]*\}/);
        const parsed = JSON.parse(jsonMatch ? jsonMatch[0] : aiResult.content);
        if (typeof parsed.summary_text === 'string' && parsed.summary_text.trim()) {
          summaryText = parsed.summary_text.trim();
        }
        if (typeof parsed.recommendation === 'string' && parsed.recommendation.trim()) {
          recommendation = parsed.recommendation.trim();
        }
      } catch (_) {
        // Keep aggregated summary counts above if JSON parse fails.
      }
    }
  }

  const generatedAt = new Date().toISOString();
  await auth.adminClient.from('school_summaries').upsert(
    {
      school_id: schoolId,
      period,
      risk_cases: riskCases,
      online_cases: onlineCases,
      summary_text: summaryText,
      recommendation,
      generated_at: generatedAt,
    },
    { onConflict: 'school_id,period' }
  );

  return jsonResponse({
    summary: {
      risk_cases: riskCases,
      online_cases: onlineCases,
      total_reports: list.length,
      top_location: topLocation,
      summary_text: summaryText,
      recommendation,
      generated_at: generatedAt,
    },
  });
});
