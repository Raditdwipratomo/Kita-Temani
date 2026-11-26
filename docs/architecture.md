# Arsitektur Sistem KitaTemani

## 1. Konteks dan Tujuan

KitaTemani adalah aplikasi Android berbasis Flutter (Dart 3) untuk pencegahan, dokumentasi, dan pelaporan perundungan (*bullying*) di lingkungan SMP/SMA/SMK secara aman dan privat.

Tujuan arsitektur:
- **Privasi & Isolasi Akses (RLS)**: Laporan, lampiran bukti (EXIF dibersihkan), dan ruang diskusi hanya dapat diakses oleh pelapor dan Guru BK sekolah yang bersangkutan — tidak pernah terbuka ke siswa lain.
- **Ketahanan mode darurat (*offline-first panic*)**: Pengiriman SMS darurat langsung dari perangkat melalui `SmsChannel.kt` (`SmsManager`), lokasi GPS `Geolocator`, perekaman audio AAC (`record`), plus aksi manual **Chat WhatsApp** dan **Telepon Kontak Utama**.
- **Pemisahan lapisan (*Clean Architecture* ringan, *feature-first*)**: Setiap fitur (`auth`, `home`, `report`, `panic`, `camera`, `curhai`, `emergency_contacts`, `profile`, `school_summary`) terisolasi dalam lapisan `domain`, `data`, dan `presentation`. *(Modul `archive` dihapus sementara pada rilis saat ini dan tab navigasi dialihkan ke `Profil`.)*

## 2. Desain Tingkat Tinggi

- **Aplikasi Klien (Flutter)**: Antarmuka siswa dan Guru BK, pembersihan EXIF gambar (`image`), perekaman bukti (`camera`, `image_picker`, `record`), penyimpanan kode aman (`flutter_secure_storage`), antrean laporan offline (`shared_preferences` + `connectivity_plus`), dan pengiriman SMS darurat.
- **Supabase (PostgreSQL, Storage, Auth, Realtime)**: Tabel `schools`, `profiles`, `staff`, `reports`, `report_attachments`, `report_status_history`, `report_messages`, `emergency_contacts`, `panic_events`, `education_articles`, `school_summaries`, `app_notifications`, dan Storage bucket `evidence` dengan Row Level Security.
- **Supabase Edge Functions**: Gerbang tunggal menuju model AI (OpenRouter / Qwen) untuk `curhai-chat`, `analyze-image`, `panic-notify`, dan `school-summary`.

## 3. Alur Data Utama

1. **Laporan Bullying & Laporanku**: Klien membersihkan metadata EXIF gambar, mengunggah bukti ke bucket `evidence/{uid}/{reportKey}/...`, menghasilkan `idempotency_key` (UUID v4), lalu memanggil RPC `submit_report`. Bila offline, laporan masuk ke antrean lokal dan otomatis dikirim saat koneksi kembali. Guru BK dapat memajukan status lewat `advance_report_status` dan membalas lewat `send_report_message`.
2. **Tombol Darurat (Panic Button)**: Menjalankan perekaman audio, pengambilan koordinat GPS (timeout 3 detik + fallback last-known), pengiriman SMS ke seluruh kontak aktif, dan pemanggilan Edge Function `panic-notify` secara paralel dan independen. Saat dihentikan, audio diunggah dan `resolve_panic_event` menutup sesi darurat.
3. **CurhAI**: Percakapan dikirim ke Edge Function `curhai-chat` dengan deteksi sinyal krisis di klien maupun server; riwayat obrolan disimpan hanya secara lokal di perangkat, bukan di tabel server.
4. **Panel Guru BK & Rangkuman Sekolah**: Memanggil Edge Function `school-summary` untuk merangkum data laporan 7 hari terakhir tanpa identitas pelapor menggunakan model Qwen dan menampilkan daftar `panic_events` aktif sekolah.
