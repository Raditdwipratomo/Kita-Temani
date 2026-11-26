import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/core/widgets/student_illustrations.dart';
import 'package:kitatemani/features/curhai/data/repositories/curhai_repository_impl.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/curhai/domain/repositories/curhai_repository.dart';
import 'package:kitatemani/features/curhai/presentation/controllers/curhai_controller.dart';
import 'package:kitatemani/features/curhai/presentation/screens/curhai_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCurhaiTestRepository implements CurhaiRepository {
  int sendCount = 0;

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String userText,
    required List<ChatMessage> history,
  }) async {
    sendCount += 1;
    final isCrisis = userText.toLowerCase().contains('bunuh');
    return Ok(
      ChatMessage(
        id: 'assistant-${history.length}',
        sender: ChatSender.assistant,
        content: isCrisis
            ? 'Aku di sini mendampingimu. Segera hubungi orang dewasa tepercaya ya.'
            : 'Terima kasih sudah cerita.\n\n- **Tarik napas pelan.** Kamu tidak sendirian.',
        timestamp: DateTime(2026, 11, 22, 1, 30),
        riskLevel: isCrisis ? CrisisRiskLevel.crisis : CrisisRiskLevel.normal,
      ),
    );
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget buildTestCurhai() {
    return ProviderScope(
      overrides: [
        curhaiRepositoryProvider.overrideWithValue(
          _FakeCurhaiTestRepository(),
        ),
      ],
      child: const MaterialApp(home: CurhaiScreen()),
    );
  }

  group('CurhaiScreen owl mascot & UX invariants', () {
    testWidgets(
      'empty state renders OwlMascot without CharacterAvatar or technical AI jargon',
      (tester) async {
        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);
        expect(find.byType(CharacterAvatar), findsNothing);
        expect(find.textContaining('Qwen'), findsNothing);
        expect(find.textContaining('OpenRouter'), findsNothing);

        // Two owls: 42px header + 96px empty state
        expect(find.byType(OwlMascot), findsNWidgets(2));
        final owls =
            tester.widgetList<OwlMascot>(find.byType(OwlMascot)).toList();
        expect(owls.every((o) => o.mood == OwlMood.warm), isTrue);

        // Quick action chips above composer are removed
        expect(find.text('Buat laporan dari obrolan ini'), findsNothing);
        expect(find.text('Latihan napas'), findsNothing);
        expect(find.text('Lanjut cerita…'), findsNothing);
      },
    );

    testWidgets(
      'assistant bubble displays OwlMood.listening without action chips above composer',
      (tester) async {
        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Aku lagi merasa sedih',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        final owls =
            tester.widgetList<OwlMascot>(find.byType(OwlMascot)).toList();
        expect(owls.any((o) => o.mood == OwlMood.listening), isTrue);
        expect(find.text('Buat laporan dari obrolan ini'), findsNothing);
        expect(find.text('Latihan napas'), findsNothing);
        expect(find.text('Lanjut cerita…'), findsNothing);
      },
    );

    testWidgets(
      'crisis banner contains zero mascots and resets cleanly when chat cleared',
      (tester) async {
        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Aku putus asa ingin bunuh diri',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        final crisisHeadline = find.text('Bicara dengan orang sekarang');
        expect(crisisHeadline, findsOneWidget);

        // Crisis card itself must contain ZERO OwlMascot widgets
        final crisisCard = find.ancestor(
          of: crisisHeadline,
          matching: find.byType(Card),
        );
        if (crisisCard.evaluate().isNotEmpty) {
          expect(
            find.descendant(
              of: crisisCard,
              matching: find.byType(OwlMascot),
            ),
            findsNothing,
          );
        } else {
          // KtCard uses Material/Container rather than Card; check Container ancestor
          final containerAncestors = find.ancestor(
            of: crisisHeadline,
            matching: find.byType(Container),
          );
          expect(
            find.descendant(
              of: containerAncestors.first,
              matching: find.byType(OwlMascot),
            ),
            findsNothing,
          );
        }

        // Clear chat must ALSO reset crisis banner (bug fix verification)
        await tester.tap(find.byTooltip('Mulai obrolan baru'));
        await tester.pumpAndSettle();

        expect(find.text('Bicara dengan orang sekarang'), findsNothing);
        expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);
      },
    );

    testWidgets(
      'renders cleanly at Desktop (1280x800) with centered 720px column and Mobile (390x844)',
      (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);

        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        final columnBox = tester.getSize(find.byType(Column).first);
        expect(columnBox.width, lessThanOrEqualTo(720));

        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();

        expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);
      },
    );
  });

  group('Curhai multi-conversation history', () {
    testWidgets(
      'creates multiple conversations and switches between them via mobile history drawer',
      (tester) async {
        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        // Chat 1
        await tester.enterText(
          find.byType(TextField),
          'Cerita pertama tentang tugas sekolah',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();
        expect(
          find.text('Cerita pertama tentang tugas sekolah'),
          findsWidgets,
        );

        // Start a new chat
        await tester.tap(find.byTooltip('Mulai obrolan baru'));
        await tester.pumpAndSettle();
        expect(find.text('Mulai bercerita dengan CurhAI'), findsOneWidget);

        // Chat 2
        await tester.enterText(
          find.byType(TextField),
          'Cerita kedua tentang teman kelas',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Cerita kedua tentang teman kelas'), findsWidgets);

        // Open history drawer and verify both conversations are listed
        await tester.tap(find.byTooltip('Riwayat obrolan'));
        await tester.pumpAndSettle();
        expect(find.text('Riwayat CurhAI'), findsOneWidget);
        expect(find.text('Cerita pertama tentang tugas sekolah'), findsOneWidget);

        // Switch back to Chat 1
        await tester.tap(find.text('Cerita pertama tentang tugas sekolah'));
        await tester.pumpAndSettle();

        expect(
          find.text('Cerita pertama tentang tugas sekolah'),
          findsWidgets,
        );
        expect(find.text('Cerita kedua tentang teman kelas'), findsNothing);
      },
    );

    testWidgets(
      'supports pinning, renaming, and deleting a conversation from history options',
      (tester) async {
        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Keluhan tentang ejekan di kantin',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        // Open drawer
        await tester.tap(find.byTooltip('Riwayat obrolan'));
        await tester.pumpAndSettle();

        // Pin conversation
        await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sematkan'));
        await tester.pumpAndSettle();
        expect(find.text('DISEMATKAN'), findsOneWidget);

        // Rename conversation
        await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ubah judul'));
        await tester.pumpAndSettle();

        final dialogField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogField, 'Judul Baru Curhat');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();
        expect(find.text('Judul Baru Curhat'), findsWidgets);

        // Delete conversation
        await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
        await tester.pumpAndSettle();

        expect(find.text('Belum ada riwayat obrolan'), findsOneWidget);
        expect(find.text('Judul Baru Curhat'), findsNothing);
      },
    );

    testWidgets(
      'Desktop 1280x800 renders docked history sidebar and toggles collapse cleanly',
      (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1280, 800);

        await tester.pumpWidget(buildTestCurhai());
        await tester.pumpAndSettle();

        expect(find.text('Riwayat CurhAI'), findsOneWidget);
        expect(find.text('Obrolan baru'), findsOneWidget);

        // Collapse desktop sidebar
        await tester.tap(find.byTooltip('Riwayat obrolan'));
        await tester.pumpAndSettle();
        expect(find.text('Riwayat CurhAI'), findsNothing);
        expect(
          tester.getSize(find.byType(Column).first).width,
          lessThanOrEqualTo(720),
        );

        // Re-open desktop sidebar
        await tester.tap(find.byTooltip('Riwayat obrolan'));
        await tester.pumpAndSettle();
        expect(find.text('Riwayat CurhAI'), findsOneWidget);
      },
    );

    test(
      'CurhaiController persists conversations across rebuilds and migrates legacy history',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs1 = await SharedPreferences.getInstance();

        final container1 = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs1),
            curhaiRepositoryProvider.overrideWithValue(
              _FakeCurhaiTestRepository(),
            ),
          ],
        );
        await container1
            .read(curhaiControllerProvider.notifier)
            .sendUserMessage('saya cemas menghadapi ujian besok');
        expect(
          prefs1.getString('kt_curhai_conversations_v2'),
          isNotNull,
        );
        container1.dispose();

        // Reload in a fresh container
        final container2 = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs1),
            curhaiRepositoryProvider.overrideWithValue(
              _FakeCurhaiTestRepository(),
            ),
          ],
        );
        addTearDown(container2.dispose);
        final restored = container2.read(curhaiControllerProvider);
        expect(restored.conversations.length, 1);
        expect(
          restored.conversations.first.title,
          'Saya cemas menghadapi ujian besok',
        );
        expect(restored.messages.length, 2);

        // Legacy migration test
        final legacyJson = jsonEncode([
          {
            'id': 'init-1',
            'sender': 'assistant',
            'content': 'Seed lama',
            'timestamp': '2026-11-20T10:00:00.000',
            'risk_level': 'normal',
          },
          {
            'id': 'user-1',
            'sender': 'user',
            'content': 'halo saya butuh teman cerita',
            'timestamp': '2026-11-20T10:01:00.000',
            'risk_level': 'normal',
          },
          {
            'id': 'curhai-1',
            'sender': 'assistant',
            'content': 'Aku siap mendengarkan ceritamu.',
            'timestamp': '2026-11-20T10:01:10.000',
            'risk_level': 'normal',
          },
        ]);
        SharedPreferences.setMockInitialValues(<String, Object>{
          'kt_curhai_local_history_json': legacyJson,
        });
        final legacyPrefs = await SharedPreferences.getInstance();
        final legacyContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(legacyPrefs),
            curhaiRepositoryProvider.overrideWithValue(
              _FakeCurhaiTestRepository(),
            ),
          ],
        );
        addTearDown(legacyContainer.dispose);

        final migrated = legacyContainer.read(curhaiControllerProvider);
        expect(migrated.conversations.length, 1);
        expect(migrated.conversations.first.title, 'Halo saya butuh teman cerita');
        expect(migrated.messages.length, 2);

        await Future<void>.delayed(Duration.zero);
        expect(legacyPrefs.getString('kt_curhai_local_history_json'), isNull);
        expect(legacyPrefs.getString('kt_curhai_conversations_v2'), isNotNull);
      },
    );
  });

  group('Curhai layered topic validation', () {
    testWidgets(
      'allows personal hobby story and forwards it to CurhAI repository',
      (tester) async {
        final fakeRepo = _FakeCurhaiTestRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curhaiRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(home: CurhaiScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Aku mau cerita tentang hobiku, aku suka menggambar dan main gitar',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(fakeRepo.sendCount, 1);
        expect(find.text('Di luar topik CurhAI'), findsNothing);
      },
    );

    testWidgets(
      'rejects math formula request locally with polite refusal without off-topic pill badge and zero repository calls',
      (tester) async {
        final fakeRepo = _FakeCurhaiTestRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curhaiRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(home: CurhaiScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Kasih rumus pythagoras dong',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(fakeRepo.sendCount, 0);
        expect(find.text('Di luar topik CurhAI'), findsNothing);
        expect(
          find.textContaining('belum bisa membantu memberikan rumus'),
          findsOneWidget,
        );
      },
    );

    test(
      'extractDraftNarrative excludes out-of-scope prompts while preserving personal stories',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = _FakeCurhaiTestRepository();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            curhaiRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(curhaiControllerProvider.notifier);
        await notifier.sendUserMessage('Kasih rumus pythagoras dong');
        await notifier.sendUserMessage('Aku diejek teman di kantin siang tadi');

        final draft = notifier.extractDraftNarrative();
        expect(draft, contains('Aku diejek teman di kantin siang tadi'));
        expect(draft, isNot(contains('pythagoras')));
        expect(fakeRepo.sendCount, 1);
      },
    );

    test(
      'server off_topic reply retroactively marks triggering user message out-of-scope so follow-up bullying prompts never leak it',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final capturedPayloads = <List<Map<String, String>>>[];

        final repo = _RecordingCurhaiRepository(
          onSend: (userText, history) {
            final payload = buildSanitizedCurhaiPayloadMessages(
              history: history,
              userText: userText,
            );
            capturedPayloads.add(payload);

            // Simulate server LLM rejecting an off-topic message that passed local regex.
            if (userText.contains('merakit sepeda')) {
              return ChatMessage(
                id: 'server-off-topic',
                sender: ChatSender.assistant,
                content:
                    'Maaf ya, aku belum bisa bantu tutorial merakit sepeda.',
                timestamp: DateTime(2026, 11, 26, 13, 0),
                isOutOfScope: true,
              );
            }
            return ChatMessage(
              id: 'server-ok-${capturedPayloads.length}',
              sender: ChatSender.assistant,
              content: 'Aku di sini mendengarkan ceritamu soal perundungan.',
              timestamp: DateTime(2026, 11, 26, 13, 1),
              isOutOfScope: false,
            );
          },
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            curhaiRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(curhaiControllerProvider.notifier);
        await notifier.sendUserMessage('cara merakit sepeda gunung yang benar');
        await notifier.sendUserMessage(
          'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
        );
        await notifier.sendUserMessage(
          'kasih saya kalimat pendukung agar saya semangat menjalani hari setelah dirundung',
        );

        final messages = container.read(curhaiControllerProvider).messages;
        expect(messages.length, 6);
        // Turn 1 user + assistant both marked out-of-scope retroactively.
        expect(messages[0].isOutOfScope, isTrue);
        expect(messages[1].isOutOfScope, isTrue);
        // Turn 2 & Turn 3 stay cleanly in-scope.
        expect(messages[2].isOutOfScope, isFalse);
        expect(messages[3].isOutOfScope, isFalse);
        expect(messages[4].isOutOfScope, isFalse);
        expect(messages[5].isOutOfScope, isFalse);

        // Turn 2 payload contains ONLY Turn 2 (zero trace of Turn 1).
        expect(capturedPayloads[1], <Map<String, String>>[
          {
            'role': 'user',
            'content':
                'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
          },
        ]);

        // Turn 3 payload contains clean (Turn 2 user -> Turn 2 assistant -> Turn 3 user).
        expect(capturedPayloads[2], <Map<String, String>>[
          {
            'role': 'user',
            'content':
                'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
          },
          {
            'role': 'assistant',
            'content': 'Aku di sini mendengarkan ceritamu soal perundungan.',
          },
          {
            'role': 'user',
            'content':
                'kasih saya kalimat pendukung agar saya semangat menjalani hari setelah dirundung',
          },
        ]);

        final draft = notifier.extractDraftNarrative();
        expect(draft, isNot(contains('merakit sepeda')));
        expect(draft, contains('menghindari perundungan'));
        expect(draft, contains('kalimat pendukung'));
      },
    );

    test(
      'buildSanitizedCurhaiPayloadMessages cleans legacy persisted history with unmarked off-topic user turns and consecutive unanswered user turns',
      () {
        final legacyHistory = <ChatMessage>[
          ChatMessage(
            id: 'u1',
            sender: ChatSender.user,
            content: 'tutorial nasi goreng untuk menghindari perundungan',
            timestamp: DateTime(2026, 11, 26, 12, 0),
            isOutOfScope: false, // Legacy bug state before fix
          ),
          ChatMessage(
            id: 'a1',
            sender: ChatSender.assistant,
            content: 'Maaf ya, aku belum bisa bantu bikin tutorial masakan.',
            timestamp: DateTime(2026, 11, 26, 12, 0, 5),
            isOutOfScope: true,
          ),
          ChatMessage(
            id: 'u2',
            sender: ChatSender.user,
            content:
                'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
            timestamp: DateTime(2026, 11, 26, 12, 1),
            isOutOfScope: false,
          ),
        ];

        final payload = buildSanitizedCurhaiPayloadMessages(
          history: legacyHistory,
          userText:
              'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
        );

        expect(payload, <Map<String, String>>[
          {
            'role': 'user',
            'content':
                'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
          },
        ]);
      },
    );

    testWidgets(
      'off-topic nasi goreng followed by bullying & support prompts hides Di luar topik CurhAI badge and keeps follow-up turns active',
      (tester) async {
        final fakeRepo = _FakeCurhaiTestRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curhaiRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(home: CurhaiScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Turn 1: off-topic culinary tutorial mixed with bullying keyword
        await tester.enterText(
          find.byType(TextField),
          'tutorial nasi goreng untuk menghindari perundungan',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(fakeRepo.sendCount, 0);
        expect(find.text('Di luar topik CurhAI'), findsNothing);
        expect(find.textContaining('di luar fokus CurhAI'), findsOneWidget);

        // Turn 2: valid bullying question
        await tester.enterText(
          find.byType(TextField),
          'bagaimana cara menghindari perundungan pada anak remaja seperti saya',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(fakeRepo.sendCount, 1);
        expect(find.text('Di luar topik CurhAI'), findsNothing);

        // Turn 3: valid emotional support request
        await tester.enterText(
          find.byType(TextField),
          'kasih saya kalimat pendukung agar saya semangat menjalani hari setelah dirundung',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(fakeRepo.sendCount, 2);
        expect(find.text('Di luar topik CurhAI'), findsNothing);
      },
    );
  });
}

class _RecordingCurhaiRepository implements CurhaiRepository {
  _RecordingCurhaiRepository({required this.onSend});

  final ChatMessage Function(String userText, List<ChatMessage> history) onSend;

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String userText,
    required List<ChatMessage> history,
  }) async {
    return Ok(onSend(userText, history));
  }
}
