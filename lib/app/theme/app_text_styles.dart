import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/app/theme/app_colors.dart';

abstract final class AppTextStyles {
  static const int _maxCacheEntries = 256;
  static final Map<Object, TextStyle> _poppinsCache = {};
  static final Map<Object, TextStyle> _interCache = {};
  static final Map<Object, TextStyle> _codeCache = {};
  static final Map<Object, TextStyle> _editorialCache = {};

  static TextStyle _memoize(
    Map<Object, TextStyle> cache,
    Object key,
    TextStyle Function() buildStyle,
  ) {
    final hit = cache[key];
    if (hit != null) return hit;
    if (cache.length >= _maxCacheEntries) {
      cache.clear();
    }
    final created = buildStyle();
    cache[key] = created;
    return created;
  }

  static TextStyle poppins({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.inkNavy,
    double? height,
    double? letterSpacing,
  }) {
    return _memoize(
      _poppinsCache,
      (fontSize, fontWeight, color, height, letterSpacing),
      () => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }

  static TextStyle inter({
    double fontSize = 13.5,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color color = AppColors.inkSlate,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    return _memoize(
      _interCache,
      (
        fontSize,
        fontWeight,
        fontStyle,
        color,
        height,
        letterSpacing,
        decoration,
        decorationColor,
      ),
      () => GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
        decorationColor: decorationColor,
      ),
    );
  }

  static TextStyle code({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.inkNavy,
    double? letterSpacing = 0.8,
  }) {
    return _memoize(
      _codeCache,
      (fontSize, fontWeight, color, letterSpacing),
      () => GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      ),
    );
  }

  // Backward-compatible method aliases mapped to Poppins/Inter/JetBrainsMono
  static TextStyle heading({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.inkNavy,
    double? height,
    double? letterSpacing,
  }) =>
      poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle plusJakarta({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.inkNavy,
    double? height,
    double? letterSpacing,
  }) =>
      poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle jetbrainsMono({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.inkNavy,
    double? letterSpacing = 0.8,
  }) =>
      code(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // KitaTemani Type Scale (Display 28, H1 22, H2 17, Card/CTA 15, Body 13.5, Caption 12)
  static TextStyle get displayLarge => poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.inkNavy,
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get heading1 => poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.inkNavy,
        height: 1.26,
        letterSpacing: -0.35,
      );

  static TextStyle get heading2 => poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.inkNavy,
        height: 1.32,
        letterSpacing: -0.2,
      );

  static TextStyle get heading3 => poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.inkNavy,
        height: 1.35,
        letterSpacing: -0.1,
      );

  static TextStyle get bodyLarge => inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.inkNavy,
        height: 1.5,
      );

  static TextStyle get bodyMedium => inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: AppColors.inkSlate,
        height: 1.48,
      );

  static TextStyle get bodySmall => inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.inkSlate,
        height: 1.4,
      );

  static TextStyle get button => poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        letterSpacing: 0.1,
      );

  static TextStyle editorialBody({
    double fontSize = 16.5,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    Color color = AppColors.inkNavy,
    double height = 1.75,
  }) {
    return _memoize(
      _editorialCache,
      (fontSize, fontWeight, fontStyle, color, height),
      () => GoogleFonts.lora(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        color: color,
        height: height,
      ),
    );
  }
}
