import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/router/app_router.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_theme.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_review_screen.dart';
import 'package:kitatemani/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDocumentMediaService extends MediaService {
  _FakeDocumentMediaService(this.nextResult);

  DocumentPickResult nextResult;

  @override
  Future<DocumentPickResult> pickEvidenceDocument() async => nextResult;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'ReportStoryScreen memiliki tepat 3 input teks tanpa opsi Kamera/Galeri & mendukung upload PDF/DOCX <= 2 MB',
      (tester) async {
    final fakeMedia = _FakeDocumentMediaService(
      DocumentPickResult.success(
        PickedEvidence(
          fileName: 'bukti_kronologi.pdf',
          kind: EvidenceKind.file,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
          sizeBytes: 4096,
          exifStripped: false,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaServiceProvider.overrideWithValue(fakeMedia),
          connectivityServiceProvider.overrideWithValue(
            DummyConnectivityService(),
          ),
          secureStorageServiceProvider.overrideWithValue(
            InMemorySecureStorageService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          initialRoute: AppRoutes.reportStory,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Opsi Kamera, Galeri & chip prompt bantuan dihapus
    expect(find.text('Kamera'), findsNothing);
    expect(find.text('Galeri'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('+ Siapa saja yang terlibat?'), findsNothing);

    // Tepat 3 TextField: Cerita kejadian, List nama pelaku, Nama korban
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.byKey(const Key('report_narrative_input')), findsOneWidget);
    expect(find.byKey(const Key('report_perpetrators_input')), findsOneWidget);
    expect(find.byKey(const Key('report_victim_name_input')), findsOneWidget);

    // Keterangan format & batas ukuran
    expect(
      find.text('Hanya format PDF atau DOCX · Maksimal 2 MB'),
      findsOneWidget,
    );

    // Isi ketiga input teks
    await tester.enterText(
      find.byKey(const Key('report_narrative_input')),
      'Kakak kelas mengejek dan mengancam saat jam istirahat di kantin.',
    );
    await tester.enterText(
      find.byKey(const Key('report_perpetrators_input')),
      'Andi (XII-IPA 1), Budi (XII-IPA 2)',
    );
    await tester.enterText(
      find.byKey(const Key('report_victim_name_input')),
      'Radit Pratama (XI-MIPA 2)',
    );
    await tester.pumpAndSettle();

    // Upload dokumen valid (.pdf)
    await tester.ensureVisible(find.text('Lampirkan file / dokumen'));
    await tester.tap(find.text('Lampirkan file / dokumen'));
    await tester.pumpAndSettle();
    expect(find.text('bukti_kronologi.pdf'), findsOneWidget);

    // Tolak format tidak valid & tampilkan error SnackBar
    fakeMedia.nextResult = const DocumentPickResult.failure(
      DocumentPickError.unsupportedFormat,
      'Format file tidak didukung. Hanya file PDF atau DOCX yang diperbolehkan.',
    );
    await tester.ensureVisible(find.text('Lampirkan file / dokumen'));
    await tester.tap(find.text('Lampirkan file / dokumen'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Format file tidak didukung. Hanya file PDF atau DOCX yang diperbolehkan.',
      ),
      findsOneWidget,
    );

    // Tolak ukuran melebihi 2 MB
    fakeMedia.nextResult = const DocumentPickResult.failure(
      DocumentPickError.fileTooLarge,
      'Ukuran file 2.50 MB melebihi batas maksimal 2 MB.',
    );
    await tester.tap(find.text('Lampirkan file / dokumen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ukuran file 2.50 MB melebihi batas maksimal 2 MB.'),
      findsOneWidget,
    );

    // Biarkan SnackBar menutup sebelum menekan tombol Tinjau laporan di bar bawah
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Lanjut ke halaman Tinjau laporan
    await tester.ensureVisible(find.text('Tinjau laporan'));
    await tester.tap(find.text('Tinjau laporan'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportReviewScreen), findsOneWidget);
    expect(find.text('Tinjau laporan'), findsOneWidget);
    expect(find.text('Radit Pratama (XI-MIPA 2)'), findsOneWidget);
    expect(find.text('Andi (XII-IPA 1), Budi (XII-IPA 2)'), findsOneWidget);
    expect(find.textContaining('1 dokumen (PDF/DOCX)'), findsOneWidget);
    expect(find.text('bukti_kronologi.pdf'), findsOneWidget);

    // Kirim laporan & cek Detail Laporan menyimpan nama pelaku dan korban
    await tester.tap(find.text('Kirim Laporan Sekarang'));
    await tester.pumpAndSettle();
    expect(find.text(L10n.reportSentTitle), findsOneWidget);

    await tester.ensureVisible(find.text('Pantau laporan'));
    await tester.tap(find.text('Pantau laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporanku'), findsOneWidget);
    expect(
      ReportListFilter.values,
      const [
        ReportListFilter.semua,
        ReportListFilter.dikirim,
        ReportListFilter.dibaca,
        ReportListFilter.ditindak,
        ReportListFilter.selesai,
      ],
    );
    expect(find.text('Diproses'), findsNothing);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Dikirim'), findsWidgets);
    expect(find.text('Dibaca'), findsWidgets);
    expect(find.text('Ditindak'), findsWidgets);
    expect(find.text('Selesai'), findsWidgets);

    await tester.tap(find.textContaining('KT-').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetailScreen), findsOneWidget);
    expect(find.text('DETAIL LAPORAN'), findsOneWidget);
    expect(find.text('Identitas pelapor'), findsOneWidget);
    expect(find.text('Peran pelapor'), findsOneWidget);
    expect(find.text('Korban langsung'), findsOneWidget);
    expect(find.text('Jenis bullying'), findsOneWidget);
    expect(find.text('Tanggal & lokasi'), findsOneWidget);
    expect(find.text('Nama korban'), findsOneWidget);
    expect(find.text('Radit Pratama (XI-MIPA 2)'), findsOneWidget);
    expect(find.text('List nama pelaku'), findsOneWidget);
    expect(find.text('Andi (XII-IPA 1), Budi (XII-IPA 2)'), findsOneWidget);
    expect(find.text('Cerita kejadian'), findsOneWidget);
    expect(
      find.text(
        'Kakak kelas mengejek dan mengancam saat jam istirahat di kantin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'ReportDetailScreen menampilkan seluruh field sinkron dan fallback Belum disebutkan untuk laporan saksi',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(
          DummyConnectivityService(),
        ),
        secureStorageServiceProvider.overrideWithValue(
          InMemorySecureStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final ctrl = container.read(submitReportControllerProvider.notifier);
    ctrl
      ..updateIsVictim(false)
      ..updateLocation('Lapangan basket')
      ..updateNarrative('Melihat siswa didorong di dekat ring basket.');
    final res = await tester.runAsync(ctrl.submitCurrentDraft);
    expect(res, isA<Ok<String>>());
    final code = (res! as Ok<String>).value;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ReportDetailScreen(reportCode: code),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DETAIL LAPORAN'), findsOneWidget);
    expect(find.text('Identitas pelapor'), findsOneWidget);
    expect(find.text('Peran pelapor'), findsOneWidget);
    expect(find.text('Saksi kejadian'), findsOneWidget);
    expect(find.text('Jenis bullying'), findsOneWidget);
    expect(find.text('Tanggal & lokasi'), findsOneWidget);
    expect(find.text('Nama korban'), findsOneWidget);
    expect(find.text('List nama pelaku'), findsOneWidget);
    expect(find.text('Belum disebutkan'), findsNWidgets(2));
    expect(find.text('Cerita kejadian'), findsOneWidget);
    expect(
      find.text('Melihat siswa didorong di dekat ring basket.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Guru BK melihat Identitas pelapor lengkap (nama, kelas, nomor HP) di Detail Laporan',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(
          DummyConnectivityService(),
        ),
        secureStorageServiceProvider.overrideWithValue(
          InMemorySecureStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(studentProfileProvider.notifier).updateProfile(
          name: 'Dika Pratama',
          shortName: 'Dika',
          className: 'XI-2',
          phoneNumber: '081234567890',
        );

    final ctrl = container.read(submitReportControllerProvider.notifier);
    ctrl
      ..updateIsVictim(true)
      ..updateLocation('Kantin sekolah')
      ..updateVictimName('Dika Pratama')
      ..updatePerpetratorNames('Andi')
      ..updateNarrative('Pelaporan oleh siswa untuk verifikasi identitas.');
    final res = await tester.runAsync(ctrl.submitCurrentDraft);
    expect(res, isA<Ok<String>>());
    final code = (res! as Ok<String>).value;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ReportDetailScreen(reportCode: code, asCounselor: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identitas pelapor'), findsOneWidget);
    expect(
      find.text('Dika Pratama (XI-2) · 081234567890'),
      findsOneWidget,
    );
  });
}
