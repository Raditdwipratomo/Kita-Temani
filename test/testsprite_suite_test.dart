import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/secure_storage_service.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/auth/presentation/screens/school_login_screen.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/curhai/domain/repositories/curhai_repository.dart';
import 'package:kitatemani/features/curhai/presentation/controllers/curhai_controller.dart';
import 'package:kitatemani/features/curhai/presentation/screens/curhai_screen.dart';
import 'package:kitatemani/features/emergency_contacts/data/repositories/emergency_contact_repository_impl.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/screens/add_contact_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/profile_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/my_reports_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_review_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_story_screen.dart';
import 'package:kitatemani/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCurhaiSuiteRepository implements CurhaiRepository {
  @override
  Future<Result<ChatMessage>> sendMessage({
    required String userText,
    required List<ChatMessage> history,
  }) async {
    final lower = userText.toLowerCase();
    final isCrisis = lower.contains('dipukuli') || lower.contains('bunuh');
    return Ok(
      ChatMessage(
        id: 'ts-assistant-${history.length}',
        sender: ChatSender.assistant,
        content: isCrisis
            ? 'Keselamatanmu paling utama. Segera bicara dengan Guru BK atau orang tua lewat Tombol SOS.'
            : 'Aku mendengarkan ceritamu.\n\n- **Tarik napas pelan.** Kamu tidak menghadapi ini sendirian.',
        timestamp: DateTime(2026, 11, 22, 2, 55),
        riskLevel: isCrisis ? CrisisRiskLevel.crisis : CrisisRiskLevel.normal,
      ),
    );
  }
}

Map<String, dynamic> _readJsonObject(String relativePath) {
  final file = File(relativePath);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'Missing TestSprite artifact: $relativePath',
  );
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<Map<String, dynamic>>());
  return decoded as Map<String, dynamic>;
}

