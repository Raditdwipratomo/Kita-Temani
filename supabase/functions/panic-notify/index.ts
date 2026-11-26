// supabase/functions/panic-notify/index.ts
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
  const lat = typeof body?.lat === 'number' ? body.lat : null;
  const lng = typeof body?.lng === 'number' ? body.lng : null;
  const accuracy = typeof body?.accuracy === 'number' ? body.accuracy : null;
  const locationLabel =
    typeof body?.location_label === 'string' && body.location_label.trim().length > 0
      ? body.location_label.trim()
      : 'Lokasi perangkat';
  const messageText = typeof body?.message_text === 'string' ? body.message_text.trim() : '';
  const areaHint =
    typeof body?.area_hint === 'string' ? body.area_hint.trim().slice(0, 120) : '';
  const situationNote =
    typeof body?.situation_note === 'string' ? body.situation_note.trim().slice(0, 240) : '';
  const contactDeliveries = Array.isArray(body?.contact_deliveries) ? body.contact_deliveries : [];

  const { data: profile } = await auth.adminClient
    .from('profiles')
    .select('school_id, name, class_name, school_name')
    .eq('id', auth.user.id)
    .maybeSingle();

  let schoolId: string | null = profile?.school_id ?? null;
  if (!schoolId && typeof body?.school_slug === 'string' && body.school_slug !== 'private-mode') {
    const { data: schoolRow } = await auth.adminClient
      .from('schools')
      .select('id')
      .eq('slug', body.school_slug)
      .maybeSingle();
    schoolId = schoolRow?.id ?? null;
  }

  const studentName =
    (typeof body?.student_name === 'string' && body.student_name.trim()) ||
    profile?.name ||
    'Siswa KitaTemani';
  const className =
    (typeof body?.class_name === 'string' && body.class_name.trim()) ||
    profile?.class_name ||
    '';
  const schoolName = (
    (typeof body?.school_name === 'string' && body.school_name.trim()) ||
    profile?.school_name ||
    ''
  ).slice(0, 160);

  const { data: inserted, error: insertError } = await auth.adminClient
    .from('panic_events')
    .insert({
      user_id: auth.user.id,
      school_id: schoolId,
      student_name: studentName,
      class_name: className,
      school_name: schoolName,
      lat,
      lng,
      accuracy_m: accuracy,
      location_label: locationLabel,
      area_hint: areaHint,
      situation_note: situationNote,
      message_text: messageText,
      contact_deliveries: contactDeliveries,
      status: 'active',
    })
    .select('id, started_at')
    .single();

  if (insertError) {
    return errorResponse('db_error', insertError.message, 500);
  }

  if (schoolId) {
    const { data: counselors } = await auth.adminClient
      .from('staff')
      .select('user_id')
      .eq('school_id', schoolId);

    if (counselors && counselors.length > 0) {
      const displayClass = className ? ` (${className})` : '';
      const details: string[] = [];
      if (schoolName) details.push(`Sekolah: ${schoolName}`);
      if (situationNote) details.push(`Situasi: ${situationNote}`);
      if (areaHint) details.push(`Area: ${areaHint}`);
      details.push(`Lokasi: ${locationLabel}`);
      const notifBody = `${details.join(' · ')}. Segera cek Panel Guru BK.`;

      await auth.adminClient.from('app_notifications').insert(
        counselors.map((c: { user_id: string }) => ({
          user_id: c.user_id,
          title: `DARURAT SOS — ${studentName}${displayClass}`,
          body: notifBody,
          kind: 'panic_alert',
          ref_code: inserted.id,
        }))
      );
    }
  }

  return jsonResponse({
    ack: true,
    event_id: inserted.id,
    received_at: inserted.started_at,
    location: { lat, lng, accuracy, label: locationLabel },
  });
});
