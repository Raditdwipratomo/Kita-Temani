-- supabase/migrations/20261130_reset_app_data_and_seed_guru_bk_articles.sql
--
-- 1. Menambahkan kolom metadata penulis & topik pada public.education_articles
--    agar seeder maupun artikel baru dari Guru BK tersinkron penuh di database.
-- 2. Menghapus seluruh data operasional & seeder lama KECUALI data akun user
--    (auth.users, public.profiles, public.staff, public.schools tetap dipertahankan).
-- 3. Mengisi 10 artikel seeder baru yang seluruh penulisnya adalah Guru BK.

alter table public.education_articles
  add column if not exists subtitle text,
  add column if not exists tag text not null default 'Batas Sehat',
  add column if not exists author_name text not null default 'Bu Rina, S.Pd. (Guru BK)',
  add column if not exists author_role text not null default 'Guru BK · SMAN 1 Nusantara',
  add column if not exists is_verified_author boolean not null default true,
  add column if not exists scene_name text;

-- Kosongkan seluruh data non-user (laporan, pesan, riwayat, lampiran,
-- panic button, kontak darurat, ringkasan sekolah, notifikasi, artikel lama).
-- Akun pengguna di auth.users, public.profiles, public.staff, dan data sekolah
-- di public.schools TIDAK disentuh.
delete from public.report_messages;
delete from public.report_status_history;
delete from public.report_attachments;
delete from public.reports;
delete from public.panic_events;
delete from public.emergency_contacts;
delete from public.school_summaries;
delete from public.app_notifications;
delete from public.education_articles;

