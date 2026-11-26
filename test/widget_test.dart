import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/core/widgets/student_illustrations.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('SplashScreen renders KitaTemani branding and owl mascot',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(),
      ),
    );

    expect(find.text('KitaTemani'), findsOneWidget);
    expect(find.text('Berani lapor, berani peduli'), findsOneWidget);
    expect(find.text('Teman amanmu di sekolah'), findsOneWidget);
    expect(find.byType(OwlMascot), findsOneWidget);
    expect(find.byType(SplashStudentsIllustration), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.byType(OwlMascot), findsOneWidget);
    expect(find.byType(CharacterAvatar), findsNothing);
  });
}
