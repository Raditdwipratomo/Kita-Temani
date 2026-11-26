import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/app.dart';
import 'package:kitatemani/app/router/routes.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Full user flow smoke test', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KitaTemaniApp(initialRoute: AppRoutes.home),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pengguna'), findsOneWidget);
    expect(find.text('Buat laporan'), findsOneWidget);
    expect(find.text('Maya'), findsNothing);
  });
}
