# ADR-001: Flutter untuk Aplikasi Klien

- **Status**: Accepted
- **Tanggal**: 2026-11-09

## Konteks
KitaTemani membutuhkan antarmuka pengguna yang responsif di Android dengan kemungkinan perluasan ke platform lain di masa depan.

## Keputusan
Menggunakan Flutter (Dart 3) dengan platform channel Kotlin khusus untuk pengiriman SMS (`SmsManager`).

## Konsekuensi
Satu basis kode untuk seluruh antarmuka, dengan modul kecil Kotlin di `android/app/src/main/kotlin/.../SmsChannel.kt`.
