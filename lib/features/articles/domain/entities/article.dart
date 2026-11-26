import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';

const List<String> kArticleTopics = [
  'Batas Sehat',
  'Teman Peduli',
  'Aman Online',
  'Jaga Diri',
  'Tanya & Diskusi',
];

class ArticleTopicTheme {
  const ArticleTopicTheme({
    required this.accent,
    required this.background,
    required this.border,
    required this.tagText,
    this.defaultScene,
  });

  final Color accent;
  final Color background;
  final Color border;
  final Color tagText;
  final IllustrationScene? defaultScene;
}

ArticleTopicTheme topicThemeFor(String topic) {
  return switch (topic) {
    'Teman Peduli' => const ArticleTopicTheme(
        accent: AppColors.hijau,
        background: AppColors.tintMint,
        border: Color(0xFFC2EBD8),
        tagText: AppColors.mintText,
        defaultScene: IllustrationScene.eduAlly,
      ),
    'Aman Online' => const ArticleTopicTheme(
        accent: Color(0xFFF59E0B),
        background: AppColors.amberTint,
        border: Color(0xFFF6DF9F),
        tagText: AppColors.amberText,
        defaultScene: IllustrationScene.eduCyber,
      ),
    'Jaga Diri' => const ArticleTopicTheme(
        accent: AppColors.lilacAccent,
        background: AppColors.tintLilac,
        border: Color(0xFFE1D2FF),
        tagText: AppColors.lilacText,
        defaultScene: IllustrationScene.eduSelfcare,
      ),
    'Tanya & Diskusi' => const ArticleTopicTheme(
        accent: AppColors.skyAccent,
        background: AppColors.tintSky,
        border: Color(0xFFC2E3FB),
        tagText: AppColors.skyText,
      ),
    _ => const ArticleTopicTheme(
        accent: AppColors.biruTinta,
        background: AppColors.tintIndigo,
        border: Color(0xFFDCE0FC),
        tagText: AppColors.biruTinta,
        defaultScene: IllustrationScene.eduBoundary,
      ),
  };
}

IllustrationScene? parseIllustrationScene(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final scene in IllustrationScene.values) {
    if (scene.name == name) return scene;
  }
  return null;
}

int estimateReadMinutes(String text) {
  final words =
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final minutes = (words / 160).ceil();
  return minutes < 1 ? 1 : minutes;
}

String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 2) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '$weeks minggu lalu';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}

String computeInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'KT';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

class ArticleComment {
  const ArticleComment({
    required this.id,
    required this.authorName,
    required this.authorRole,
    required this.isVerifiedStaff,
    required this.isAnonymous,
    required this.body,
    required this.createdAt,
    this.helpfulCount = 0,
    this.isHelpfulByMe = false,
  });

  final String id;
  final String authorName;
  final String authorRole;
  final bool isVerifiedStaff;
  final bool isAnonymous;
  final String body;
  final DateTime createdAt;
  final int helpfulCount;
  final bool isHelpfulByMe;

  String get displayAuthor => isAnonymous ? 'Siswa Anonim' : authorName;

  String get displayRole => isAnonymous ? 'Anonim' : authorRole;

  String get authorInitials => computeInitials(displayAuthor);

  String get relativeTimeLabel => formatRelativeTime(createdAt);

