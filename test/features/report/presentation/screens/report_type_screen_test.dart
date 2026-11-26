import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/report_type_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'ReportTypeScreen memakai teks input lokasi bebas, dapat dikosongkan, dan jatuh ke Area Sekolah bila kosong',
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ReportTypeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      BullyingType.values,
      const [BullyingType.fisik, BullyingType.verbal, BullyingType.siber],
    );
    expect(find.text('Fisik'), findsOneWidget);
    expect(find.text('Verbal'), findsOneWidget);
    expect(find.text('Siber (Online)'), findsOneWidget);
    expect(find.text('Sosial'), findsNothing);

    final legacyParsed = AnonymousReportItem.fromJson(const {
      'code': 'KT-LEGACY',
      'types': ['sosial'],
      'location': 'Sekolah',
      'narrative': 'Catatan laporan lama',
      'status': 'diterima',
    });
    expect(legacyParsed.types, const {BullyingType.verbal});

    expect(find.byType(ChoiceChip), findsNothing);
    final locationField = find.byKey(const Key('report_location_input'));

    await tester.scrollUntilVisible(
      locationField,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(locationField);
    await tester.pumpAndSettle();
    expect(locationField, findsOneWidget);

    await tester.enterText(locationField, 'Lorong lab IPA lantai 2');
    await tester.pumpAndSettle();

    expect(
      container.read(submitReportControllerProvider).location,
      'Lorong lab IPA lantai 2',
    );
    expect(find.byTooltip('Hapus lokasi'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus lokasi'));
    await tester.pumpAndSettle();

    expect(container.read(submitReportControllerProvider).location, isEmpty);
    expect(find.byTooltip('Hapus lokasi'), findsNothing);

    final submitFuture = container
        .read(submitReportControllerProvider.notifier)
        .submitCurrentDraft();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final submitRes = await submitFuture;
    expect(submitRes.isOk, isTrue);

    final reports = container.read(myReportsControllerProvider).reports;
    expect(reports.first.location, 'Area Sekolah');
  });

  testWidgets(
      'ReportTypeScreen tampil rapi pada Mobile 390x844 & Desktop 1280x800',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1.0;

    for (final viewport in [const Size(390, 844), const Size(1280, 800)]) {
      tester.view.physicalSize = viewport;
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ReportTypeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final locationField = find.byKey(const Key('report_location_input'));
      await tester.scrollUntilVisible(
        locationField,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(locationField);
      await tester.pumpAndSettle();
      expect(locationField, findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
