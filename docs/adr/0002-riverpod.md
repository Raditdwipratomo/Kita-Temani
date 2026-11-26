# ADR-002: Riverpod untuk State Management dan Dependency Injection

- **Status**: Accepted
- **Tanggal**: 2026-11-09

## Konteks
Aplikasi memerlukan state management yang aman saat kompilasi, mendukung pemisahan lapisan Clean Architecture, dan mudah diuji dengan implementasi dummy maupun produksi.

## Keputusan
Menggunakan `flutter_riverpod` untuk state management dan injeksi dependensi repositori/layanan.

## Konsekuensi
Seluruh repositori dan layanan dapat di-override dengan mudah untuk pengujian dan mode data dummy tanpa mengubah kode presentasi.