  ArticleComment copyWith({
    String? id,
    String? authorName,
    String? authorRole,
    bool? isVerifiedStaff,
    bool? isAnonymous,
    String? body,
    DateTime? createdAt,
    int? helpfulCount,
    bool? isHelpfulByMe,
  }) {
    return ArticleComment(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      isVerifiedStaff: isVerifiedStaff ?? this.isVerifiedStaff,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isHelpfulByMe: isHelpfulByMe ?? this.isHelpfulByMe,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'authorRole': authorRole,
        'isVerifiedStaff': isVerifiedStaff,
        'isAnonymous': isAnonymous,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'helpfulCount': helpfulCount,
        'isHelpfulByMe': isHelpfulByMe,
      };

  factory ArticleComment.fromJson(Map<String, dynamic> json) {
    return ArticleComment(
      id: (json['id'] ?? '').toString(),
      authorName: (json['authorName'] ?? 'Siswa').toString(),
      authorRole: (json['authorRole'] ?? 'Siswa').toString(),
      isVerifiedStaff: json['isVerifiedStaff'] == true,
      isAnonymous: json['isAnonymous'] == true,
      body: (json['body'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
      isHelpfulByMe: json['isHelpfulByMe'] == true,
    );
  }
}

class ArticleItem {
  const ArticleItem({
    required this.id,
    required this.slug,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.readMinutes,
    required this.authorName,
    required this.authorRole,
    required this.isVerifiedAuthor,
    required this.publishedAt,
    required this.accentColorValue,
    required this.cardBackgroundValue,
    required this.borderColorValue,
    required this.tagTextColorValue,
    this.sceneName,
    this.clapCount = 0,
    this.myClapCount = 0,
    this.isBookmarked = false,
    this.comments = const [],
    this.isUserCreated = false,
  });

  final String id;
  final String slug;
  final String tag;
  final String title;
  final String subtitle;
  final String body;
  final int readMinutes;
  final String authorName;
  final String authorRole;
  final bool isVerifiedAuthor;
  final DateTime publishedAt;
  final int accentColorValue;
  final int cardBackgroundValue;
  final int borderColorValue;
  final int tagTextColorValue;
  final String? sceneName;
  final int clapCount;
  final int myClapCount;
  final bool isBookmarked;
  final List<ArticleComment> comments;
  final bool isUserCreated;

  Color get accentColor => Color(accentColorValue);
  Color get cardBackground => Color(cardBackgroundValue);
  Color get borderColor => Color(borderColorValue);
  Color get tagTextColor => Color(tagTextColorValue);
  IllustrationScene? get scene => parseIllustrationScene(sceneName);
  String get cleanTitle => title.replaceAll('\n', ' ');
  String get authorInitials => computeInitials(authorName);
  String get relativeTimeLabel => formatRelativeTime(publishedAt);

  ArticleItem copyWith({
    String? id,
    String? slug,
    String? tag,
    String? title,
    String? subtitle,
    String? body,
    int? readMinutes,
    String? authorName,
    String? authorRole,
    bool? isVerifiedAuthor,
    DateTime? publishedAt,
    int? accentColorValue,
    int? cardBackgroundValue,
    int? borderColorValue,
    int? tagTextColorValue,
    String? sceneName,
    bool clearScene = false,
    int? clapCount,
    int? myClapCount,
    bool? isBookmarked,
    List<ArticleComment>? comments,
    bool? isUserCreated,
  }) {
    return ArticleItem(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      tag: tag ?? this.tag,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      readMinutes: readMinutes ?? this.readMinutes,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      isVerifiedAuthor: isVerifiedAuthor ?? this.isVerifiedAuthor,
      publishedAt: publishedAt ?? this.publishedAt,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      cardBackgroundValue: cardBackgroundValue ?? this.cardBackgroundValue,
      borderColorValue: borderColorValue ?? this.borderColorValue,
      tagTextColorValue: tagTextColorValue ?? this.tagTextColorValue,
      sceneName: clearScene ? null : (sceneName ?? this.sceneName),
      clapCount: clapCount ?? this.clapCount,
      myClapCount: myClapCount ?? this.myClapCount,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      comments: comments ?? this.comments,
      isUserCreated: isUserCreated ?? this.isUserCreated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'tag': tag,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'readMinutes': readMinutes,
        'authorName': authorName,
        'authorRole': authorRole,
        'isVerifiedAuthor': isVerifiedAuthor,
        'publishedAt': publishedAt.toIso8601String(),
        'accentColorValue': accentColorValue,
        'cardBackgroundValue': cardBackgroundValue,
        'borderColorValue': borderColorValue,
        'tagTextColorValue': tagTextColorValue,
        'sceneName': sceneName,
        'clapCount': clapCount,
        'myClapCount': myClapCount,
        'isBookmarked': isBookmarked,
        'comments': comments.map((c) => c.toJson()).toList(),
        'isUserCreated': isUserCreated,
      };

  factory ArticleItem.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag'] ?? 'Batas Sehat').toString();
    final theme = topicThemeFor(tag);
    final rawComments = json['comments'];
    final parsedComments = rawComments is List
        ? rawComments
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ArticleComment.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <ArticleComment>[];

    return ArticleItem(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      tag: tag,
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      readMinutes: (json['readMinutes'] as num?)?.toInt() ?? 3,
      authorName: (json['authorName'] ?? 'Guru BK').toString(),
      authorRole: (json['authorRole'] ?? 'Pendamping Sekolah').toString(),
      isVerifiedAuthor: json['isVerifiedAuthor'] == true,
      publishedAt: DateTime.tryParse((json['publishedAt'] ?? '').toString()) ??
          DateTime.now(),
      accentColorValue: (json['accentColorValue'] as num?)?.toInt() ??
          theme.accent.toARGB32(),
      cardBackgroundValue: (json['cardBackgroundValue'] as num?)?.toInt() ??
          theme.background.toARGB32(),
      borderColorValue: (json['borderColorValue'] as num?)?.toInt() ??
          theme.border.toARGB32(),
      tagTextColorValue: (json['tagTextColorValue'] as num?)?.toInt() ??
          theme.tagText.toARGB32(),
      sceneName: json['sceneName']?.toString(),
      clapCount: (json['clapCount'] as num?)?.toInt() ?? 0,
      myClapCount: (json['myClapCount'] as num?)?.toInt() ?? 0,
      isBookmarked: json['isBookmarked'] == true,
      comments: parsedComments,
      isUserCreated: json['isUserCreated'] == true,
    );
  }
}

ArticleItem _seededGuruBkArticle({
  required String id,
  required String slug,
  required String tag,
  required String title,
  required String subtitle,
  required String body,
  required int readMinutes,
  required String authorName,
  required DateTime publishedAt,
  IllustrationScene? scene,
}) {
  final theme = topicThemeFor(tag);
  return ArticleItem(
    id: id,
    slug: slug,
    tag: tag,
    title: title,
    subtitle: subtitle,
    body: body,
    readMinutes: readMinutes,
    authorName: authorName,
    authorRole: 'Guru BK · SMAN 1 Nusantara',
    isVerifiedAuthor: true,
    publishedAt: publishedAt,
    accentColorValue: theme.accent.toARGB32(),
    cardBackgroundValue: theme.background.toARGB32(),
    borderColorValue: theme.border.toARGB32(),
    tagTextColorValue: theme.tagText.toARGB32(),
    sceneName: (scene ?? theme.defaultScene)?.name,
    clapCount: 0,
    comments: const [],
  );
}

final List<ArticleItem> defaultEditorialArticles = [
  _seededGuruBkArticle(
    id: 'art-1',
    slug: 'bercanda-atau-bullying',
    tag: 'Batas Sehat',
    title: 'Bercanda atau bullying? Ini cara membedakannya',
    subtitle:
        'Tiga tanda sederhana untuk mengenali batas aman saat candaan di kelas mulai terasa merendahkan dan menyakitkan.',
    body: '''
Banyak siswa ragu melapor karena pelaku sering berkilah: "Cuma bercanda kok, jangan baper!" Kalimat ini sering membuat korban mempertanyakan perasaannya sendiri.

## Tiga ciri utama bercanda vs bullying
- Dalam candaan sehat, semua pihak ikut tertawa dan berhenti begitu ada yang merasa tidak nyaman.
- Dalam perundungan (bullying), ada ketimpangan kuasa, niat merendahkan martabat, dan pengulangan meski kamu sudah meminta berhenti.
- Perundungan juga sering membuat korbannya terisolasi dari teman sebaya atau takut berangkat ke sekolah.

> Kalau hatimu merasa terpojok dan permintaanmu untuk berhenti terus diabaikan, itu bukan lagi bercanda—itu sinyal kuat kamu butuh ruang aman.

## Langkah cepat yang bisa kamu ambil hari ini
- Katakan batas dengan singkat dan tegas lalu menjauh dari kerumunan.
- Catat tanggal, lokasi, serta siapa saja yang melihat kejadian tersebut.
- Cerita ke CurhAI jika kamu masih bingung merangkai kata, atau kirim laporan privat ke Guru BK kapan pun siap.''',
    readMinutes: 3,
    authorName: 'Bu Rina, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 25, 9, 30),
    scene: IllustrationScene.eduBoundary,
  ),
  _seededGuruBkArticle(
    id: 'art-2',
    slug: 'melihat-teman-dirundung',
    tag: 'Teman Peduli',
    title: 'Apa yang dilakukan saat melihat teman dirundung?',
    subtitle:
        'Menjadi upstander tidak harus konfrontatif. Langkah kecil yang aman sudah cukup menyelamatkan teman.',
    body: '''
Saat perundungan terjadi, suasana sekitar sering membeku. Namun kehadiran satu orang yang berpihak sudah mampu memutus efek intimidasi pelaku.

## Empat cara aman menjadi Upstander
- Alihkan perhatian: ajak korban pergi menjauh dari situasi dengan alasan sederhana.
- Dampingi setelah kejadian: tanyakan keadaannya di tempat sepi tanpa memaksa cerita.
- Jangan ikut merekam atau menyebarkan video kejadian karena itu memperberat luka korban.
- Bantu catat kronologi dan tawarkan menemani ke Ruang BK untuk melapor bersama.

> Dukungan kecil seperti duduk menemani di kantin bisa menjadi penyelamat terbesar bagi teman yang sedang tertekan.''',
    readMinutes: 3,
    authorName: 'Bu Sari, M.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 24, 15, 0),
    scene: IllustrationScene.eduAlly,
  ),
  _seededGuruBkArticle(
    id: 'art-3',
    slug: 'hadapi-cyberbullying',
    tag: 'Aman Online',
    title: 'Menghadapi teror chat & cyberbullying di media sosial',
    subtitle:
        'Protokol empat langkah dari Guru BK saat menerima ancaman, fitnah, atau pengucilan di grup chat.',
    body: '''
Perundungan digital bisa mengikuti sampai ke rumah dan muncul di layar ponsel kapan saja. Jangan menghadapi layar ponselmu sendirian saat pesan ancaman datang.

## Protokol 4 langkah saat menerima teror online
- Jangan membalas pesan penuh amarah karena pelaku sering menunggu reaksi emosionalmu.
- Ambil tangkapan layar penuh yang menampilkan isi pesan, tanggal, jam, serta nama akun pelaku.
- Gunakan fitur blokir dan bisukan grup agar ketenanganmu terjaga.
- Unggah bukti tangkapan layar ke menu Lapor Guru BK untuk penanganan sekolah.

> Menghapus chat terlalu cepat justru menghilangkan jejak bukti penting sebelum ditinjau Guru BK.''',
    readMinutes: 4,
    authorName: 'Pak Bagus, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 24, 10, 15),
    scene: IllustrationScene.eduCyber,
  ),
  _seededGuruBkArticle(
    id: 'art-4',
    slug: 'menenangkan-diri-setelah-kejadian',
    tag: 'Jaga Diri',
    title: 'Teknik grounding 5-4-3-2-1 saat cemas setelah mengalami perundungan',
    subtitle:
        'Latihan singkat membantu jantung lebih tenang dan pikiran kembali hadir ketika panik melanda.',
    body: '''
Setelah mengalami intimidasi, tubuh sering bereaksi dengan jantung berdebar cepat, tangan gemetar, atau sulit berkonsentrasi di kelas.

## Langkah grounding 5-4-3-2-1
- Sebutkan 5 benda yang dapat kamu lihat di ruangan saat ini.
- Sentuh 4 permukaan berbeda di sekitarmu seperti meja, buku, atau tas.
- Dengarkan 3 suara pelan yang ada di sekitar kelas.
- Kenali 2 aroma terdekat, lalu ambil 1 tarikan napas dalam dan hembuskan perlahan.

> Tubuhmu sedang berusaha melindungimu. Beri dirimu waktu beberapa menit untuk menenangkan diri sebelum mengambil langkah berikutnya.''',
    readMinutes: 3,
    authorName: 'Bu Rina, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 23, 14, 20),
    scene: IllustrationScene.eduSelfcare,
  ),
  _seededGuruBkArticle(
    id: 'art-5',
    slug: 'alur-konseling-ruang-bk',
    tag: 'Tanya & Diskusi',
    title: 'Apa yang terjadi di Ruang BK setelah kamu mengirim laporan?',
    subtitle:
        'Penjelasan transparan mengenai tahapan status laporan dan perlindungan kerahasiaan pelapor.',
    body: '''
Banyak siswa khawatir melapor karena membayangkan suasana ruang konseling yang kaku atau takut identitasnya bocor ke pelaku. Di KitaTemani, perlindungan pelapor menjadi prioritas utama.

## Tahapan tindak lanjut laporanmu
- Laporan yang masuk berstatus Dikirim hanya dapat dibaca oleh Guru BK resmi sekolah.
- Ketika berstatus Dibaca dan Ditindak, Guru BK memverifikasi fakta secara tertutup tanpa menyebut namamu kepada pihak pelaku.
- Kamu dapat memantau setiap pembaruan status hingga laporan selesai ditangani.

> Ruang BK hadir bukan untuk menghakimi, melainkan memastikan setiap siswa bisa belajar dengan rasa aman.''',
    readMinutes: 4,
    authorName: 'Bu Rina, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 23, 8, 45),
    scene: IllustrationScene.eduAlly,
  ),
  _seededGuruBkArticle(
    id: 'art-6',
    slug: 'menolak-paksaan-teman',
    tag: 'Batas Sehat',
    title: 'Cara mengatakan tidak saat candaan teman melewati batas',
    subtitle:
        'Kalimat asertif singkat untuk menjaga harga diri tanpa memicu pertengkaran di lingkungan pertemanan.',
    body: '''
Menolak perlakuan tidak nyaman bukan berarti kamu terlalu sensitif. Menetapkan batas sejak awal justru menjaga hubungan pertemanan tetap sehat.

## Mengapa batas asertif penting?
- Sikap diam sering disalahartikan pelaku sebagai persetujuan untuk terus mengulang ejekan.
- Kalimat yang tenang namun tegas memberi sinyal jelas bahwa perilaku tersebut tidak bisa diterima.

> Kamu berhak dihormati di kelas, di koridor, maupun di grup obrolan tanpa harus membalas dengan kemarahan.

## Contoh kalimat yang bisa dipakai
- "Aku nggak nyaman sama sebutan itu, tolong berhenti sekarang."
- "Kalau pembicaraan ini mengarah ke mengejek teman, aku memilih keluar dari obrolan."
- Jika perlakuan tetap berlanjut, segera laporkan ke Guru BK agar ditindaklanjuti secara aman.''',
    readMinutes: 3,
    authorName: 'Pak Bagus, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 22, 16, 10),
    scene: IllustrationScene.eduBoundary,
  ),
  _seededGuruBkArticle(
    id: 'art-7',
    slug: 'menjadi-pendengar-aman',
    tag: 'Teman Peduli',
    title: 'Menjadi pendengar aman bagi teman yang takut bercerita',
    subtitle:
        'Panduan merespons curhatan korban bullying agar mereka merasa diterima, bukan dihakimi.',
    body: '''
Korban perundungan sering menunda bercerita karena takut disalahkan atau dianggap lemah. Cara kamu mendengarkan sangat menentukan keberaniannya mencari pertolongan.

## Sikap pendengar yang menguatkan
- Fokus mendengarkan tanpa menyela atau membandingkan masalahnya dengan orang lain.
- Hindari kalimat menyalahkan seperti "Kenapa nggak kamu lawan balik?"
- Validasi perasaannya: akui bahwa kejadian itu memang berat dan bukan kesalahannya.

> Tugasmu bukan menyelesaikan semuanya sendirian, melainkan menemani temanmu menjangkau bantuan Guru BK yang tepat.''',
    readMinutes: 4,
    authorName: 'Bu Rina, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 22, 11, 0),
    scene: IllustrationScene.eduAlly,
  ),
  _seededGuruBkArticle(
    id: 'art-8',
    slug: 'privasi-akun-sekolah',
    tag: 'Aman Online',
    title: 'Menjaga privasi akun dan grup chat agar terhindar dari doxing',
    subtitle:
        'Kebiasaan keamanan digital sederhana untuk melindungi foto, nomor telepon, dan data pribadimu.',
    body: '''
Penyebaran foto tanpa izin dan pembocoran data pribadi (doxing) sering berawal dari celah privasi akun media sosial yang terbuka untuk umum.

## Daftar periksa keamanan akun siswa
- Atur akun media sosial menjadi privat dan tinjau ulang siapa saja pengikutmu.
- Batasi siapa yang bisa memasukkanmu ke grup chat baru atau melihat foto profilmu.
- Jangan pernah membagikan kata sandi, kode OTP, atau tangkapan layar percakapan pribadi ke sembarang orang.

> Jika foto atau datamu sudah telanjur disebarkan tanpa izin, segera simpan tautannya dan laporkan ke Guru BK.''',
    readMinutes: 3,
    authorName: 'Bu Sari, M.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 21, 13, 30),
    scene: IllustrationScene.eduCyber,
  ),
  _seededGuruBkArticle(
    id: 'art-9',
    slug: 'kapan-pakai-tombol-darurat',
    tag: 'Jaga Diri',
    title: 'Kapan perlu menekan tombol darurat dan menghubungi Guru BK?',
    subtitle:
        'Mengenal situasi mendesak yang membutuhkan respons cepat dari konselor sekolah dan orang tua.',
    body: '''
Tidak semua masalah bisa menunggu jam istirahat. Pada situasi tertentu, keselamatan fisik dan rasa amanmu harus didahulukan segera.

## Situasi darurat yang perlu respons cepat
- Kamu sedang diancam secara langsung, diikuti, atau dikepung di area sekolah.
- Terjadi kekerasan fisik atau pemalakan yang berisiko melukai dirimu maupun teman.
- Kamu merasa kewalahan secara emosional dan membutuhkan pendampingan segera dari Guru BK.

> Tekan tombol Darurat selama 2 detik agar sinyal lokasi dan pesan SOS langsung meneruskan panggilan bantuan ke Guru BK serta kontak daruratmu.''',
    readMinutes: 3,
    authorName: 'Pak Bagus, S.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 21, 9, 0),
    scene: IllustrationScene.eduSelfcare,
  ),
  _seededGuruBkArticle(
    id: 'art-10',
    slug: 'menyiapkan-bukti-laporan',
    tag: 'Tanya & Diskusi',
    title: 'Cara menyiapkan bukti tangkapan layar & kronologi sebelum melapor',
    subtitle:
        'Panduan menyusun kronologi singkat dan dokumen PDF/DOCX agar laporan mudah diverifikasi Guru BK.',
    body: '''
Laporan yang disertai kronologi jelas membantu Guru BK memahami konteks kejadian tanpa membuatmu harus mengulang cerita berulang kali.

## Tiga elemen utama laporan yang kuat
- Waktu dan lokasi spesifik kejadian berlangsung.
- Rangkaian peristiwa secara singkat: apa yang diucapkan atau dilakukan pihak terkait, serta siapa saksinya.
- Lampiran bukti pendukung berupa tautan atau dokumen PDF/DOCX yang rapi.

> Belum punya bukti lengkap? Jangan tunggu sempurna—kamu tetap boleh mengirim laporan agar Guru BK bisa langsung mendampingimu.''',
    readMinutes: 4,
    authorName: 'Bu Sari, M.Pd. (Guru BK)',
    publishedAt: DateTime(2026, 11, 20, 10, 0),
    scene: IllustrationScene.eduBoundary,
  ),
];
