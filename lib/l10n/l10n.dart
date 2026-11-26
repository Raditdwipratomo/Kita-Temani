abstract final class L10n {
  static const String appTitle = 'KitaTemani';
  static const String splashTagline = 'Berani lapor, berani peduli';
  static const String splashSubtitle =
      'Tempat aman untuk bercerita, melaporkan\nbullying, dan mendapatkan dukungan.\nKamu tidak sendirian!';

  // Onboarding
  static const String onboardingBadge = 'Aku ada di sini';
  static const String onboardingTitle1 = 'Laporkan bullying\ndengan rasa aman';
  static const String onboardingBody1 =
      'Laporanmu bersifat privat dan rahasia. Hanya Guru BK terverifikasi yang membacanya—tidak dibuka ke siswa lain.';
  static const String onboardingTitle2 = 'Lampirkan bukti &\ncerita kapan saja';
  static const String onboardingBody2 =
      'Ngobrol dengan Curhai kapan saja 24/7 atau kirim bukti foto, file, dan tautan langsung kepada Guru BK.';
  static const String onboardingTitle3 = 'Izin Darurat &\nPerlindungan Cepat';
  static const String onboardingBody3 =
      'Aktifkan izin penting agar Tombol Darurat siap mengirim pesan ke keluarga dan Guru BK dalam hitungan detik.';
  static const String btnNext = 'Lanjut';
  static const String btnStart = 'Mulai pakai KitaTemani';
  static const String btnSkip = 'Lewati';

  // Navigasi
  static const String navHome = 'Beranda';
  static const String navCurhai = 'Curhai';
  static const String navReports = 'Laporan';
  static const String navProfile = 'Profil';

  // Beranda
  static String homeGreeting(String name) => 'Halo, $name!';
  static const String homeSubtitle = 'Kamu aman bersama kami';
  static const String heroBannerPill = 'Kamu tidak sendirian';
  static const String heroBannerBody = 'Aman & terlindungi. Ditinjau Guru BK.';
  static const String quickReport = 'Buat laporan';
  static const String quickLiveCamera = 'Kamera';
  static const String quickCurhai = 'Curhai';
  static const String trackReportTitle = 'Laporanmu';
  static const String trackReportSubtitle =
      'Perkembangan laporanmu bisa kamu pantau di sini.';

  // Pelaporan Bullying
  static const String reportBullyingTitle = 'Laporan perundungan';
  static const String reportStoryTitle = 'Ceritakan kejadiannya';
  static const String reportSentTitle = 'Laporan terkirim!';
  static const String myReportsTitle = 'Laporanku';

  // Panic Button (tanpa 112)
  static const String panicTitle = 'Tombol Darurat';
  static const String panicQuestion = 'Merasa terancam sekarang?';
  static const String panicSubtitle =
      'Tahan 2 detik untuk mengirim lokasi & peringatan ke kontak darurat dan Guru BK.';
  static const String panicSentTitle = 'Sinyal darurat terkirim';
  static const String panicSentSubtitle =
      'Tetap tenang, tarik napas pelan-pelan.';
  static const String btnImSafe = 'Saya sudah aman · tahan 2 detik';

  // Profil & Kontak Darurat
  static const String profileTitle = 'Profil';
  static const String emergencyContactsTitle = 'Kontak Darurat';
  static const String addContactTitle = 'Tambah Kontak';

  // Curhai
  static const String curhaiTitle = 'Curhai';
  static const String curhaiStatus = 'Online · teman ceritamu';
  static const String curhaiPrivacyPill =
      'Privat & rahasia · tidak dibagikan tanpa izinmu';
  static const String curhaiDisclaimer =
      'Curhai bukan pengganti Guru BK. Kalau merasa tidak aman, tekan Tombol Darurat.';
}
