import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/router/app_router.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/features/articles/domain/entities/article.dart';
import 'package:kitatemani/features/articles/presentation/controllers/articles_controller.dart';
import 'package:kitatemani/features/articles/presentation/screens/article_composer_screen.dart';
import 'package:kitatemani/features/articles/presentation/screens/article_detail_screen.dart';
import 'package:kitatemani/features/articles/presentation/screens/articles_feed_screen.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/home/presentation/screens/home_screen.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Editorial Articles (Medium x X x Quora) & Guru BK RBAC CRUD', () {
    testWidgets(
        'ArticlesFeedScreen memfilter topik, mencari judul, memberi clap, menyimpan ke Disimpan, & menyembunyikan tombol Tulis bagi Siswa',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: ArticlesFeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ruang Baca'), findsOneWidget);
      // RBAC: Siswa tidak memiliki tombol Tulis / Edit / Hapus artikel
      expect(find.text('Tulis'), findsNothing);
      expect(find.byTooltip('Edit artikel'), findsNothing);
      expect(find.byTooltip('Hapus artikel'), findsNothing);
      expect(
        find.text('Bercanda atau bullying? Ini cara membedakannya'),
        findsOneWidget,
      );

      // Multi-tap clap increments live count (0 -> 2)
      final clapPill = find.byTooltip('Beri tepuk tangan').first;
      await tester.ensureVisible(clapPill);
      await tester.tap(clapPill);
      await tester.pumpAndSettle();
      await tester.tap(clapPill);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);

      // Bookmark first article and switch to Disimpan tab
      await tester.tap(find.byTooltip('Simpan artikel').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disimpan (1)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bercanda atau bullying? Ini cara membedakannya'),
        findsOneWidget,
      );

      // Switch back to Untukmu and filter by Aman Online + search
      await tester.tap(find.text('Untukmu'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Aman Online'));
      await tester.pumpAndSettle();
      expect(
        find.text('Menghadapi teror chat & cyberbullying di media sosial'),
        findsOneWidget,
      );
      expect(
        find.text('Bercanda atau bullying? Ini cara membedakannya'),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('articles_search_input')),
        'teror chat',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Menjaga privasi akun dan grup chat agar terhindar dari doxing',
        ),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('articles_search_input')),
        'doxing',
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Menjaga privasi akun dan grup chat agar terhindar dari doxing',
        ),
        findsOneWidget,
      );
    });

    test('10 seeder artikel seluruhnya ditulis oleh Guru BK tanpa data dummy lain',
        () {
      expect(defaultEditorialArticles, hasLength(10));
      for (final article in defaultEditorialArticles) {
        expect(article.authorName, contains('Guru BK'));
        expect(article.authorRole, contains('Guru BK'));
        expect(article.isVerifiedAuthor, isTrue);
        expect(article.clapCount, 0);
        expect(article.comments, isEmpty);
      }
    });

    testWidgets(
        'ArticleDetailScreen menampilkan progress baca, ubah ukuran font, clap, & diskusi anonim',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: ArticleDetailScreen(articleId: 'art-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.text('Tiga ciri utama bercanda vs bullying'),
        findsOneWidget,
      );

      // Cycle font size button A -> A+
      expect(find.text('A'), findsOneWidget);
      await tester.tap(find.byTooltip('Ukuran huruf'));
      await tester.pumpAndSettle();
      expect(find.text('A+'), findsOneWidget);

      // Multi-tap clap from sticky bottom bar
      await tester.tap(find.byIcon(Icons.pan_tool_alt_outlined).last);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsWidgets);
      expect(find.text('+1'), findsOneWidget);

      // Scroll to comment composer and post anonymous response
      final commentInput = find.byKey(const Key('article_comment_input'));
      await tester.scrollUntilVisible(
        commentInput,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(commentInput);
      await tester.pumpAndSettle();

      await tester.enterText(
        commentInput,
        'Terima kasih panduannya, sangat membantu untuk berani bicara.',
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Kirim tanggapan'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Kirim tanggapan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim tanggapan'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Terima kasih panduannya, sangat membantu untuk berani bicara.',
        ),
        findsOneWidget,
      );
      expect(find.text('Siswa Anonim'), findsWidgets);

      // Toggle helpful on newly posted comment
      await tester.scrollUntilVisible(
        find.text('Bermanfaat (0)'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Bermanfaat (0)').first);
      await tester.pumpAndSettle();
      expect(find.text('Bermanfaat (1)'), findsOneWidget);
    });

    testWidgets(
        'RBAC Artikel: Siswa ditolak di ArticleComposerScreen, sedangkan Guru BK dapat melakukan Full CRUD (Create, Edit, Delete Artikel & Hapus Komentar)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Default Siswa mencoba membuka ArticleComposerScreen -> muncul Akses Khusus Guru BK
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            initialRoute: AppRoutes.articleCompose,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Akses Khusus Guru BK'), findsOneWidget);
      expect(find.text('Publikasikan Artikel'), findsNothing);

      // 2. Beralih ke akun Guru BK -> form Tulis Artikel terbuka
      container.read(studentProfileProvider.notifier).updateProfile(
            name: 'Bu Rina, S.Pd.',
            shortName: 'Bu Rina',
            className: 'Ruang BK',
            schoolId: 'sman1-nusantara',
            schoolName: 'SMA Negeri 1 Nusantara',
            counselorName: 'Bu Rina, S.Pd.',
            counselorPhone: '+628119988776',
            isPrivateMode: false,
            isDisguisedMode: false,
            isProfileCompleted: true,
            role: UserRole.guruBk,
          );
      await tester.pumpAndSettle();

      expect(find.text('Tulis Artikel'), findsOneWidget);
      await tester.tap(find.text('Publikasikan Artikel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Judul artikel minimal 6 karakter agar mudah dipahami.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('composer_title_input')),
        'Panduan Konseling Aman di Ruang BK',
      );
      await tester.enterText(
        find.byKey(const Key('composer_subtitle_input')),
        'Langkah mudah menjadwalkan sesi cerita rahasia bersama Guru BK.',
      );
      await tester.enterText(
        find.byKey(const Key('composer_body_input')),
        '## Ruang BK selalu terbuka\nSetiap siswa berhak didengar tanpa dihakimi dan dijaga kerahasiaannya.',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publikasikan Artikel'));
      await tester.pumpAndSettle();

      final created = container.read(articlesControllerProvider).articles.first;
      expect(created.title, 'Panduan Konseling Aman di Ruang BK');
      expect(created.authorName, 'Bu Rina, S.Pd.');
      expect(created.authorRole, 'Guru BK');
      expect(created.isVerifiedAuthor, isTrue);
      expect(find.byType(ArticleDetailScreen), findsOneWidget);

      // 3. Guru BK melakukan Update (Edit) artikel dan Delete artikel + komentar
      final notifier = container.read(articlesControllerProvider.notifier);
      notifier.updateArticle(
        articleId: created.id,
        title: 'Panduan Konseling Rahasia di Ruang BK (Diperbarui)',
        subtitle: created.subtitle,
        body: created.body,
        tag: 'Teman Sebaya',
      );
      expect(
        container.read(articlesControllerProvider).findById(created.id)!.title,
        'Panduan Konseling Rahasia di Ruang BK (Diperbarui)',
      );

      notifier.addComment(
        articleId: created.id,
        body: 'Komentar uji moderasi',
        isAnonymous: true,
      );
      final commentId = container
          .read(articlesControllerProvider)
          .findById(created.id)!
          .comments
          .first
          .id;
      notifier.deleteComment(articleId: created.id, commentId: commentId);
      expect(
        container
            .read(articlesControllerProvider)
            .findById(created.id)!
            .comments,
        isEmpty,
      );

      notifier.deleteArticle(created.id);
      expect(
        container.read(articlesControllerProvider).findById(created.id),
        isNull,
      );
    });

    testWidgets(
        'Sinkronisasi Laporan Siswa <-> Guru BK: Dikirim -> Dibaca -> Ditindak -> Selesai memakai keterangan default otomatis tanpa input catatan',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Siswa mengirim laporan baru -> status awal Dikirim
      final draftCtrl = container.read(submitReportControllerProvider.notifier);
      draftCtrl.toggleType(BullyingType.verbal);
      draftCtrl.updateLocation('Koridor Kelas XI IPA 2');
      draftCtrl.updateNarrative(
        'Ada siswa yang terus diejek di depan kelas setiap jam istirahat.',
      );
      await tester.runAsync(draftCtrl.submitCurrentDraft);
      final submitted =
          container.read(myReportsControllerProvider).reports.first;
      expect(submitted.status, ReportStatus.diterima);
      expect(submitted.status.label, 'Dikirim');

      // 2. Guru BK membuka ReportDetailScreen(asCounselor: true)
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: ReportDetailScreen(
              reportCode: submitted.code,
              asCounselor: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Klik 1-tap Tandai Sudah Dibaca (Dikirim -> Dibaca)
      final panelTitle = find.text('PANEL TINDAK LANJUT GURU BK');
      await tester.scrollUntilVisible(
        panelTitle,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(panelTitle, findsOneWidget);

      final markReadBtn = find.byKey(const Key('counselor_mark_read_button'));
      await tester.scrollUntilVisible(
        markReadBtn,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(markReadBtn);
      await tester.pumpAndSettle();
      expect(find.text('Tandai Sudah Dibaca'), findsOneWidget);
      await tester.tap(markReadBtn);
      await tester.pumpAndSettle();

      var latest = container
          .read(myReportsControllerProvider)
          .reports
          .firstWhere((r) => r.code == submitted.code);
      expect(latest.status, ReportStatus.ditinjau);
      expect(latest.status.label, 'Dibaca');

      // Pilih tahap Ditindak dan pastikan input catatan manual sudah dihapus
      expect(
        find.byKey(const Key('counselor_status_note_input')),
        findsNothing,
      );
      expect(
        find.text('Catatan Tindak Lanjut (Tampil di Riwayat Siswa)'),
        findsNothing,
      );

      final ditindakChip =
          find.byKey(const Key('counselor_stage_tindak_lanjut'));
      await tester.scrollUntilVisible(
        ditindakChip,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(ditindakChip);
      await tester.pumpAndSettle();
      await tester.tap(ditindakChip);
      await tester.pumpAndSettle();

      final saveBtn = find.byKey(const Key('counselor_save_status_button'));
      await tester.scrollUntilVisible(
        saveBtn,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      latest = container
          .read(myReportsControllerProvider)
          .reports
          .firstWhere((r) => r.code == submitted.code);
      expect(latest.status, ReportStatus.tindakLanjut);
      expect(latest.status.label, 'Ditindak');

      // 3. Siswa membuka ReportDetailScreen(asCounselor: false) -> melihat status Ditindak & keterangan default otomatis
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: ReportDetailScreen(
              reportCode: submitted.code,
              asCounselor: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PANEL TINDAK LANJUT GURU BK'), findsNothing);
      expect(find.text('Ditindak'), findsWidgets);
      final counselorNoteFinder = find.text(
        'Pendampingan dan tindak lanjut aman sedang dilakukan oleh Guru BK.',
      );
      await tester.scrollUntilVisible(
        counselorNoteFinder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(counselorNoteFinder);
      await tester.pumpAndSettle();
      expect(counselorNoteFinder, findsOneWidget);
    });

    testWidgets(
        'HomeScreen Guru BK memakai Navbar Admin (Dashboard, Pantau, Artikel, Profil) tanpa fitur Siswa (Curhai, Darurat, Kamera, Buat laporan)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(studentProfileProvider.notifier).updateProfile(
            name: 'Bu Rina, S.Pd.',
            shortName: 'Bu Rina',
            className: 'Ruang BK',
            schoolId: 'sman1-nusantara',
            schoolName: 'SMA Negeri 1 Nusantara',
            counselorName: 'Bu Rina, S.Pd.',
            counselorPhone: '+628119988776',
            isPrivateMode: false,
            isDisguisedMode: false,
            isProfileCompleted: true,
            role: UserRole.guruBk,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Counselor navbar tabs
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Pantau'), findsOneWidget);
      expect(find.text('Artikel'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);

      // Counselor dashboard content
      expect(find.text('Dashboard Konselor & Admin'), findsOneWidget);
      expect(find.text('Panel Guru BK & Insight AI'), findsNothing);
      expect(find.text('Pemantauan Status Laporan'), findsOneWidget);

      // Zero student features on Guru BK shell
      expect(find.text('Curhai'), findsNothing);
      expect(find.text('Darurat'), findsNothing);
      expect(find.text('Kamera'), findsNothing);
      expect(find.text('Buat laporan'), findsNothing);
      expect(find.text('Gimana perasaanmu hari ini?'), findsNothing);
    });

    testWidgets(
        'Halaman Feed, Detail, & Composer tampil bebas overflow pada Mobile 390x844 & Desktop 1280x800',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;

      final screens = <Widget>[
        const ArticlesFeedScreen(),
        const ArticleDetailScreen(articleId: 'art-1'),
        const ArticleComposerScreen(),
      ];

      for (final viewport in [const Size(390, 844), const Size(1280, 800)]) {
        tester.view.physicalSize = viewport;
        for (final screen in screens) {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                onGenerateRoute: AppRouter.onGenerateRoute,
                home: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
