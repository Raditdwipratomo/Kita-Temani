import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';

void main() {
  group('KitaIllustration', () {
    for (final scene in IllustrationScene.values) {
      testWidgets(
        'renders ${scene.name} cleanly and settles without pending frames',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: KitaIllustration(
                    scene: scene,
                    width: 140,
                    height: 100,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(KitaIllustration), findsOneWidget);
          expect(find.byType(SvgPicture), findsOneWidget);
        },
      );
    }
  });
}
