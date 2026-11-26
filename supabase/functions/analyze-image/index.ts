// supabase/functions/analyze-image/index.ts
import { callQwenChatCompletion } from '../_shared/ai.ts';
import { corsHeaders, errorResponse, jsonResponse } from '../_shared/cors.ts';
import { requireAuthenticatedUser } from '../_shared/supabase.ts';

const DISCLAIMER =
  'Hasil analisis AI hanya indikasi awal untuk membantu dokumentasi dan bukan keputusan akhir.';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const auth = await requireAuthenticatedUser(req);
  if (!auth) {
    return errorResponse('unauthorized', 'Harus masuk terlebih dahulu.', 401);
  }

  const body = await req.json().catch(() => ({}));
  const imageBase64 = typeof body?.image_base64 === 'string' ? body.image_base64.trim() : '';

  if (imageBase64.length <= 50) {
    return errorResponse('bad_request', 'Gambar bukti tidak valid atau kosong.', 400);
  }

  const dataUrl = imageBase64.startsWith('data:')
    ? imageBase64
    : `data:image/jpeg;base64,${imageBase64}`;

  const aiResult = await callQwenChatCompletion({
    vision: true,
    temperature: 0.2,
    maxTokens: 250,
    messages: [
      {
        role: 'system',
        content:
          'Analisis singkat gambar situasi sekolah secara objektif dalam bahasa Indonesia. Sebutkan maksimal 2 indikasi visual jika ada konfrontasi, kerumunan intimidasi, atau teks penghinaan di chat. Jangan menyimpulkan secara final.',
      },
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Identifikasi indikasi awal perundungan pada gambar ini dalam 1-2 kalimat ringkas.' },
          { type: 'image_url', image_url: { url: dataUrl } },
        ],
      },
    ],
  });

  if (!aiResult.ok) {
    return errorResponse('ai_upstream_error', aiResult.message, aiResult.status);
  }

  return jsonResponse({
    indications: [aiResult.content],
    disclaimer: DISCLAIMER,
    model: aiResult.model,
  });
});
