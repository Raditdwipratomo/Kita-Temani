# Panduan Onboarding Developer KitaTemani

## 1. Prasyarat Lingkungan

- Flutter SDK (Dart 3.x)
- Android SDK (API 31+ direkomendasikan)
- Editor dengan dukungan Dart/Flutter

## 2. Menjalankan Aplikasi (Mode Dummy Data / MVP)

Aplikasi saat ini dikonfigurasi dengan **Repositori Dummy In-Memory** sesuai tahap verifikasi UI dan alur fungsional awal, sehingga dapat langsung dijalankan tanpa setup database eksternal:

```bash
flutter pub get
flutter run
```

## 3. Struktur Modul

- `lib/app/`: Konfigurasi MaterialApp, tema (`app_colors.dart`, `app_theme.dart`), dan router (`app_router.dart`).
- `lib/core/`: Tipe hasil (`Result`, `Failure`), layanan perangkat (`SmsSender`, `LocationService`, `AudioRecorderService`, `CryptoService`), dan widget bersama.
- `lib/features/`: Modul fitur terisolasi (`onboarding`, `home`, `report`, `panic`, `camera`, `archive`, `emergency_contacts`, `curhai`, `profile`).
- `lib/l10n/`: Teks Bahasa Indonesia terpusat.

## 4. Konvensi Kode

- Lapisan `domain` hanya berisi kode Dart murni.
- Setiap fitur berkomunikasi melalui provider Riverpod atau kontrak di `core`.
- Jalankan `flutter analyze` dan `flutter test` sebelum membuat pull request.
