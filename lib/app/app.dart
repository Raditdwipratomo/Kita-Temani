import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kitatemani/app/router/app_router.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_theme.dart';
import 'package:kitatemani/l10n/l10n.dart';

class KitaTemaniApp extends StatelessWidget {
  const KitaTemaniApp({
    super.key,
    this.initialRoute = AppRoutes.splash,
  });

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: L10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (initialRouteName) => [
        AppRouter.onGenerateRoute(RouteSettings(name: initialRouteName)),
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