Finder _verticalScrollable() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: _verticalScrollable().first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('TestSprite Configuration & Schema Validation', () {
    const jsonFiles = <String>[
      'testsprite_tests/tmp/config.json',
      'testsprite_tests/tmp/code_summary.json',
      'testsprite_tests/standard_prd.json',
      'testsprite_tests/testsprite_frontend_test_plan.json',
      'testsprite_tests/testsprite_backend_test_plan.json',
      'testsprite_tests/mcp_testsprite.json',
    ];

    test('all 6 TestSprite JSON files parse and expose required schema fields',
        () {
      final config = _readJsonObject('testsprite_tests/tmp/config.json');
      expect(config['status'], 'ready');
      expect(config['type'], 'frontend');
      expect(config['scope'], 'codebase');
      expect(config['localPort'], 8089);
      expect(config['localEndpoint'], 'http://localhost:8089');
      expect(config['framework'], 'flutter-web');
      expect(config['executionArgs'], isA<Map<String, dynamic>>());

      final codeSummary =
          _readJsonObject('testsprite_tests/tmp/code_summary.json');
      expect(codeSummary['project_name'], 'KitaTemani');
      expect(codeSummary['tech_stack'], isA<List<dynamic>>());
      expect(codeSummary['routing'], isA<Map<String, dynamic>>());
      expect(codeSummary['features'], isA<List<dynamic>>());
      expect(codeSummary['apis'], isA<List<dynamic>>());

      final prd = _readJsonObject('testsprite_tests/standard_prd.json');
      expect(prd['meta'], isA<Map<String, dynamic>>());
      expect(prd['product_overview'], isA<String>());
      expect(
          (prd['core_goals'] as List<dynamic>).length, greaterThanOrEqualTo(4));
      expect(
          (prd['user_roles'] as List<dynamic>).length, greaterThanOrEqualTo(2));
      expect((prd['key_features'] as List<dynamic>).length,
          greaterThanOrEqualTo(8));
      expect(prd['validation_criteria'], isA<List<dynamic>>());
      expect(prd['safety_and_privacy_invariants'], isA<List<dynamic>>());

      final frontendPlan = _readJsonObject(
          'testsprite_tests/testsprite_frontend_test_plan.json');
      expect(frontendPlan['projectName'], 'KitaTemani');
      expect(frontendPlan['type'], 'frontend');
      expect(frontendPlan['baseUrl'], 'http://localhost:8089');
      expect(frontendPlan['viewports'], isA<List<dynamic>>());

      final backendPlan =
          _readJsonObject('testsprite_tests/testsprite_backend_test_plan.json');
      expect(backendPlan['type'], 'backend');
      expect(backendPlan['testCases'], isA<List<dynamic>>());

      final mcpConfig = _readJsonObject('testsprite_tests/mcp_testsprite.json');
      final servers = mcpConfig['mcpServers'] as Map<String, dynamic>;
      final spriteServer = servers['TestSprite'] as Map<String, dynamic>;
      expect(spriteServer['command'], 'npx');
      expect(
          spriteServer['args'], contains('@testsprite/testsprite-mcp@latest'));

      // Also ensure companion helper files exist.
      for (final helperPath in const <String>[
        'testsprite_tests/ci/testsprite.yml',
        'testsprite_tests/scripts/run_local_server.ps1',
        'testsprite_tests/README.md',
      ]) {
        expect(File(helperPath).existsSync(), isTrue, reason: helperPath);
      }
      expect(jsonFiles.length, 6);
    });

    test(
        'frontend (18) & backend (8) test cases are unique with action + assertion steps',
        () {
      final frontendPlan = _readJsonObject(
          'testsprite_tests/testsprite_frontend_test_plan.json');
      final frontendCases = (frontendPlan['testCases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(frontendCases.length, 18);

      final seenFrontendIds = <String>{};
      for (var i = 0; i < frontendCases.length; i++) {
        final tc = frontendCases[i];
        final expectedId = 'TC${(i + 1).toString().padLeft(3, '0')}';
        expect(tc['id'], expectedId);
        expect(seenFrontendIds.add(tc['id'] as String), isTrue);
        expect((tc['title'] as String).trim(), isNotEmpty);
        expect((tc['description'] as String).trim(), isNotEmpty);
        expect((tc['category'] as String).trim(), isNotEmpty);
        expect((tc['priority'] as String).trim(), isNotEmpty);

        final steps =
            (tc['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(
          steps.any((s) => s['type'] == 'action'),
          isTrue,
          reason: '${tc['id']} must contain at least one action step',
        );
        expect(
          steps.any((s) => s['type'] == 'assertion'),
          isTrue,
          reason: '${tc['id']} must contain at least one assertion step',
        );
      }

      final backendPlan =
          _readJsonObject('testsprite_tests/testsprite_backend_test_plan.json');
      final backendCases = (backendPlan['testCases'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(backendCases.length, 8);

      final seenBackendIds = <String>{};
      for (var i = 0; i < backendCases.length; i++) {
        final btc = backendCases[i];
        final expectedId = 'BTC${(i + 1).toString().padLeft(3, '0')}';
        expect(btc['id'], expectedId);
        expect(seenBackendIds.add(btc['id'] as String), isTrue);
        expect((btc['title'] as String).trim(), isNotEmpty);
        expect((btc['endpoint'] as String).trim(), isNotEmpty);

        final steps =
            (btc['steps'] as List<dynamic>).cast<Map<String, dynamic>>();
        expect(steps.any((s) => s['type'] == 'action'), isTrue);
        expect(steps.any((s) => s['type'] == 'assertion'), isTrue);
      }
    });

    test(
        'configurations contain zero hardcoded secrets and valid codebase paths',
        () {
      final config = _readJsonObject('testsprite_tests/tmp/config.json');
      expect(config['credentialSource'], 'env:TESTSPRITE_API_KEY');
      expect(config.containsKey('apiKey'), isFalse);

      final mcpConfig = _readJsonObject('testsprite_tests/mcp_testsprite.json');
      final env =
          ((mcpConfig['mcpServers'] as Map<String, dynamic>)['TestSprite']
              as Map<String, dynamic>)['env'] as Map<String, dynamic>;
      expect(env['API_KEY'], r'${TESTSPRITE_API_KEY}');

      for (final filePath in const <String>[
        'testsprite_tests/tmp/config.json',
        'testsprite_tests/mcp_testsprite.json',
      ]) {
        final raw = File(filePath).readAsStringSync();
        expect(raw.contains('ts_live_'), isFalse, reason: filePath);
        expect(raw.contains('eyJ'), isFalse, reason: filePath);
      }

      final codeSummary =
          _readJsonObject('testsprite_tests/tmp/code_summary.json');
      final features = (codeSummary['features'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final feature in features) {
        final files = (feature['files'] as List<dynamic>).cast<String>();
        expect(files, isNotEmpty);
        for (final relativePath in files) {
          expect(
            File(relativePath).existsSync(),
            isTrue,
            reason:
                'Feature ${feature['id']} lists missing file: $relativePath',
          );
        }
      }

      final apis =
          (codeSummary['apis'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final api in apis) {
        final filePath = api['file'] as String?;
        if (filePath != null) {
          expect(
            File(filePath).existsSync(),
            isTrue,
            reason: 'API ${api['endpoint']} lists missing file: $filePath',
          );
        }
      }
    });

    test(
        'TestSprite routes and Edge Function contracts uphold safety invariants',
        () {
      final frontendPlanRaw =
          File('testsprite_tests/testsprite_frontend_test_plan.json')
              .readAsStringSync();
      expect(
        RegExp(r'/#(?!/)').hasMatch(frontendPlanRaw),
        isFalse,
        reason: 'Hash routes in test plan must always start with /#/',
      );

      final schoolSummaryFn =
          File('supabase/functions/school-summary/index.ts').readAsStringSync();
      expect(schoolSummaryFn.contains('guru_bk'), isTrue);
      expect(schoolSummaryFn.contains('403'), isTrue);
      expect(schoolSummaryFn.contains('total_reports: 0'), isTrue);
      expect(schoolSummaryFn.contains("top_location: 'Area Sekolah'"), isTrue);

      final curhaiFn =
          File('supabase/functions/curhai-chat/index.ts').readAsStringSync();
      expect(curhaiFn.contains('diejeek'), isFalse);
      expect(curhaiFn.contains('aiResult.content}`'), isFalse);
    });
  });

  group('TestSprite Mapped Frontend E2E Execution', () {
    testWidgets(
      'TC003: Panel Guru BK memblokir akses siswa biasa & terbuka untuk role guru_bk tanpa jargon Qwen',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: KitaTemaniApp(initialRoute: AppRoutes.schoolSummary),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Akses Khusus Guru BK'), findsOneWidget);
        expect(find.text('Kembali ke Beranda'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(KitaTemaniApp)),
        );
        container
            .read(studentProfileProvider.notifier)
            .updateProfile(role: UserRole.guruBk);
        await tester.pumpAndSettle();

        expect(find.text('Insight Sekolah & Panel BK'), findsOneWidget);
        expect(find.text('Ringkasan AI Sekolah'), findsOneWidget);
        expect(find.textContaining('Qwen'), findsNothing);
      },
    );
    testWidgets(
      'TC005: Mood Check-in sudah dihapus dari Beranda & kartu Curhai membuka tab CurhAI',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: KitaTemaniApp(initialRoute: AppRoutes.home),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gimana perasaanmu hari ini?'), findsNothing);
        expect(find.text('Lagi cemas'), findsNothing);

        final curhaiQuickCard = find.text('Cerita pelan-pelan, didengar tanpa dihakimi');
        await _scrollIntoView(tester, curhaiQuickCard);
        await tester.tap(curhaiQuickCard);
        await tester.pumpAndSettle();

        expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);
      },
    );

    testWidgets(
      'TC006: Menu Mode samar sudah dihapus dari halaman Profil',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: KitaTemaniApp(initialRoute: AppRoutes.home),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OwlMascot), findsOneWidget);
        expect(find.text('Gimana perasaanmu hari ini?'), findsNothing);

        await tester.tap(find.text('Profil'));
        await tester.pumpAndSettle();

        await _scrollIntoView(tester, find.text('Pusat bantuan'));

        expect(find.text('Izin Aplikasi'), findsOneWidget);
        expect(find.text('Pusat bantuan'), findsOneWidget);
        expect(find.text('Mode samar'), findsNothing);
        expect(
          find.text('Tampilan aplikasi disamarkan sebagai "Catatan"'),
          findsNothing,
        );
        expect(find.byType(Switch), findsNothing);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(KitaTemaniApp)),
        );
        expect(
          container.read(studentProfileProvider).isDisguisedMode,
          isFalse,
        );

        await tester.tap(find.text('Beranda'));
        await tester.pumpAndSettle();

        expect(find.byType(OwlMascot), findsOneWidget);
      },
    );

    testWidgets(
      'TC007: Alur penuh 3 langkah Laporan Bullying sampai Laporan terkirim! + kode KT-',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(
                DummyConnectivityService(),
              ),
              secureStorageServiceProvider.overrideWithValue(
                InMemorySecureStorageService(),
              ),
            ],
            child: const KitaTemaniApp(initialRoute: AppRoutes.reportType),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Fisik'));
        await tester.pumpAndSettle();

        final locationField = find.byKey(const Key('report_location_input'));
        await _scrollIntoView(tester, locationField);
        expect(find.byType(ChoiceChip), findsNothing);
        await tester.enterText(locationField, 'Dekat kantin lantai 1');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lanjut ke Cerita Kejadian'));
        await tester.pumpAndSettle();

        expect(find.text('Ceritakan kejadiannya'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField).first,
          'Teman sekelas terus mengejek dan menarik tas saat istirahat di kantin.',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tinjau laporan'));
        await tester.pumpAndSettle();

        expect(find.text('Tinjau laporan'), findsOneWidget);
        expect(find.textContaining('Dekat kantin lantai 1'), findsOneWidget);
        await _scrollIntoView(tester, find.text('DIJAGA RAHASIA'));
        expect(find.text('DIJAGA RAHASIA'), findsOneWidget);

        await tester.tap(find.text('Kirim Laporan Sekarang'));
        await tester.pumpAndSettle();

        expect(find.text(L10n.reportSentTitle), findsOneWidget);
        expect(find.textContaining('KT-'), findsWidgets);
        expect(
          tester.widget<KitaIllustration>(find.byType(KitaIllustration)).scene,
          IllustrationScene.reportSent,
        );
      },
    );

    testWidgets(
      'TC012: Tombol aksi cepat CurhAI sudah dihapus & Kartu Krisis CurhAI reset bersih',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curhaiRepositoryProvider.overrideWithValue(
                _FakeCurhaiSuiteRepository(),
              ),
            ],
            child: const MaterialApp(home: CurhaiScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Buat laporan dari obrolan ini'), findsNothing);
        expect(find.text('Latihan napas'), findsNothing);
        expect(find.text('Lanjut cerita…'), findsNothing);

        // TC012: Crisis input triggers red banner without OwlMascot inside; refresh resets it.
        await tester.enterText(
          find.byType(TextField),
          'aku takut sekali dan dipukuli terus',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Buat laporan dari obrolan ini'), findsNothing);
        expect(find.text('Latihan napas'), findsNothing);
        expect(find.text('Lanjut cerita…'), findsNothing);

        expect(find.text('Bicara dengan orang sekarang'), findsOneWidget);
        final crisisCard = find.ancestor(
          of: find.text('Bicara dengan orang sekarang'),
          matching: find.byType(KtCard),
        );
        expect(
          find.descendant(of: crisisCard, matching: find.byType(OwlMascot)),
          findsNothing,
        );

        await tester.tap(find.byTooltip('Mulai obrolan baru'));
        await tester.pumpAndSettle();

        expect(find.text('Bicara dengan orang sekarang'), findsNothing);
        expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);
      },
    );

    testWidgets(
      'TC008: Guardrail form cerita menjaga narasi & mampu menghapus chip tautan bukti',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: ReportStoryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'Saat istirahat di kantin saya diejek teman.',
        );
        await tester.pumpAndSettle();

        await _scrollIntoView(tester, find.text('Tambah link bukti'));
        await tester.tap(find.text('Tambah link bukti'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'https://drive.example.com/bukti-01',
        );
        await tester.tap(find.text('Simpan link bukti'));
        await tester.pumpAndSettle();

        expect(
          find.text('https://drive.example.com/bukti-01'),
          findsWidgets,
        );

        await _scrollIntoView(tester, find.byIcon(Icons.close_rounded));
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        expect(
          find.text('https://drive.example.com/bukti-01'),
          findsNothing,
        );
        expect(
          find.textContaining('Saat istirahat di kantin saya diejek teman.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC015: Kontak Darurat empty state, validasi kosong & digit HP tidak memblokir Simpan kontak',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: KitaTemaniApp(initialRoute: AppRoutes.emergencyContacts),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Belum ada kontak darurat'), findsOneWidget);
        expect(
          tester.widget<KitaIllustration>(find.byType(KitaIllustration)).scene,
          IllustrationScene.guardianContacts,
        );

        await tester.tap(find.text('Tambah kontak baru'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah kontak darurat'), findsOneWidget);
        await tester.tap(find.text('Simpan kontak'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Nama dan nomor HP wajib diisi'), findsWidgets);

        await tester.enterText(find.byType(TextField).at(0), 'Budi');
        await tester.enterText(find.byType(TextField).at(1), '123');
        await tester.tap(find.text('Simpan kontak'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text('Nomor HP tidak valid (minimal 8 digit)'),
          findsWidgets,
        );

        await tester.enterText(find.byType(TextField).at(0), 'Ibu Sari');
        await tester.enterText(find.byType(TextField).at(1), '081234567890');
        await _scrollIntoView(tester, find.text('Jadikan Kontak Utama'));
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

        await tester.tap(find.text('Simpan kontak'));
        await tester.pumpAndSettle();

        expect(find.text('Tambah kontak darurat'), findsNothing);
        expect(find.text('Ibu Sari'), findsOneWidget);
      },
    );

    test(
        'TC015 Repo: DummyEmergencyContactRepository menolak > 5 kontak & menjaga tepat 1 utama',
        () async {
      final repo = DummyEmergencyContactRepository();
      for (var i = 1; i <= 5; i++) {
        final res = await repo.saveContact(
          EmergencyContact(
            id: 'c-$i',
            name: 'Wali $i',
            phone: '08123456780$i',
            roleLabel: 'Orang Tua',
            isPrimary: i == 5,
            isActive: true,
          ),
        );
        expect(res, isA<Ok<List<EmergencyContact>>>());
      }

      final overflowRes = await repo.saveContact(
        const EmergencyContact(
          id: 'c-6',
          name: 'Wali 6',
          phone: '081234567806',
          roleLabel: 'Saudara',
          isPrimary: false,
          isActive: true,
        ),
      );
      expect(overflowRes, isA<Err<List<EmergencyContact>>>());

      final all = await repo.getAll();
      expect(all.length, 5);
      expect(all.where((c) => c.isPrimary).length, 1);
      expect(all.firstWhere((c) => c.isPrimary).name, 'Wali 5');
    });

    testWidgets(
      'TC018: Audit responsif Desktop (1280x800) & Mobile (390x844) seluruh halaman utama & pelaporan',
      (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        tester.view.devicePixelRatio = 1.0;

        for (final viewport in const <Size>[
          Size(1280, 800),
          Size(390, 844),
        ]) {
          tester.view.physicalSize = viewport;

          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(home: SchoolLoginScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Ruang amanmu di sekolah'), findsOneWidget);
          expect(
            tester
                .widget<KitaIllustration>(find.byType(KitaIllustration))
                .scene,
            IllustrationScene.welcomeLogin,
          );
          expect(tester.takeException(), isNull);

          for (final screen in const <Widget>[
            MyReportsTabView(),
            ProfileScreen(isTabView: true),
            ReportStoryScreen(),
            ReportReviewScreen(),
            ReportDetailScreen(reportCode: 'KT-0001-TEST'),
            AddContactScreen(),
          ]) {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(home: screen),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  });
}
