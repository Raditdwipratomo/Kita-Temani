import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';

void main() {
  group('OwlMascot', () {
    for (final mood in OwlMood.values) {
      testWidgets(
        'renders ${mood.name} at 28px, 42px, and 96px and settles cleanly',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OwlMascot(mood: mood, size: 28),
                      const SizedBox(height: 8),
                      OwlMascot(mood: mood, size: 42),
                      const SizedBox(height: 8),
                      OwlMascot(mood: mood, size: 96),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(OwlMascot), findsNWidgets(3));
          expect(find.byType(SvgPicture), findsNWidgets(3));
        },
      );
    }

    testWidgets(
      'respects disableAnimations and supports unframed / custom radius modes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Row(
                  children: [
                    OwlMascot(
                      mood: OwlMood.breathing,
                      size: 38,
                      breathingScale: 1.08,
                      borderRadius: BorderRadius.circular(10),
                      backgroundColor: AppColors.tintMint,
                    ),
                    const OwlMascot(
                      mood: OwlMood.reassuring,
                      size: 48,
                      showContainer: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scales = tester
            .widgetList<AnimatedScale>(find.byType(AnimatedScale))
            .toList();
        expect(scales.length, 2);
        for (final s in scales) {
          expect(s.duration, Duration.zero);
          expect(s.scale, 1.0);
        }

        final switchers = tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .toList();
        for (final sw in switchers) {
          expect(sw.duration, Duration.zero);
        }
      },
    );

    testWidgets('OwlGlyphIcon renders cleanly at 22px', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                OwlGlyphIcon(color: AppColors.biruTinta, size: 22),
                OwlGlyphIcon(color: AppColors.inkSlate, size: 22),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OwlGlyphIcon), findsNWidgets(2));
      expect(find.byType(SvgPicture), findsNWidgets(2));
    });
  });
}
