import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/core/widgets/student_illustrations.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/auth/presentation/screens/complete_profile_screen.dart';
import 'package:kitatemani/features/auth/presentation/screens/school_login_screen.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/screens/emergency_contacts_screen.dart';
import 'package:kitatemani/features/home/presentation/screens/home_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/app_permissions_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/profile_screen.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/my_reports_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_sent_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_type_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
      'Beranda bersih dari data dummy & alur Laporan bullying menampilkan date picker + link bukti',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.home),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pengguna'), findsOneWidget);
    expect(find.text('Maya'), findsNothing);
    expect(find.text('XI-2'), findsNothing);
    expect(find.text('KT-8F3Q-M7ZK'), findsNothing);
    expect(find.text('Aman & terlindungi. Ditinjau Guru BK.'), findsOneWidget);
    expect(find.text('Buat laporan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Belum ada laporan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Belum ada laporan'), findsOneWidget);

    // Bottom navigation replaced Arsip with Profil
    expect(find.text('Arsip'), findsNothing);
    expect(find.text('Profil'), findsOneWidget);

    // Tap Curhai tab: zero dummy starter chat messages
    await tester.tap(find.text('Curhai').first);
    await tester.pumpAndSettle();
    expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);
    expect(find.textContaining('diejek di depan kelas'), findsNothing);

    // Tap Profil tab on bottom navigation
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profil saya'), findsOneWidget);
    expect(find.textContaining('Arsip'), findsNothing);
    expect(find.text('Panel Guru BK & Insight AI'), findsNothing);

    // Return to Beranda tab and start report flow
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Buat laporan'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Buat laporan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Laporan perundungan'), findsOneWidget);
    expect(find.text('Privat & Rahasia'), findsOneWidget);
    expect(find.text('Aku yang mengalami'), findsOneWidget);
    expect(find.text('Fisik'), findsOneWidget);
    expect(find.text('Verbal'), findsOneWidget);
    expect(find.text('Siber (Online)'), findsOneWidget);
    expect(find.text('Sosial'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(DateFormatter.fullDate(DateTime.now())),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('KAPAN KEJADIANNYA?'), findsOneWidget);
    expect(find.text(DateFormatter.fullDate(DateTime.now())), findsOneWidget);
    expect(find.text('Lanjut ke Cerita Kejadian'), findsOneWidget);

    await tester.tap(find.text('Lanjut ke Cerita Kejadian'));
    await tester.pumpAndSettle();

    expect(find.text('Ceritakan kejadiannya'), findsOneWidget);
    expect(find.text('Kamera'), findsNothing);
    expect(find.text('Galeri'), findsNothing);
    expect(find.byKey(const Key('report_narrative_input')), findsOneWidget);
    expect(find.byKey(const Key('report_perpetrators_input')), findsOneWidget);
    expect(find.byKey(const Key('report_victim_name_input')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tambah link bukti'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tambah link bukti'), findsOneWidget);
    expect(find.text('Lampirkan file / dokumen'), findsOneWidget);
    expect(
      find.text('Hanya format PDF atau DOCX · Maksimal 2 MB'),
      findsOneWidget,
    );
    expect(find.textContaining('Arsip'), findsNothing);

    // Tambah link bukti modal
    await tester.ensureVisible(find.text('Tambah link bukti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah link bukti'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan link bukti'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'https://drive.example.com/bukti-01',
    );
    await tester.tap(find.text('Simpan link bukti'));
    await tester.pumpAndSettle();

    expect(find.text('https://drive.example.com/bukti-01'), findsWidgets);
  });

  testWidgets(
      'Alur Daftar / Login Siswa mengarahkan ke Lengkapi Biodata sebelum Beranda',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.schoolLogin),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke KitaTemani'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
    expect(find.text('Daftar Akun'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Kata sandi'), findsOneWidget);
    expect(find.text('Lanjutkan dengan Google'), findsOneWidget);
    expect(find.textContaining('Sekolah mitra'), findsNothing);
    expect(find.textContaining('Mode pribadi'), findsNothing);
    expect(find.textContaining('Panel Sekolah'), findsNothing);

    await tester.tap(find.text('Daftar Akun'));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi kata sandi'), findsOneWidget);
    expect(find.text('Daftar sebagai Siswa'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'radit@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.widgetWithText(AppButton, 'Daftar sebagai Siswa'));
    await tester.pumpAndSettle();

    // Must land on Lengkapi Biodata before entering Beranda
    expect(find.text('Lengkapi Biodata'), findsOneWidget);
    expect(find.text('Nama lengkap'), findsOneWidget);
    expect(find.text('Kelas'), findsOneWidget);
    expect(find.text('Nama sekolah'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Radit Dwi');
    await tester.enterText(find.byType(TextField).at(1), 'XI-1');
    await tester.enterText(find.byType(TextField).at(2), 'SMAN 2 Bandung');
    await tester.ensureVisible(
      find.widgetWithText(AppButton, 'Simpan Biodata & Lanjut'),
    );
    await tester.tap(
      find.widgetWithText(AppButton, 'Simpan Biodata & Lanjut'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Radit'), findsOneWidget);
    expect(find.text('XI-1'), findsOneWidget);
  });

  testWidgets(
      'Login dengan akun khusus Guru BK membuka akses Panel Guru BK di Beranda',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.schoolLogin),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).at(0),
      'bk@kitatemani.id',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'password123',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Konselor & Admin'), findsOneWidget);
    expect(find.text('Pemantauan Status Laporan'), findsOneWidget);
    expect(find.text('Panel Guru BK & Insight AI'), findsNothing);
  });

  testWidgets('Panic Button bersih dari kontak dummy & tanpa opsi 112',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.panic),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tombol Darurat'), findsOneWidget);
    expect(find.text('Situasi cepat (opsional)'), findsOneWidget);
    expect(find.text('Diancam / diikuti'), findsOneWidget);
    expect(find.textContaining('112'), findsNothing);
    expect(find.textContaining('Mama'), findsNothing);
    expect(find.textContaining('Pak Gavin'), findsNothing);
    expect(find.text('Bu Rina (Guru BK)'), findsOneWidget);
    expect(
      find.textContaining('Belum ada kontak keluarga aktif'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Panic Status menampilkan pratinjau pesan SOS detail tanpa chip area sekitar & tombol WA',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.panicActive),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Sinyal darurat terkirim'), findsOneWidget);
    expect(
      find.text('Kirim pesan darurat ke WhatsApp sekarang'),
      findsOneWidget,
    );
    expect(find.text('Kirim WhatsApp ke Bu Rina (Guru BK)'), findsOneWidget);
    expect(find.text('Pesan SOS siap kirim WhatsApp'), findsOneWidget);
    expect(find.text('Salin'), findsOneWidget);
    expect(find.text('Perbarui GPS'), findsOneWidget);
    expect(find.textContaining('PERINGATAN DARURAT'), findsOneWidget);
    expect(find.text('Tambah area sekitar (opsional)'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Chat WA Bu Rina'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Mama'), findsNothing);
    expect(find.textContaining('Pak Gavin'), findsNothing);
    expect(find.textContaining('SMS terkirim'), findsNothing);
    expect(
      find.textContaining('Belum ada kontak keluarga terdaftar'),
      findsOneWidget,
    );
    expect(find.text('Chat WA Bu Rina'), findsOneWidget);
    expect(find.text('Hubungi Bu Rina'), findsOneWidget);
    expect(find.textContaining('089686899447'), findsOneWidget);
    expect(find.text('Saya sudah aman · tahan 2 detik'), findsOneWidget);
  });

  testWidgets(
      'Panic Button tahan 2 detik + Kirim sekarang langsung masuk Panic Status tanpa macet',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.panic),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diancam / diikuti'));
    await tester.pump();

    // Hold the SOS circle for > 2 seconds
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('TAHAN 2 DETIK')),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 2200));
    await gesture.up();
    await tester.pump();

    expect(find.text('Kirim sekarang'), findsOneWidget);

    // Tap "Kirim sekarang" and verify transition completes cleanly without getting stuck
    await tester.tap(find.text('Kirim sekarang'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sinyal darurat terkirim'), findsOneWidget);
    expect(find.textContaining('*Situasi:* Diancam / diikuti'), findsOneWidget);
    expect(find.text('Kirim WhatsApp ke Bu Rina (Guru BK)'), findsOneWidget);
  });

  testWidgets('Kontak Darurat bersih dari kontak keluarga dummy',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.emergencyContacts),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu Rina, S.Pd.'), findsOneWidget);
    expect(find.textContaining('089686899447'), findsOneWidget);
    expect(find.text('Tetap aktif'), findsOneWidget);
    expect(find.text('Belum ada kontak darurat'), findsOneWidget);
    expect(find.text('Mama'), findsNothing);
    expect(find.text('Pak Gavin'), findsNothing);
    expect(find.textContaining('Pak Dimas'), findsNothing);
  });

  testWidgets(
      'Kamera langsung menampilkan antarmuka full-screen kamera tanpa ilustrasi dummy',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.camera),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CharacterAvatar), findsNothing);
    expect(find.text('FOTO'), findsOneWidget);
    expect(find.text('VIDEO'), findsOneWidget);
    expect(find.text('LIVE AI'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('Bukti foto yang diunggah menampilkan thumbnail & dialog Preview',
      (tester) async {
    final testImg = img.Image(width: 24, height: 24);
    img.fill(testImg, color: img.ColorRgb8(88, 95, 230));
    final pngBytes = Uint8List.fromList(img.encodePng(testImg));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(submitReportControllerProvider.notifier).addPickedEvidence(
          PickedEvidence(
            fileName: 'galeri_bukti_test.jpg',
            kind: EvidenceKind.foto,
            bytes: pngBytes,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KitaTemaniApp(initialRoute: AppRoutes.reportStory),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('galeri_bukti_test.jpg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('galeri_bukti_test.jpg'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(
      find.text('Preview bukti · Metadata EXIF telah dihapus'),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets(
      'Detail Laporan tanpa fitur chat & menampilkan preview bukti gambar',
      (tester) async {
    final testImg = img.Image(width: 24, height: 24);
    img.fill(testImg, color: img.ColorRgb8(24, 169, 107));
    final pngBytes = Uint8List.fromList(img.encodePng(testImg));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final submitCtrl = container.read(submitReportControllerProvider.notifier);
    submitCtrl
      ..updateNarrative('Kronologi pengujian detail laporan beserta bukti.')
      ..addPickedEvidence(
        PickedEvidence(
          fileName: 'bukti_detail_test.jpg',
          kind: EvidenceKind.foto,
          bytes: pngBytes,
        ),
      );
    final res = await tester.runAsync(submitCtrl.submitCurrentDraft);
    expect(res, isA<Ok<String>>());
    final code = (res! as Ok<String>).value;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReportDetailScreen(reportCode: code),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No chat UI in ReportDetailScreen
    expect(find.text('DISKUSI PRIVAT'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);

    // Visual preview card & button present
    await tester.scrollUntilVisible(
      find.text('BUKTI & LAMPIRAN'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('BUKTI & LAMPIRAN'));
    await tester.pumpAndSettle();

    expect(find.text('BUKTI & LAMPIRAN'), findsOneWidget);
    expect(find.text('bukti_detail_test.jpg'), findsOneWidget);

    await tester.ensureVisible(find.text('Lihat Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat Preview'), findsOneWidget);

    await tester.tap(find.text('Lihat Preview'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets(
      'Izin Aplikasi dari Profil membuka halaman izin khusus dan kembali ke Profil tanpa ke halaman Login',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.home),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profil saya'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Izin Aplikasi'),
      200,
      scrollable: find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Izin Aplikasi'));
    await tester.pumpAndSettle();

    // Must open dedicated AppPermissionsScreen — NOT Onboarding or Login
    expect(find.byType(AppPermissionsScreen), findsOneWidget);
    expect(find.text('Izin Aplikasi'), findsOneWidget);
    expect(find.text('Kamera & Bukti'), findsOneWidget);
    expect(find.text('Mikrofon Darurat'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Panggilan Cepat'),
      200,
      scrollable: find.descendant(
        of: find.byType(AppPermissionsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Lokasi GPS Presisi'), findsOneWidget);
    expect(find.text('Kirim SMS Darurat'), findsOneWidget);
    expect(find.text('Panggilan Cepat'), findsOneWidget);
    expect(find.text('Masuk ke KitaTemani'), findsNothing);
    expect(find.text('Lewati'), findsNothing);

    await tester.tap(find.text('Kembali ke Profil'));
    await tester.pumpAndSettle();

    // Returns cleanly back to Profil — never redirected to Login
    expect(find.text('Profil saya'), findsOneWidget);
    expect(find.text('Masuk ke KitaTemani'), findsNothing);
  });

  testWidgets(
      'Tombol kembali & Kembali ke Profil di Izin Aplikasi tetap aman meski dibuka langsung (canPop == false)',
      (tester) async {
    // 1. Test header back arrow when launched directly (e.g. browser refresh / hot restart)
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.appPermissions),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppPermissionsScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Profil saya'), findsOneWidget);
    expect(find.text('Masuk ke KitaTemani'), findsNothing);

    // 2. Test bottom "Kembali ke Profil" button when launched directly
    await tester.pumpWidget(
      const ProviderScope(
        key: ValueKey('direct-permissions-2'),
        child: KitaTemaniApp(initialRoute: AppRoutes.appPermissions),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppPermissionsScreen), findsOneWidget);
    await tester.tap(find.text('Kembali ke Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Profil saya'), findsOneWidget);
    expect(find.text('Masuk ke KitaTemani'), findsNothing);
  });

  testWidgets(
      'Beranda tampil proporsional di desktop (1280px) & mobile (390px) tanpa ilustrasi clipart',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Desktop wide viewport
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.home),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CharacterAvatar), findsNothing);
    expect(find.text('Asisten AI'), findsNothing);
    expect(find.text('Bisa tanpa nama'), findsNothing);
    expect(find.text('Hanya ke Guru BK'), findsOneWidget);
    expect(find.text('Bukti dibersihkan'), findsOneWidget);
    expect(
      find.text('Cerita pelan-pelan, didengar tanpa dihakimi'),
      findsOneWidget,
    );

    // Compact mobile viewport
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterAvatar), findsNothing);
    expect(find.byType(OwlMascot), findsOneWidget);
    expect(find.byType(OwlGlyphIcon), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is KitaIllustration && w.scene == IllustrationScene.heroBanner,
      ),
      findsOneWidget,
    );
    expect(find.text('Bisa tanpa nama'), findsNothing);
    expect(find.text('Khusus Guru BK'), findsNothing);
    expect(find.text('Buat laporan'), findsOneWidget);
    expect(find.text('Gimana perasaanmu hari ini?'), findsNothing);
    expect(find.text('Cek harian'), findsNothing);
    expect(
      find.text('Artikel edukasi akan tampil saat terhubung ke server.'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Batas Sehat'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(KitaIllustration), findsWidgets);
    expect(find.text('Batas Sehat'), findsOneWidget);
    expect(find.text('Teman Peduli'), findsOneWidget);

    // Enabling Mode Samar hides Beranda OwlMascot & heroBanner owl
    final container = ProviderScope.containerOf(
      tester.element(find.byType(KitaTemaniApp)),
    );
    container
        .read(studentProfileProvider.notifier)
        .updateProfile(isDisguisedMode: true);
    await tester.pumpAndSettle();
    expect(find.byType(OwlMascot), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is KitaIllustration && w.scene == IllustrationScene.heroBanner,
      ),
      findsNothing,
    );
    expect(find.text('Gimana perasaanmu hari ini?'), findsNothing);
  });

  testWidgets(
      'Onboarding Slide 1 & 2 tampil dengan maskot burung hantu tanpa clipart',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.onboarding),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CharacterAvatar), findsNothing);
    expect(
      tester.widget<OwlMascot>(find.byType(OwlMascot)).mood,
      OwlMood.reassuring,
    );

    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterAvatar), findsNothing);
    expect(
      tester.widget<OwlMascot>(find.byType(OwlMascot)).mood,
      OwlMood.warm,
    );
  });

  testWidgets(
      'Seluruh 6 area berwarna & berilustrasi tampil rapi di Desktop (1280px) & Mobile (390px)',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.devicePixelRatio = 1.0;

    final screens = <Widget>[
      const ReportSentScreen(),
      const MyReportsTabView(),
      const ReportTypeScreen(),
      const SchoolLoginScreen(),
      const CompleteProfileScreen(),
      const ProfileScreen(isTabView: true),
      const EmergencyContactsScreen(),
    ];

    for (final viewport in [const Size(1280, 800), const Size(390, 844)]) {
      tester.view.physicalSize = viewport;
      for (final screen in screens) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: screen),
          ),
        );
        await tester.pumpAndSettle();
      }
    }

    // Verify key illustration placements on Mobile viewport
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ReportSentScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<KitaIllustration>(find.byType(KitaIllustration)).scene,
      IllustrationScene.reportSent,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MyReportsTabView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buat laporan pertama'), findsOneWidget);
    expect(
      tester.widget<KitaIllustration>(find.byType(KitaIllustration)).scene,
      IllustrationScene.emptyReports,
    );
  });

  testWidgets(
      'Fitur notifikasi sudah dihapus dari Beranda, Profil, dan Laporan Saya',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.text('Notifikasi'), findsNothing);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileScreen(isTabView: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.text('Notifikasi'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Pusat bantuan'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Izin Aplikasi'), findsOneWidget);
    expect(find.text('Mode samar'), findsNothing);
    expect(
      find.text('Tampilan aplikasi disamarkan sebagai "Catatan"'),
      findsNothing,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MyReportsTabView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    expect(find.text('Notifikasi'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byTooltip('Muat ulang laporan'), findsOneWidget);
  });
}
