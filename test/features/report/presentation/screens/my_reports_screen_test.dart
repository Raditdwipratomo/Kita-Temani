import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/widgets/code_highlighter.dart';
import 'package:kitatemani/core/widgets/status_stepper.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/panic/domain/usecases/activate_panic.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/domain/repositories/report_repository.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/my_reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReportListRepository implements ReportRepository {
  _FakeReportListRepository(this._reports);

  final List<AnonymousReportItem> _reports;

  @override
  Future<Result<List<AnonymousReportItem>>> advanceReportStatus(
    String code, {
    ReportStatus? nextStatus,
    String? note,
  }) async =>
      Ok(_reports);

  @override
  Future<List<AnonymousReportItem>> getMyReports() async => _reports;

  @override
  Future<ReportDetailData> getReportDetail(String code) async {
    final item = _reports.firstWhere(
      (r) => r.code == code,
      orElse: () => _reports.first,
    );
    return ReportDetailData(
      item: item,
      schoolName: 'SMPN 1 Nusantara',
      history: const [],
      messages: const [],
    );
  }

  @override
  Future<List<AnonymousReportItem>> getSchoolReports() async => _reports;

  @override
  Future<Result<ReportChatMessage>> sendReportMessage({
    required String code,
    required String content,
    required String senderLabel,
    bool asCounselor = false,
  }) async =>
      const Err(ServerFailure('unused'));

  @override
  Future<Result<ReportStatus>> statusOf(String code) async =>
      const Ok(ReportStatus.diterima);

  @override
  Future<Result<String>> submit(NewReport draft) async =>
      const Ok('KT-NEW-0001');

  @override
  Future<int> syncOfflineQueue() async => 0;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'MyReportsTabView renders uniform stepper cards for every report and filters by status',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);

      final seededReports = <AnonymousReportItem>[
        AnonymousReportItem(
          code: 'KT-541D-E195',
          types: const {BullyingType.verbal, BullyingType.fisik},
          occurredAt: DateTime(2026, 11, 24),
          location: 'Kelas XI-B',
          narrative: 'Laporan pertama',
          status: ReportStatus.diterima,
          createdAt: DateTime(2026, 11, 24),
        ),
        AnonymousReportItem(
          code: 'KT-ED0D-7478',
          types: const {BullyingType.verbal},
          occurredAt: DateTime(2026, 11, 23),
          location: 'Kantin',
          narrative: 'Laporan kedua',
          status: ReportStatus.ditinjau,
          createdAt: DateTime(2026, 11, 23),
        ),
        AnonymousReportItem(
          code: 'KT-8E66-C30F',
          types: const {BullyingType.fisik},
          occurredAt: DateTime(2026, 11, 16),
          location: 'Kelas',
          narrative: 'Laporan selesai',
          status: ReportStatus.selesai,
          createdAt: DateTime(2026, 11, 16),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportRepositoryProvider.overrideWithValue(
              _FakeReportListRepository(seededReports),
            ),
          ],
          child: const MaterialApp(home: MyReportsTabView()),
        ),
      );
      await tester.pumpAndSettle();

      // Uniform layout: every report renders CodeHighlighter & StatusStepper, without "Riwayat laporan" or "Diproses".
      expect(find.byType(CodeHighlighter), findsNWidgets(3));
      expect(find.byType(StatusStepper), findsNWidgets(3));
      expect(find.text('KT-541D-E195'), findsOneWidget);
      expect(find.text('KT-ED0D-7478'), findsOneWidget);
      expect(find.text('KT-8E66-C30F'), findsOneWidget);
      expect(find.text('Riwayat laporan'), findsNothing);
      expect(find.text('Diproses'), findsNothing);

      // Filter by Selesai (scroll horizontally into view if needed on 430px width)
      final selesaiPill = find.text('Selesai').first;
      await tester.ensureVisible(selesaiPill);
      await tester.pumpAndSettle();
      await tester.tap(selesaiPill);
      await tester.pumpAndSettle();

      expect(find.byType(CodeHighlighter), findsOneWidget);
      expect(find.byType(StatusStepper), findsOneWidget);
      expect(find.text('KT-8E66-C30F'), findsOneWidget);
      expect(find.text('KT-541D-E195'), findsNothing);
      expect(find.text('KT-ED0D-7478'), findsNothing);

      // Back to Semua restores all 3 uniform cards
      final semuaPill = find.text('Semua');
      await tester.ensureVisible(semuaPill);
      await tester.pumpAndSettle();
      await tester.tap(semuaPill);
      await tester.pumpAndSettle();

      expect(find.byType(CodeHighlighter), findsNWidgets(3));
      expect(find.byType(StatusStepper), findsNWidgets(3));
    },
  );

  testWidgets(
    'Counselor Pantau view provides 2 tabs (Laporan and Panic Button) and resolves active SOS alerts',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 1000);

      SharedPreferences.setMockInitialValues(<String, Object>{
        kLocalPanicEventsPrefsKey: jsonEncode([
          {
            'id': 'panic-1',
            'student_name': 'Radit Dwi',
            'class_name': 'XI-2',
            'school_name': 'SMAN 1 Nusantara',
            'location_label': 'Depan Lab Kimia',
            'area_hint': 'Lantai 2',
            'situation_note': 'Diancam / diikuti',
            'status': 'active',
            'started_at': '2026-11-25T10:15:00.000',
          },
        ]),
      });

      final seededReports = <AnonymousReportItem>[
        AnonymousReportItem(
          code: 'KT-BK-1001',
          types: const {BullyingType.verbal},
          occurredAt: DateTime(2026, 11, 25),
          location: 'Kantin',
          narrative: 'Laporan verbal masuk untuk Guru BK.',
          status: ReportStatus.diterima,
          createdAt: DateTime(2026, 11, 25),
        ),
      ];

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reportRepositoryProvider.overrideWithValue(
            _FakeReportListRepository(seededReports),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(studentProfileProvider.notifier).updateProfile(
            name: 'Bu Rina, S.Pd.',
            shortName: 'Bu Rina',
            className: 'Ruang BK',
            schoolId: defaultSchoolSlug,
            schoolName: defaultSchoolName,
            isProfileCompleted: true,
            role: UserRole.guruBk,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MyReportsTabView()),
        ),
      );
      await tester.pumpAndSettle();

      // Default tab is Laporan (2 tabs only: Laporan & Panic Button)
      expect(find.byKey(const Key('pantau_category_semua')), findsNothing);
      expect(find.byKey(const Key('pantau_category_laporan')), findsOneWidget);
      expect(find.byKey(const Key('pantau_category_panic')), findsOneWidget);
      expect(find.text('KT-BK-1001'), findsOneWidget);
      expect(find.text('Radit Dwi (XI-2)'), findsNothing);

      // Switch to Panic Button tab and mark SOS alert as handled
      final panicTab = find.byKey(const Key('pantau_category_panic'));
      await tester.ensureVisible(panicTab);
      await tester.pumpAndSettle();
      await tester.tap(panicTab);
      await tester.pumpAndSettle();
      expect(find.text('Radit Dwi (XI-2)'), findsOneWidget);
      expect(find.text('KT-BK-1001'), findsNothing);
      expect(find.text('SOS Aktif'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pantau_resolve_panic_panic-1')));
      await tester.pumpAndSettle();

      expect(find.text('Tertangani'), findsOneWidget);
      expect(find.text('SOS Aktif'), findsNothing);

      // Switch back to Laporan tab
      await tester.tap(find.byKey(const Key('pantau_category_laporan')));
      await tester.pumpAndSettle();
      expect(find.text('KT-BK-1001'), findsOneWidget);
      expect(find.text('Radit Dwi (XI-2)'), findsNothing);
    },
  );
}
