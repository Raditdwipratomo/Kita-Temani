import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_review_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_story_screen.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Chip video membuka dialog pemutar interaktif, bukan kartu statis',
      (tester) async {
    final fakeMp4Bytes = Uint8List.fromList([0x00, 0x00, 0x00, 0x18, 0x66]);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(submitReportControllerProvider.notifier).addPickedEvidence(
          PickedEvidence(
            fileName: 'Screen Recording 2026-10-28 151251.mp4',
            kind: EvidenceKind.video,
            bytes: fakeMp4Bytes,
            exifStripped: false,
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
      find.text('Screen Recording 2026-10-28 151251.mp4'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Putar'), findsOneWidget);

    await tester.ensureVisible(find.text('Putar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence_video_player')), findsOneWidget);
    expect(find.textContaining('Lampiran bertipe VIDEO'), findsNothing);
    expect(find.textContaining('Pemutar video bukti'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_video_player')), findsNothing);
  });

  testWidgets(
      'EvidencePreviewCard video menampilkan Putar Video & modal player',
      (tester) async {
    const videoAtt = EvidenceAttachment(
      fileName: 'bukti_kejadian.mp4',
      kind: 'video',
      previewUrl: 'https://cdn.example.com/bukti_kejadian.mp4',
      exifStripped: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: EvidencePreviewCard(attachment: videoAtt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('bukti_kejadian.mp4'), findsOneWidget);
    expect(find.text('Video siap diputar'), findsOneWidget);
    expect(find.text('Putar Video'), findsOneWidget);

    await tester.tap(find.text('Putar Video'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence_video_player')), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_video_player')), findsNothing);
  });

  testWidgets(
      'Tambah link bukti mendeteksi YouTube & membuka pemutar video tautan',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ReportStoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tambah link bukti'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tambah link bukti'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'https://youtu.be/dQw4w9WgXcQ',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Video YouTube terdeteksi — bisa langsung diputar'),
      findsOneWidget,
    );

    await tester.tap(find.text('Simpan link bukti'));
    await tester.pumpAndSettle();

    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Putar'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Putar'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Putar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putar'));
    await tester.pumpAndSettle();

    expect(find.text('Video YouTube'), findsOneWidget);
    expect(find.byKey(const Key('evidence_embed_player')), findsOneWidget);
    expect(find.text('Buka di tab baru'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_embed_player')), findsNothing);
  });

  testWidgets(
      'Tambah link bukti mendeteksi Google Drive & memvalidasi URL tidak valid',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ReportStoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tambah link bukti'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tambah link bukti'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'bukan tautan');
    await tester.tap(find.text('Simpan link bukti'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Masukkan tautan yang valid'),
      findsOneWidget,
    );
    expect(find.text('Simpan link bukti'), findsOneWidget);

    const driveUrl =
        'https://drive.google.com/file/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/view?usp=sharing';
    await tester.enterText(find.byType(TextField).last, driveUrl);
    await tester.pumpAndSettle();

    expect(
      find.text('File Google Drive terdeteksi — bisa diputar di preview'),
      findsOneWidget,
    );

    await tester.tap(find.text('Simpan link bukti'));
    await tester.pumpAndSettle();

    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('Putar'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Putar'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Putar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Putar'));
    await tester.pumpAndSettle();

    expect(find.text('Preview Google Drive'), findsOneWidget);
    expect(find.byKey(const Key('evidence_embed_player')), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'ReportReviewScreen & ReportDetailScreen menampilkan EvidenceLinkCard yang dapat diputar tanpa overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider
            .overrideWithValue(DummyConnectivityService()),
        secureStorageServiceProvider
            .overrideWithValue(InMemorySecureStorageService()),
      ],
    );
    addTearDown(container.dispose);

    const youtubeUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
    final submitCtrl = container.read(submitReportControllerProvider.notifier);
    submitCtrl
      ..updateNarrative('Terdapat rekaman bukti YouTube pada kejadian ini.')
      ..updateEvidenceLink(youtubeUrl);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReportReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Putar Video'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Putar Video'));
    await tester.pumpAndSettle();

    expect(find.text('Video YouTube'), findsOneWidget);
    expect(find.text('Putar Video'), findsOneWidget);

    await tester.tap(find.text('Putar Video'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_embed_player')), findsOneWidget);
    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();

    final res = await tester.runAsync(submitCtrl.submitCurrentDraft);
    expect(res, isA<Ok<String>>());
    final code = (res! as Ok<String>).value;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReportDetailScreen(reportCode: code)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Putar Video'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Putar Video'));
    await tester.pumpAndSettle();

    expect(find.text('Video YouTube'), findsOneWidget);
    expect(find.text('Putar Video'), findsOneWidget);

    await tester.tap(find.text('Putar Video'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_embed_player')), findsOneWidget);
  });

  testWidgets(
      'EvidencePreviewCard DOCX membuka EvidenceDocxViewer lengkap dengan kontrol zoom teks',
      (tester) async {
    const xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>Kronologi Kejadian</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Bukti laporan siswa</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Catatan Penting</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''';
    final archive = Archive();
    final xmlBytes = utf8.encode(xml);
    archive.addFile(ArchiveFile('word/document.xml', xmlBytes.length, xmlBytes));
    final docxBytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final docxAtt = EvidenceAttachment(
      fileName: 'kronologi_kejadian.docx',
      kind: 'file',
      bytes: docxBytes,
      sizeBytes: docxBytes.length,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: EvidencePreviewCard(attachment: docxAtt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('kronologi_kejadian.docx'), findsOneWidget);
    expect(find.text('Lihat Preview'), findsOneWidget);

    await tester.tap(find.text('Lihat Preview'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence_docx_viewer')), findsOneWidget);
    expect(find.textContaining('Kronologi Kejadian'), findsOneWidget);
    expect(find.textContaining('Bukti laporan siswa'), findsOneWidget);
    expect(find.textContaining('Catatan Penting'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byTooltip('Perbesar teks'));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_docx_viewer')), findsNothing);
  });

  testWidgets(
      'EvidencePreviewCard PDF merender halaman via MethodChannel saat channel tersedia',
      (tester) async {
    const channel = MethodChannel('id.kitatemani/pdf_preview');
    final samplePng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getPageCount') return 2;
      if (call.method == 'renderPage') return samplePng;
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final pdfBytes = Uint8List.fromList(latin1.encode('%PDF-1.4\n%%EOF'));
    final pdfAtt = EvidenceAttachment(
      fileName: 'bukti_surat.pdf',
      kind: 'file',
      bytes: pdfBytes,
      sizeBytes: pdfBytes.length,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: EvidencePreviewCard(attachment: pdfAtt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lihat Preview'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence_pdf_viewer')), findsOneWidget);
    expect(find.byKey(const Key('evidence_pdf_fallback_view')), findsNothing);
    expect(find.textContaining('2 halaman'), findsOneWidget);
    expect(find.text('Halaman 1 / 2'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('evidence_pdf_viewer')), findsNothing);
  });

  testWidgets(
      'EvidencePreviewCard PDF menampilkan fallback metadata saat channel native tidak tersedia',
      (tester) async {
    final pdfBytes = Uint8List.fromList(
      latin1.encode('%PDF-1.5\n1 0 obj\n<< /Type /Page >>\nendobj\n%%EOF'),
    );
    final pdfAtt = EvidenceAttachment(
      fileName: 'laporan_lampiran.pdf',
      kind: 'file',
      bytes: pdfBytes,
      sizeBytes: pdfBytes.length,
      previewUrl: 'https://cdn.example.com/laporan_lampiran.pdf',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: EvidencePreviewCard(attachment: pdfAtt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lihat Preview'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence_pdf_viewer')), findsOneWidget);
    expect(find.byKey(const Key('evidence_pdf_fallback_view')), findsOneWidget);
    expect(find.textContaining('PDF v1.5'), findsOneWidget);
    expect(find.text('Buka / Unduh Dokumen'), findsOneWidget);

    await tester.tap(find.byTooltip('Tutup preview'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Lampiran PDF dengan kind legacy foto tetap dirender sebagai PDF, bukan gambar',
      (tester) async {
    const legacyPdfAtt = EvidenceAttachment(
      fileName: 'Bukti Ujian 19240735 (803).pdf',
      kind: 'foto',
    );
    expect(legacyPdfAtt.isPdf, isTrue);
    expect(legacyPdfAtt.isImage, isFalse);

    final parsedFromString = EvidenceAttachment.fromJson(
      'Bukti Ujian 19240735 (803).pdf',
    );
    expect(parsedFromString.kind, 'file');
    expect(parsedFromString.isPdf, isTrue);
    expect(parsedFromString.isImage, isFalse);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: EvidencePreviewCard(attachment: legacyPdfAtt),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dokumen PDF'), findsOneWidget);
    expect(
      find.text('Ketuk tombol Preview untuk melihat lampiran'),
      findsNothing,
    );

    await tester.tap(find.text('Lihat Preview'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evidence_pdf_viewer')), findsOneWidget);
    expect(
      find.textContaining('Preview gambar belum tersedia'),
      findsNothing,
    );
  });
}
