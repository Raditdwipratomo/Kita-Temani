# Runbook: Kegagalan Tombol Darurat / SMS

## 1. Gejala
Status SMS pada layar *Bantuan Sedang Dikirim* menampilkan status **Gagal** pada satu atau lebih kontak darurat.

## 2. Langkah Penanganan di Klien
1. Aplikasi otomatis mencoba ulang pengiriman SMS hingga 3 kali.
2. Layar *Bantuan Sedang Dikirim* menampilkan peringatan dan mengarahkan siswa ke tiga tombol aksi manual yang selalu tersedia:
   - **Chat WhatsApp** ke Kontak Utama (pesan dan tautan lokasi terisi otomatis).
   - **Telepon** ke Kontak Utama (membuka dialer dengan nomor terisi).
   - **Hubungi 112**.

## 3. Verifikasi Teknis
- Pastikan izin `SEND_SMS` dan `ACCESS_FINE_LOCATION` telah diberikan saat onboarding izin.
- Periksa ketersediaan pulsa dan sinyal seluler pada perangkat uji.
