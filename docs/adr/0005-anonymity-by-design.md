# ADR-005: Anonimitas by Design pada Tabel Laporan

- **Status**: Proposed
- **Tanggal**: 2026-11-09

## Konteks
Siswa ragu melapor bila identitasnya dapat dilihat pihak sekolah atau bocor dari database.

## Keputusan
Tabel `reports` tidak menyimpan kolom `user_id` pelapor. Pelapor melacak status laporan menggunakan kode unik (`KT-MMDD-XXXX`) yang disimpan secara lokal di perangkat.

## Konsekuensi
Anonimitas dijamin secara teknis di tingkat skema database.
