# Panduan Konfigurasi & Test Suite TestSprite — KitaTemani

Direktori ini berisi konfigurasi lengkap TestSprite yang disusun khusus untuk aplikasi **KitaTemani** (`Flutter Web + Supabase + CurhAI`) tanpa ketergantungan izin eksternal maupun kredensial tersimpan (*zero hardcoded secrets*).

---

## Struktur Berkas

| Berkas | Fungsi |
| --- | --- |
| `testsprite_tests/tmp/config.json` | Konfigurasi runtime TestSprite (`localPort: 8089`, `framework: flutter-web`, viewport `1280x800` & `390x844`, `credentialSource: env:TESTSPRITE_API_KEY`). |
| `testsprite_tests/tmp/code_summary.json` | Peta arsitektur aplikasi: 20 rute di `AppRouter`, 9 modul fitur dengan jalur berkas valid, 4 Edge Function Supabase, dan 8 RPC PostgreSQL. |
| `testsprite_tests/standard_prd.json` | PRD terstandarisasi mencakup kebutuhan fungsional, alur siswa & Guru BK, serta invarian privasi/keselamatan (Mode Samar, tanpa 112, kartu krisis tanpa maskot). |
| `testsprite_tests/testsprite_frontend_test_plan.json` | **18 skenario Frontend E2E** (`TC001`–`TC018`) lengkap dengan langkah `action` dan `assertion`. |
| `testsprite_tests/testsprite_backend_test_plan.json` | **8 skenario Backend / Supabase** (`BTC001`–`BTC008`) untuk Edge Functions & RPC RLS. |
| `testsprite_tests/mcp_testsprite.json` | Template konfigurasi MCP server (`@testsprite/testsprite-mcp@latest`) menggunakan `${TESTSPRITE_API_KEY}`. |
| `testsprite_tests/ci/testsprite.yml` | Template GitHub Actions CI siap salin ke `.github/workflows/testsprite.yml`. |
| `testsprite_tests/scripts/run_local_server.ps1` | Skrip PowerShell untuk membangun dan menyajikan `build/web` di `http://localhost:8089`. |

---

## Ringkasan 26 Test Case

- **Frontend (`TC001`–`TC018`)**:
  - **Onboarding & Auth**: `TC001` Splash & Onboarding 2 slide bermaskot owl, `TC002` Quick Login + Lengkapi Biodata, `TC003` Akun khusus Guru BK (`bk@kitatemani.id`).
  - **Beranda, Edukasi & Privasi**: `TC004` Beranda bersih tanpa data dummy + 4 kartu edukasi pastel, `TC005` Daily Mood Check-in (`Lagi cemas`) -> CurhAI, `TC006` Mode Samar menyembunyikan Mood Check-in & lencana OwlMascot.
  - **Pelaporan Anonim**: `TC007` Alur 3 langkah hingga kode tiket `KT-` + `scene_report_sent.svg`, `TC008` Guardrail draf & hapus link, `TC009` Laporanku (`scene_empty_reports.svg`), filter, dan Detail Laporan.
  - **CurhAI**: `TC010` Formatting Markdown bold tanpa `**` mentah & bebas jargon LLM, `TC011` Modal Latihan napas 1 menit, `TC012` Kartu Krisis merah tanpa maskot & reset obrolan.
  - **Darurat & Profil**: `TC013` Panic Button tahan 2s + masa tenggang 5s, `TC014` Panic Status pesan WA detail tanpa `112`/chip area, `TC015` Kontak Darurat (`scene_guardian_contacts.svg`, validasi, CRUD), `TC016` Profil statistik pastel + Izin Aplikasi aman `canPop == false`, `TC017` Kamera & preview foto bersih EXIF, `TC018` Audit responsif `1280x800` & `390x844`.
- **Backend (`BTC001`–`BTC008`)**:
  - `BTC001`–`BTC002` `curhai-chat` balasan normal & eskalasi `risk_level: "crisis"`.
  - `BTC003` `panic-notify`, `BTC004` `school-summary` teragregasi tanpa PII, `BTC005` `analyze-image`.
  - `BTC006`–`BTC008` Idempotensi RPC `submit_report`, kontrol peran RLS `advance_report_status`, dan `resolve_panic_event`.

---

## Cara Menjalankan Pengujian

### 1. Verifikasi Lokal Otomatis (Tanpa API Key)
Memvalidasi seluruh struktur JSON TestSprite, memastikan nol kredensial hardcoded, mengecek keberadaan berkas di `code_summary.json`, dan menjalankan skenario E2E Flutter (`KitaTemaniApp`):

```powershell
flutter test test/testsprite_suite_test.dart
```

### 2. Menjalankan di TestSprite Cloud / MCP CLI
1. Atur kredensial TestSprite satu kali:
   ```powershell
   npx @testsprite/testsprite-cli@latest setup
   # atau set environment variable:
   $env:TESTSPRITE_API_KEY = "ts_..."
   ```
2. Jalankan aplikasi web secara lokal:
   ```powershell
   .\testsprite_tests\scripts\run_local_server.ps1 -Rebuild
   ```
3. Cek kesehatan & jalankan sinkronisasi/eksekusi TestSprite:
   ```powershell
   npx @testsprite/testsprite-cli@latest doctor
   npx @testsprite/testsprite-cli@latest plan --file testsprite_tests/standard_prd.json
   npx @testsprite/testsprite-cli@latest apply
   npx @testsprite/testsprite-cli@latest run
   ```
4. *(Opsional)* Untuk mengaktifkan di IDE/MCP, gabungkan blok `mcpServers.TestSprite` dari `testsprite_tests/mcp_testsprite.json` ke konfigurasi MCP IDE Anda.
