# Dokumentasi Kontrak API KitaTemani

Format kesalahan seragam di seluruh RPC dan Edge Function:
```json
{
  "code": "error_code",
  "message": "Pesan kesalahan yang aman ditampilkan ke pengguna."
}
```

## 1. Supabase RPC

### `upsert_my_profile`
Menyimpan atau memperbarui profil pengguna (`profiles`) serta menyinkronkan keanggotaan `staff` bila peran adalah `guru_bk` atau `wali_kelas`.

### `submit_report`
Mengirim laporan perundungan secara idempoten beserta lampiran bukti dan riwayat status awal, serta mengirim notifikasi ke Guru BK sekolah mitra.

- **Input**:
  - `p_idempotency_key` (`uuid`)
  - `p_school_ref` (`text`: slug atau uuid sekolah)
  - `p_types` (`text[]`: `fisik`, `verbal`, `sosial`, `siber`)
  - `p_occurred_at` (`timestamptz`)
  - `p_location` (`text`)
  - `p_narrative` (`text`, 10–5000 karakter)
  - `p_evidence_link` (`text`, opsional)
  - `p_is_victim` (`boolean`)
  - `p_is_anonymous` (`boolean`)
  - `p_attachments` (`jsonb` array `{ file_name, storage_path, kind }`)
- **Output**: `{ "id": "uuid", "code": "KT-XXXX-XXXX" }`

### `get_my_reports`, `get_school_reports`, & `get_report_detail`
Mengambil daftar laporan pelapor (atau semua laporan sekolah khusus Guru BK) lengkap dengan riwayat timeline, lampiran, dan pesan diskusi privat 2-arah.

### `advance_report_status` & `send_report_message`
Memperbarui status penanganan oleh Guru BK (`diterima` -> `ditinjau` -> `tindak_lanjut` -> `selesai`), menambah entri `report_status_history`, dan mengirim pesan diskusi privat (`report_messages`) disertai notifikasi ke pihak terkait.

### `resolve_panic_event`
Menandai sesi darurat (`panic_events`) selesai ketika pengguna mengakhiri mode darurat dan menyimpan `audio_storage_path` bila ada.

## 2. Supabase Edge Functions

### `POST /functions/v1/curhai-chat`
- **Request**: `{ "messages": [{ "role": "user", "content": "..." }] }`
- **Response**: `{ "reply": "...", "risk_level": "normal|elevated|crisis", "disclaimer": "..." }`

### `POST /functions/v1/analyze-image`
- **Request**: `{ "image_base64": "..." }`
- **Response**: `{ "indications": ["..."], "disclaimer": "...", "model": "..." }`

### `POST /functions/v1/panic-notify`
- **Request**: `{ "lat": -6.2, "lng": 106.8, "accuracy": 8.5, "location_label": "...", "student_name": "...", "class_name": "...", "school_slug": "...", "message_text": "...", "contact_deliveries": [] }`
- **Response**: `{ "ack": true, "event_id": "uuid", "received_at": "...", "location": { ... } }`

### `POST /functions/v1/school-summary`
- **Request**: `{ "school_slug": "sman1-nusantara", "period": "7d" }`
- **Response**: `{ "summary": { "risk_cases": 1, "online_cases": 1, "total_reports": 4, "top_location": "...", "summary_text": "...", "recommendation": "...", "generated_at": "..." } }`
