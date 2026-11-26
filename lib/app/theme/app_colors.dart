import 'package:flutter/material.dart';

abstract final class AppColors {
  // KitaTemani Interface Design Tokens
  static const Color canvas = Color(0xFFF7F8FD);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color tintIndigo = Color(0xFFF3F4FE);
  static const Color indigoSoft = Color(0xFFEEF0FD);
  static const Color tintMint = Color(0xFFE2F7EE);
  static const Color mintText = Color(0xFF0F6E4A);
  static const Color tintSky = Color(0xFFE3F3FE);
  static const Color skyText = Color(0xFF0369A1);
  static const Color skyAccent = Color(0xFF38BDF8);
  static const Color tintLilac = Color(0xFFF4EEFF);
  static const Color lilacText = Color(0xFF6D28D9);
  static const Color lilacAccent = Color(0xFF8B5CF6);
  static const Color tintCoral = Color(0xFFFFF1EC);
  static const Color coralText = Color(0xFFC2410C);
  static const Color coralAccent = Color(0xFFF97316);
  static const Color amberTint = Color(0xFFFFF8E1);
  static const Color amber = Color(0xFFFBBF24);
  static const Color amberText = Color(0xFFB45309);
  static const Color indigo400 = Color(0xFF858CF7);

  static const Color inkNavy = Color(0xFF1D224A);
  static const Color inkSlate = Color(0xFF6E7499);
  static const Color borderHairline = Color(0xFFE2E6F3);

  static const Color sosDanger = Color(0xFFEE4E5F);
  static const Color sosSoft = Color(0xFFFDE8EA);
  static const Color crimsonContrast = Color(0xFF9E1D2B);

  // Legacy & Semantic Compatibility Aliases (updated to new KitaTemani palette)
  static const Color kertas = canvas;
  static const Color tinta = inkNavy;
  static const Color tintaPudar = inkSlate;
  static const Color biruTinta = Color(0xFF585FE6);
  static const Color biruTua = Color(0xFF3F46C2);
  static const Color biruMuda = Color(0xFF7B83F8);
  static const Color stabilo = Color(0xFFFFD54F);
  static const Color stabiloMuda = amberTint;
  static const Color hijau = Color(0xFF18A96B);
  static const Color hijauMuda = tintMint;
  static const Color darurat = Color(0xFFEA4556);
  static const Color daruratTua = crimsonContrast;
  static const Color daruratMuda = sosSoft;

  static const Color background = canvas;
  static const Color surface = cardWhite;
  static const Color border = borderHairline;
  static const Color borderStrong = Color(0xFFD0D6EC);

  static const Color textPrimary = inkNavy;
  static const Color textSecondary = inkSlate;
  static const Color textMuted = Color(0xFF8C92B3);

  static const Color primary = biruTinta;
  static const Color primaryDark = biruTua;
  static const Color primaryLight = biruMuda;
  static const Color primarySoft = indigoSoft;
  static const Color primaryExtraSoft = tintIndigo;

  static const Color danger = darurat;
  static const Color dangerDark = crimsonContrast;
  static const Color dangerSoft = sosSoft;

  static const Color success = hijau;
  static const Color successSoft = tintMint;

  static const Color warning = amber;
  static const Color warningSoft = amberTint;

  static const Color accent = biruTinta;
  static const Color accentDark = biruTua;
  static const Color accentLight = indigo400;
  static const Color accentSoft = indigoSoft;

  // Gradients from KitaTemani_Interface
  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [Color(0xFF7B83F8), Color(0xFF585FE6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF767EF6), Color(0xFF6269EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF5A60E8), Color(0xFF8E94FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient panicIdleBgGradient = LinearGradient(
    colors: [Color(0xFFF46170), Color(0xFFF7828E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient panicActiveGradient = LinearGradient(
    colors: [Color(0xFFFA7A87), Color(0xFFEA4556)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient purpleCardGradient = heroCardGradient;

  // Soft Pill, SOS, & Circle Glows (replacing legacy hard shadows)
  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x45585FE6),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  static const List<BoxShadow> sosShadow = [
    BoxShadow(
      color: Color(0x5CEE4E5F),
      offset: Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  static const List<BoxShadow> circleControlShadow = [
    BoxShadow(
      color: Color(0x161D224A),
      offset: Offset(0, 3),
      blurRadius: 10,
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0D1D224A),
      offset: Offset(0, 4),
      blurRadius: 14,
    ),
  ];

  static const List<BoxShadow> primaryButtonShadow = buttonShadow;
  static const List<BoxShadow> hardButtonShadow = buttonShadow;
  static const List<BoxShadow> hardDangerShadow = sosShadow;
  static const List<BoxShadow> subtleShadow = circleControlShadow;
}
