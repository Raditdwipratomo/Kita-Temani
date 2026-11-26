import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/report/data/datasources/report_remote_data_source.dart';
import 'package:kitatemani/features/report/data/models/report_dto.dart';
import 'package:kitatemani/features/report/data/repositories/report_repository_impl.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemoteReportDataSource extends ReportRemoteDataSource {
  _FakeRemoteReportDataSource({required this.activeUidProvider});

  final String? Function() activeUidProvider;
  final Map<String, List<AnonymousReportItem>> reportsByUser =
      <String, List<AnonymousReportItem>>{};
  final List<AnonymousReportItem> schoolReports = <AnonymousReportItem>[];
  List<String>? lastFetchedCodes;

  @override
  bool get isRemoteEnabled => true;

  @override
  bool get hasAuthenticatedSession => activeUidProvider() != null;

  @override
  String? get currentUserId => activeUidProvider();

  @override
  Future<List<EvidenceAttachment>> uploadAttachments({
    required String reportKey,
    required List<EvidenceAttachment> items,
  }) async =>
      items;

  @override
  Future<String> submit(NewReportDto dto) async {
    final uid = activeUidProvider() ?? 'anon';
    final code = 'KT-${uid.toUpperCase()}-${(reportsByUser[uid]?.length ?? 0) + 1}';
    final item = AnonymousReportItem(
      code: code,
      types: const {BullyingType.verbal},
      occurredAt: DateTime(2026, 11, 25),
      location: dto.location,
      narrative: dto.narrative,
      status: ReportStatus.diterima,
      createdAt: DateTime(2026, 11, 25),
    );
    reportsByUser.putIfAbsent(uid, () => <AnonymousReportItem>[]).add(item);
    schoolReports.add(item);
    return code;
  }

  @override
  Future<List<AnonymousReportItem>> fetchMyReports(List<String> codes) async {
    lastFetchedCodes = List<String>.from(codes);
    final uid = activeUidProvider();
    if (uid == null) return const [];
    return List<AnonymousReportItem>.from(reportsByUser[uid] ?? const []);
  }

  @override
  Future<List<AnonymousReportItem>> fetchSchoolReports() async {
    return List<AnonymousReportItem>.from(schoolReports);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Report per-user isolation', () {
    test(
      'isolates local reports, secure codes, and remote reconciliation across accounts',
      () async {
        final prefs = LocalPreferencesService(
          await SharedPreferences.getInstance(),
        );
        final storage = InMemorySecureStorageService();
        String? activeUid = 'user-a';

        final remote = _FakeRemoteReportDataSource(
          activeUidProvider: () => activeUid,
        );
        final codeStore = SecureReportCodeStore(
          storage,
          userScopeResolver: () => activeUid ?? 'guest',
        );
        final repo = ReportRepositoryImpl(
          remote,
          prefs: prefs,
          connectivity: DummyConnectivityService(),
          codeStore: codeStore,
          userScopeResolver: () => activeUid ?? 'guest',
        );

        // User A submits a report
        final submitA = await repo.submit(
          NewReport(
            idempotencyKey: 'key-a-1',
            schoolId: defaultSchoolSlug,
            types: const {BullyingType.verbal},
            occurredAt: DateTime(2026, 11, 25),
            whenLabel: '25 Nov 2026',
            location: 'Kantin',
            narrative: 'Laporan khusus milik akun pertama di kantin sekolah.',
          ),
        );
        expect(submitA, isA<Ok<String>>());
        final codeA = (submitA as Ok<String>).value;

        final userAReports = await repo.getMyReports();
        expect(userAReports.map((r) => r.code), equals([codeA]));

        // Switch directly to User B (without even calling signOut first)
        activeUid = 'user-b';
        final userBReports = await repo.getMyReports();
        expect(userBReports, isEmpty);
        expect(remote.lastFetchedCodes, isEmpty);

        // User B submits their own report
        final submitB = await repo.submit(
          NewReport(
            idempotencyKey: 'key-b-1',
            schoolId: defaultSchoolSlug,
            types: const {BullyingType.fisik},
            occurredAt: DateTime(2026, 11, 25),
            whenLabel: '25 Nov 2026',
            location: 'Lapangan',
            narrative: 'Laporan khusus milik akun kedua di lapangan sekolah.',
          ),
        );
        expect(submitB, isA<Ok<String>>());
        final codeB = (submitB as Ok<String>).value;

        final userBReportsAfter = await repo.getMyReports();
        expect(userBReportsAfter.map((r) => r.code), equals([codeB]));
        expect(userBReportsAfter.any((r) => r.code == codeA), isFalse);

        // Switch back to User A -> sees only User A's report
        activeUid = 'user-a';
        final userAReportsAgain = await repo.getMyReports();
        expect(userAReportsAgain.map((r) => r.code), equals([codeA]));
      },
    );

    test(
      'keeps school reports separate from student my-reports and reconciles stale cache',
      () async {
        final prefs = LocalPreferencesService(
          await SharedPreferences.getInstance(),
        );
        final storage = InMemorySecureStorageService();
        const activeUid = 'user-a';

        final remote = _FakeRemoteReportDataSource(
          activeUidProvider: () => activeUid,
        );
        remote.schoolReports.add(
          AnonymousReportItem(
            code: 'KT-OTHER-1',
            types: const {BullyingType.siber},
            occurredAt: DateTime(2026, 11, 24),
            location: 'Grup Kelas',
            narrative: 'Laporan siswa lain di sekolah.',
            status: ReportStatus.ditinjau,
            createdAt: DateTime(2026, 11, 24),
          ),
        );

        final repo = ReportRepositoryImpl(
          remote,
          prefs: prefs,
          connectivity: DummyConnectivityService(),
          codeStore: SecureReportCodeStore(
            storage,
            userScopeResolver: () => activeUid,
          ),
          userScopeResolver: () => activeUid,
        );

        // Even if getSchoolReports was fetched under the same scope,
        // getMyReports must not inherit school-wide reports.
        final school = await repo.getSchoolReports();
        expect(school.map((e) => e.code), equals(['KT-OTHER-1']));

        final my = await repo.getMyReports();
        expect(my, isEmpty);

        // Even if stale non-pending data was somehow written into my-cache,
        // authoritative remote fetch reconciles and removes stale items.
        await prefs.setJsonList('kt_reports_v2_my_user-a', [
          AnonymousReportItem(
            code: 'KT-STALE-99',
            types: const {BullyingType.verbal},
            occurredAt: DateTime(2026, 11, 20),
            location: 'Koridor',
            narrative: 'Cache lama yang bukan milik user ini.',
            status: ReportStatus.diterima,
            createdAt: DateTime(2026, 11, 20),
          ).toJson(),
        ]);

        final reconciled = await repo.getMyReports();
        expect(reconciled, isEmpty);
      },
    );

    test(
      'FullstackAuthRepository.signOut clears report caches and secure codes',
      () async {
        final prefs = LocalPreferencesService(
          await SharedPreferences.getInstance(),
        );
        final storage = InMemorySecureStorageService();

        await prefs.setJsonList('kt_reports_v2_my_user-a', [
          AnonymousReportItem(
            code: 'KT-OLD-1',
            types: const {BullyingType.verbal},
            occurredAt: DateTime(2026, 11, 20),
            location: 'Kelas',
            narrative: 'Laporan lama sebelum logout.',
            status: ReportStatus.diterima,
            createdAt: DateTime(2026, 11, 20),
          ).toJson(),
        ]);
        await storage.write('report_codes_v2_user-a', 'KT-OLD-1');

        final authRepo = FullstackAuthRepository(
          client: null,
          prefs: prefs,
          secureStorage: storage,
        );
        await authRepo.signOut();

        expect(prefs.getJsonList('kt_reports_v2_my_user-a'), isEmpty);
        expect(await storage.read('report_codes_v2_user-a'), isNull);
      },
    );

    test(
      'MyReportsController refreshes automatically when switching between two student IDs',
      () async {
        final prefs = LocalPreferencesService(
          await SharedPreferences.getInstance(),
        );
        final storage = InMemorySecureStorageService();
        String? activeUid = 'student-a';

        final remote = _FakeRemoteReportDataSource(
          activeUidProvider: () => activeUid,
        );
        remote.reportsByUser['student-a'] = [
          AnonymousReportItem(
            code: 'KT-STU-A',
            types: const {BullyingType.verbal},
            occurredAt: DateTime(2026, 11, 25),
            location: 'Kelas A',
            narrative: 'Laporan milik siswa A.',
            status: ReportStatus.diterima,
            createdAt: DateTime(2026, 11, 25),
          ),
        ];
        remote.reportsByUser['student-b'] = [
          AnonymousReportItem(
            code: 'KT-STU-B',
            types: const {BullyingType.fisik},
            occurredAt: DateTime(2026, 11, 25),
            location: 'Kelas B',
            narrative: 'Laporan milik siswa B.',
            status: ReportStatus.ditinjau,
            createdAt: DateTime(2026, 11, 25),
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            localPreferencesServiceProvider.overrideWithValue(prefs),
            secureStorageServiceProvider.overrideWithValue(storage),
            reportRemoteDataSourceProvider.overrideWithValue(remote),
            reportRepositoryProvider.overrideWith(
              (ref) => ReportRepositoryImpl(
                remote,
                prefs: prefs,
                connectivity: DummyConnectivityService(),
                codeStore: SecureReportCodeStore(
                  storage,
                  userScopeResolver: () => activeUid ?? 'guest',
                ),
                userScopeResolver: () => activeUid ?? 'guest',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Listen so controller stays active and verify Student A reports
        final sub = container.listen(myReportsControllerProvider, (_, __) {});
        addTearDown(sub.close);

        container.read(studentProfileProvider.notifier).state =
            const StudentProfile(
          id: 'student-a',
          schoolId: defaultSchoolSlug,
          schoolName: defaultSchoolName,
          name: 'Siswa A',
          shortName: 'Siswa',
          className: 'XI-1',
          safeDaysCount: 1,
          counselorName: defaultCounselorName,
          isProfileCompleted: true,
          role: UserRole.siswa,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          container
              .read(myReportsControllerProvider)
              .reports
              .map((r) => r.code),
          equals(['KT-STU-A']),
        );

        // Switch to Student B (same role UserRole.siswa, different id!)
        activeUid = 'student-b';
        container.read(studentProfileProvider.notifier).state =
            const StudentProfile(
          id: 'student-b',
          schoolId: defaultSchoolSlug,
          schoolName: defaultSchoolName,
          name: 'Siswa B',
          shortName: 'Siswa',
          className: 'XI-2',
          safeDaysCount: 1,
          counselorName: defaultCounselorName,
          isProfileCompleted: true,
          role: UserRole.siswa,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          container
              .read(myReportsControllerProvider)
              .reports
              .map((r) => r.code),
          equals(['KT-STU-B']),
        );
      },
    );
  });
}
