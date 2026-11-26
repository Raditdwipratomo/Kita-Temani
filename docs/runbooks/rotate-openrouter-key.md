# Runbook: Rotasi Kunci API OpenRouter (Model Qwen)

## 1. Kapan Dipakai
Ketika kunci `OPENROUTER_API_KEY` dicurigai bocor, kedaluwarsa, atau mencapai batas kuota/rotasi berkala.

## 2. Langkah Eksekusi
1. Buat API key baru di dashboard OpenRouter (<https://openrouter.ai/keys>).
2. Perbarui secret di Supabase Edge Functions:
   ```bash
   npx supabase secrets set OPENROUTER_API_KEY=<kunci_baru>
   ```
   *(Opsional) Untuk mengganti slug model Qwen tanpa mengubah kode:*
   ```bash
   npx supabase secrets set OPENROUTER_MODEL="qwen/qwen3-32b" OPENROUTER_VISION_MODEL="qwen/qwen3-vl-8b-instruct"
   ```
3. Verifikasi respons fungsi `curhai-chat` dan `analyze-image` menggunakan pengguna uji.
4. Cabut (*revoke*) kunci lama di dashboard OpenRouter.
