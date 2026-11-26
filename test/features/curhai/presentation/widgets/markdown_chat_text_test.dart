import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/curhai/domain/repositories/curhai_repository.dart';
import 'package:kitatemani/features/curhai/presentation/controllers/curhai_controller.dart';
import 'package:kitatemani/features/curhai/presentation/screens/curhai_screen.dart';
import 'package:kitatemani/features/curhai/presentation/widgets/markdown_chat_text.dart';

class _FakeMarkdownCurhaiRepository implements CurhaiRepository {
  @override
  Future<Result<ChatMessage>> sendMessage({
    required String userText,
    required List<ChatMessage> history,
  }) async {
    return Ok(
      ChatMessage(
        id: 'assistant-1',
        sender: ChatSender.assistant,
        content: 'Beberapa langkah aman:\n\n'
            '- **Cari teman, jangan sendirian.** Tetap di dekat teman yang kamu percaya.\n'
            '- **Simpan bukti.** Screenshot chat kalau perlu dilaporkan.',
        timestamp: DateTime(2026, 11, 21, 23, 30),
      ),
    );
  }
}

List<TextSpan> _flattenSpans(InlineSpan span) {
  final result = <TextSpan>[];
  if (span is TextSpan) {
    if (span.text != null && span.text!.isNotEmpty) {
      result.add(span);
    }
    final children = span.children;
    if (children != null) {
      for (final child in children) {
        result.addAll(_flattenSpans(child));
      }
    }
  }
  return result;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const baseStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: Color(0xFF1D224A),
  );

  group('parseMarkdownInlineSpans', () {
    test('parses bold, italic, bold+italic, code, strike, and links', () {
      const input =
          'Biasa **tebal** dan __tebal2__ lalu *miring* serta _miring2_, '
          '***tebal miring***, ~~coret~~, `guru_bk`, dan '
          '[Panduan](https://kitatemani.id).';
      final spans = parseMarkdownInlineSpans(input, baseStyle)
          .expand(_flattenSpans)
          .toList();

      final combinedText = spans.map((s) => s.text).join();
      expect(combinedText, isNot(contains('**')));
      expect(combinedText, isNot(contains('__')));
      expect(combinedText, isNot(contains('~~')));
      expect(combinedText, isNot(contains('`')));
      expect(combinedText, isNot(contains('https://')));

      expect(
        spans.any(
          (s) => s.text == 'tebal' && s.style?.fontWeight == FontWeight.w700,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.text == 'tebal2' && s.style?.fontWeight == FontWeight.w700,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.text == 'miring' && s.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.text == 'miring2' && s.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) =>
              s.text == 'tebal miring' &&
              s.style?.fontWeight == FontWeight.w700 &&
              s.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) =>
              s.text == 'coret' &&
              s.style?.decoration == TextDecoration.lineThrough,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.text == 'guru_bk' && s.style?.fontFamily == 'monospace',
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) =>
              s.text == 'Panduan' &&
              s.style?.decoration == TextDecoration.underline,
        ),
        isTrue,
      );
    });

    test('preserves snake_case, math asterisks, and unclosed delimiters', () {
      const input =
          'Hubungi guru_bk_1 untuk 2 * 3 hal, atau **tanpa penutup dan \\*literal\\*';
      final spans = parseMarkdownInlineSpans(input, baseStyle)
          .expand(_flattenSpans)
          .toList();

      final combined = spans.map((s) => s.text).join();
      expect(combined, contains('guru_bk_1'));
      expect(combined, contains('2 * 3'));
      expect(combined, contains('**tanpa penutup'));
      expect(combined, contains('*literal*'));
      expect(
        spans.any((s) => s.style?.fontStyle == FontStyle.italic),
        isFalse,
      );
    });

    test('handles nested bold/italic and invokes resolveStyle', () {
      var resolveCalls = 0;
      final spans = parseMarkdownInlineSpans(
        '**tebal dengan *miring* di dalam** dan ***penting** banget*',
        baseStyle,
        resolveStyle: (s) {
          resolveCalls++;
          return s.copyWith(fontFamily: 'ResolvedInter');
        },
      ).expand(_flattenSpans).toList();

      expect(resolveCalls, greaterThan(0));
      expect(
        spans.any(
          (s) =>
              s.text == 'miring' &&
              s.style?.fontWeight == FontWeight.w700 &&
              s.style?.fontStyle == FontStyle.italic &&
              s.style?.fontFamily == 'ResolvedInter',
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) =>
              s.text == 'penting' &&
              s.style?.fontWeight == FontWeight.w700 &&
              s.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (s) => s.text == ' banget' && s.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
    });
  });

  group('MarkdownChatText widget', () {
    testWidgets(
      'renders CurhAI bullet reply with bold lead-ins and zero raw asterisks',
      (tester) async {
        const sampleReply =
            'Aku ikut sedih dengar kamu lagi ngalamin ini. 😔 Kamu nggak salah '
            'dan nggak pantas diperlakukan seperti itu — perasaanmu valid banget.\n\n'
            'Beberapa langkah aman yang bisa kamu coba:\n\n'
            '- **Cari teman, jangan sendirian.** Berada di dekat teman yang kamu percaya bisa bikin kamu lebih aman dan kurang jadi target.\n'
            '- **Simpan bukti.** Kalau bullying terjadi lewat chat atau medsos, screenshot dulu. Ini penting kalau nanti perlu dilaporkan.\n'
            '- **Cerita ke orang dewasa tepercaya.** Guru BK, wali kelas, atau orang tua bisa bantu kamu. Kamu nggak harus hadapi ini sendirian.\n\n'
            'Kalau kamu mau, cerita aja ke aku dulu — siapa yang nge-bully, di mana biasanya kejadian? Aku di sini buat dengerin. 💛';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 340,
                  child: MarkdownChatText(
                    data: sampleReply,
                    style: baseStyle,
                  ),
                ),
              ),
            ),
          ),
        );

        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final allSpans =
            richTexts.expand((rt) => _flattenSpans(rt.text)).toList();
        final fullRenderedText = allSpans.map((s) => s.text).join();

        expect(fullRenderedText, isNot(contains('**')));
        expect(find.text('•'), findsNWidgets(3));

        for (final expectedBold in [
          'Cari teman, jangan sendirian.',
          'Simpan bukti.',
          'Cerita ke orang dewasa tepercaya.',
        ]) {
          expect(
            allSpans.any(
              (s) =>
                  s.text == expectedBold &&
                  s.style?.fontWeight == FontWeight.w700,
            ),
            isTrue,
            reason: 'Expected "$expectedBold" to render with FontWeight.w700',
          );
        }
      },
    );

    testWidgets(
      'renders headings, ordered lists, sub-bullets, and blockquotes cleanly',
      (tester) async {
        const sample = '### **Langkah Cepat**\n'
            '1. **Tarik napas** pelan-pelan\n'
            '  - Hitung 4 detik\n'
            '> Kamu berhak merasa aman.';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                child: MarkdownChatText(
                  data: sample,
                  style: baseStyle,
                ),
              ),
            ),
          ),
        );

        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final allSpans =
            richTexts.expand((rt) => _flattenSpans(rt.text)).toList();
        final fullRenderedText = allSpans.map((s) => s.text).join();

        expect(fullRenderedText, isNot(contains('###')));
        expect(fullRenderedText, isNot(contains('**')));
        expect(fullRenderedText, contains('Langkah Cepat'));
        expect(find.text('1.'), findsOneWidget);
        expect(find.text('◦'), findsOneWidget);
        expect(
          allSpans.any(
            (s) =>
                s.text == 'Tarik napas' &&
                s.style?.fontWeight == FontWeight.w700,
          ),
          isTrue,
        );
        expect(
          allSpans.any(
            (s) =>
                s.text == 'Kamu berhak merasa aman.' &&
                s.style?.fontStyle == FontStyle.italic,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'CurhaiScreen formats assistant Markdown bold bullets without raw asterisks',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              curhaiRepositoryProvider.overrideWithValue(
                _FakeMarkdownCurhaiRepository(),
              ),
            ],
            child: const MaterialApp(home: CurhaiScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Aku lagi dibully di sekolah',
        );
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        final markdownFinder = find.byType(MarkdownChatText);
        expect(markdownFinder, findsOneWidget);

        final richTexts = tester.widgetList<RichText>(
          find.descendant(
            of: markdownFinder,
            matching: find.byType(RichText),
          ),
        );
        final allSpans =
            richTexts.expand((rt) => _flattenSpans(rt.text)).toList();
        final fullText = allSpans.map((s) => s.text).join();

        expect(fullText, isNot(contains('**')));
        expect(
          allSpans.any(
            (s) =>
                s.text == 'Cari teman, jangan sendirian.' &&
                s.style?.fontWeight == FontWeight.w700,
          ),
          isTrue,
        );
        expect(
          allSpans.any(
            (s) =>
                s.text == 'Simpan bukti.' &&
                s.style?.fontWeight == FontWeight.w700,
          ),
          isTrue,
        );
      },
    );
  });
}