-- 10 Seeder Artikel Edukasi baru (seluruh penulis adalah Guru BK).
insert into public.education_articles (
  slug,
  tag,
  title,
  subtitle,
  body,
  read_minutes,
  accent_color,
  author_name,
  author_role,
  is_verified_author,
  scene_name,
  sort_order
)
values
  (
    'bercanda-atau-bullying',
    'Batas Sehat',
    'Bercanda atau bullying? Ini cara membedakannya',
    'Tiga tanda sederhana untuk mengenali batas aman saat candaan di kelas mulai terasa merendahkan dan menyakitkan.',
    E'Banyak siswa ragu melapor karena pelaku sering berkilah: "Cuma bercanda kok, jangan baper!" Kalimat ini sering membuat korban mempertanyakan perasaannya sendiri.\n\n## Tiga ciri utama bercanda vs bullying\n- Dalam candaan sehat, semua pihak ikut tertawa dan berhenti begitu ada yang merasa tidak nyaman.\n- Dalam perundungan (bullying), ada ketimpangan kuasa, niat merendahkan martabat, dan pengulangan meski kamu sudah meminta berhenti.\n- Perundungan juga sering membuat korbannya terisolasi dari teman sebaya atau takut berangkat ke sekolah.\n\n> Kalau hatimu merasa terpojok dan permintaanmu untuk berhenti terus diabaikan, itu bukan lagi bercanda—itu sinyal kuat kamu butuh ruang aman.\n\n## Langkah cepat yang bisa kamu ambil hari ini\n- Katakan batas dengan singkat dan tegas lalu menjauh dari kerumunan.\n- Catat tanggal, lokasi, serta siapa saja yang melihat kejadian tersebut.\n- Cerita ke CurhAI jika kamu masih bingung merangkai kata, atau kirim laporan privat ke Guru BK kapan pun siap.',
    3,
    '#585FE6',
    'Bu Rina, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduBoundary',
    1
  ),
  (
    'menolak-paksaan-teman',
    'Batas Sehat',
    'Cara mengatakan tidak saat candaan teman melewati batas',
    'Kalimat asertif singkat untuk menjaga harga diri tanpa memicu pertengkaran di lingkungan pertemanan.',
    E'Menolak perlakuan tidak nyaman bukan berarti kamu terlalu sensitif. Menetapkan batas sejak awal justru menjaga hubungan pertemanan tetap sehat.\n\n## Mengapa batas asertif penting?\n- Sikap diam sering disalahartikan pelaku sebagai persetujuan untuk terus mengulang ejekan.\n- Kalimat yang tenang namun tegas memberi sinyal jelas bahwa perilaku tersebut tidak bisa diterima.\n\n> Kamu berhak dihormati di kelas, di koridor, maupun di grup obrolan tanpa harus membalas dengan kemarahan.\n\n## Contoh kalimat yang bisa dipakai\n- "Aku nggak nyaman sama sebutan itu, tolong berhenti sekarang."\n- "Kalau pembicaraan ini mengarah ke mengejek teman, aku memilih keluar dari obrolan."\n- Jika perlakuan tetap berlanjut, segera laporkan ke Guru BK agar ditindaklanjuti secara aman.',
    3,
    '#585FE6',
    'Pak Bagus, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduBoundary',
    6
  ),
  (
    'melihat-teman-dirundung',
    'Teman Peduli',
    'Apa yang dilakukan saat melihat teman dirundung?',
    'Menjadi upstander tidak harus konfrontatif. Langkah kecil yang aman sudah cukup menyelamatkan teman.',
    E'Saat perundungan terjadi, suasana sekitar sering membeku. Namun kehadiran satu orang yang berpihak sudah mampu memutus efek intimidasi pelaku.\n\n## Empat cara aman menjadi Upstander\n- Alihkan perhatian: ajak korban pergi menjauh dari situasi dengan alasan sederhana.\n- Dampingi setelah kejadian: tanyakan keadaannya di tempat sepi tanpa memaksa cerita.\n- Jangan ikut merekam atau menyebarkan video kejadian karena itu memperberat luka korban.\n- Bantu catat kronologi dan tawarkan menemani ke Ruang BK untuk melapor bersama.\n\n> Dukungan kecil seperti duduk menemani di kantin bisa menjadi penyelamat terbesar bagi teman yang sedang tertekan.',
    3,
    '#1F8A70',
    'Bu Sari, M.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduAlly',
    2
  ),
  (
    'menjadi-pendengar-aman',
    'Teman Peduli',
    'Menjadi pendengar aman bagi teman yang takut bercerita',
    'Panduan merespons curhatan korban bullying agar mereka merasa diterima, bukan dihakimi.',
    E'Korban perundungan sering menunda bercerita karena takut disalahkan atau dianggap lemah. Cara kamu mendengarkan sangat menentukan keberaniannya mencari pertolongan.\n\n## Sikap pendengar yang menguatkan\n- Fokus mendengarkan tanpa menyela atau membandingkan masalahnya dengan orang lain.\n- Hindari kalimat menyalahkan seperti "Kenapa nggak kamu lawan balik?"\n- Validasi perasaannya: akui bahwa kejadian itu memang berat dan bukan kesalahannya.\n\n> Tugasmu bukan menyelesaikan semuanya sendirian, melainkan menemani temanmu menjangkau bantuan Guru BK yang tepat.',
    4,
    '#1F8A70',
    'Bu Rina, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduAlly',
    7
  ),
  (
    'hadapi-cyberbullying',
    'Aman Online',
    'Menghadapi teror chat & cyberbullying di media sosial',
    'Protokol empat langkah dari Guru BK saat menerima ancaman, fitnah, atau pengucilan di grup chat.',
    E'Perundungan digital bisa mengikuti sampai ke rumah dan muncul di layar ponsel kapan saja. Jangan menghadapi layar ponselmu sendirian saat pesan ancaman datang.\n\n## Protokol 4 langkah saat menerima teror online\n- Jangan membalas pesan penuh amarah karena pelaku sering menunggu reaksi emosionalmu.\n- Ambil tangkapan layar penuh yang menampilkan isi pesan, tanggal, jam, serta nama akun pelaku.\n- Gunakan fitur blokir dan bisukan grup agar ketenanganmu terjaga.\n- Unggah bukti tangkapan layar ke menu Lapor Guru BK untuk penanganan sekolah.\n\n> Menghapus chat terlalu cepat justru menghilangkan jejak bukti penting sebelum ditinjau Guru BK.',
    4,
    '#2563EB',
    'Pak Bagus, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduCyber',
    3
  ),
  (
    'privasi-akun-sekolah',
    'Aman Online',
    'Menjaga privasi akun dan grup chat agar terhindar dari doxing',
    'Kebiasaan keamanan digital sederhana untuk melindungi foto, nomor telepon, dan data pribadimu.',
    E'Penyebaran foto tanpa izin dan pembocoran data pribadi (doxing) sering berawal dari celah privasi akun media sosial yang terbuka untuk umum.\n\n## Daftar periksa keamanan akun siswa\n- Atur akun media sosial menjadi privat dan tinjau ulang siapa saja pengikutmu.\n- Batasi siapa yang bisa memasukkanmu ke grup chat baru atau melihat foto profilmu.\n- Jangan pernah membagikan kata sandi, kode OTP, atau tangkapan layar percakapan pribadi ke sembarang orang.\n\n> Jika foto atau datamu sudah telanjur disebarkan tanpa izin, segera simpan tautannya dan laporkan ke Guru BK.',
    3,
    '#2563EB',
    'Bu Sari, M.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduCyber',
    8
  ),
  (
    'menenangkan-diri-setelah-kejadian',
    'Jaga Diri',
    'Teknik grounding 5-4-3-2-1 saat cemas setelah mengalami perundungan',
    'Latihan singkat membantu jantung lebih tenang dan pikiran kembali hadir ketika panik melanda.',
    E'Setelah mengalami intimidasi, tubuh sering bereaksi dengan jantung berdebar cepat, tangan gemetar, atau sulit berkonsentrasi di kelas.\n\n## Langkah grounding 5-4-3-2-1\n- Sebutkan 5 benda yang dapat kamu lihat di ruangan saat ini.\n- Sentuh 4 permukaan berbeda di sekitarmu seperti meja, buku, atau tas.\n- Dengarkan 3 suara pelan yang ada di sekitar kelas.\n- Kenali 2 aroma terdekat, lalu ambil 1 tarikan napas dalam dan hembuskan perlahan.\n\n> Tubuhmu sedang berusaha melindungimu. Beri dirimu waktu beberapa menit untuk menenangkan diri sebelum mengambil langkah berikutnya.',
    3,
    '#D97706',
    'Bu Rina, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduSelfcare',
    4
  ),
  (
    'kapan-pakai-tombol-darurat',
    'Jaga Diri',
    'Kapan perlu menekan tombol darurat dan menghubungi Guru BK?',
    'Mengenal situasi mendesak yang membutuhkan respons cepat dari konselor sekolah dan orang tua.',
    E'Tidak semua masalah bisa menunggu jam istirahat. Pada situasi tertentu, keselamatan fisik dan rasa amanmu harus didahulukan segera.\n\n## Situasi darurat yang perlu respons cepat\n- Kamu sedang diancam secara langsung, diikuti, atau dikepung di area sekolah.\n- Terjadi kekerasan fisik atau pemalakan yang berisiko melukai dirimu maupun teman.\n- Kamu merasa kewalahan secara emosional dan membutuhkan pendampingan segera dari Guru BK.\n\n> Tekan tombol Darurat selama 2 detik agar sinyal lokasi dan pesan SOS langsung meneruskan panggilan bantuan ke Guru BK serta kontak daruratmu.',
    3,
    '#D97706',
    'Pak Bagus, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduSelfcare',
    9
  ),
  (
    'menyiapkan-bukti-laporan',
    'Tanya & Diskusi',
    'Cara menyiapkan bukti tangkapan layar & kronologi sebelum melapor',
    'Panduan menyusun kronologi singkat dan dokumen PDF/DOCX agar laporan mudah diverifikasi Guru BK.',
    E'Laporan yang disertai kronologi jelas membantu Guru BK memahami konteks kejadian tanpa membuatmu harus mengulang cerita berulang kali.\n\n## Tiga elemen utama laporan yang kuat\n- Waktu dan lokasi spesifik kejadian berlangsung.\n- Rangkaian peristiwa secara singkat: apa yang diucapkan atau dilakukan pihak terkait, serta siapa saksinya.\n- Lampiran bukti pendukung berupa tautan atau dokumen PDF/DOCX yang rapi.\n\n> Belum punya bukti lengkap? Jangan tunggu sempurna—kamu tetap boleh mengirim laporan agar Guru BK bisa langsung mendampingimu.',
    4,
    '#7C3AED',
    'Bu Sari, M.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduBoundary',
    10
  ),
  (
    'alur-konseling-ruang-bk',
    'Tanya & Diskusi',
    'Apa yang terjadi di Ruang BK setelah kamu mengirim laporan?',
    'Penjelasan transparan mengenai tahapan status laporan dan perlindungan kerahasiaan pelapor.',
    E'Banyak siswa khawatir melapor karena membayangkan suasana ruang konseling yang kaku atau takut identitasnya bocor ke pelaku. Di KitaTemani, perlindungan pelapor menjadi prioritas utama.\n\n## Tahapan tindak lanjut laporanmu\n- Laporan yang masuk berstatus Dikirim hanya dapat dibaca oleh Guru BK resmi sekolah.\n- Ketika berstatus Dibaca dan Ditindak, Guru BK memverifikasi fakta secara tertutup tanpa menyebut namamu kepada pihak pelaku.\n- Kamu dapat memantau setiap pembaruan status hingga laporan selesai ditangani.\n\n> Ruang BK hadir bukan untuk menghakimi, melainkan memastikan setiap siswa bisa belajar dengan rasa aman.',
    4,
    '#7C3AED',
    'Bu Rina, S.Pd. (Guru BK)',
    'Guru BK · SMAN 1 Nusantara',
    true,
    'eduAlly',
    5
  )
on conflict (slug) do update
set
  tag = excluded.tag,
  title = excluded.title,
  subtitle = excluded.subtitle,
  body = excluded.body,
  read_minutes = excluded.read_minutes,
  accent_color = excluded.accent_color,
  author_name = excluded.author_name,
  author_role = excluded.author_role,
  is_verified_author = excluded.is_verified_author,
  scene_name = excluded.scene_name,
  sort_order = excluded.sort_order;
