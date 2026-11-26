import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kitatemani/app/theme/app_colors.dart';

/// Data-driven emotional expressions for the KitaTemani / CurhAI owl mascot.
enum OwlMood {
  /// Default calm, approachable stance for CurhAI welcome & Beranda entry.
  warm('assets/mascot/owl_warm.svg', 'Maskot burung hantu CurhAI'),

  /// Slightly tilted attentive stance used beside CurhAI replies.
  listening(
    'assets/mascot/owl_listening.svg',
    'Maskot burung hantu sedang mendengarkan',
  ),

  /// Soft upward-right thoughtful glance shown while composing a reply.
  thinking(
    'assets/mascot/owl_thinking.svg',
    'Maskot burung hantu sedang berpikir',
  ),

  /// Peaceful closed-eye breathing stance for the grounding exercise.
  breathing(
    'assets/mascot/owl_breathing.svg',
    'Maskot burung hantu menemani latihan napas',
  ),

  /// Steady grounded stance with protective mint check badge.
  reassuring(
    'assets/mascot/owl_reassuring.svg',
    'Maskot burung hantu siap menjaga ruang amanmu',
  );

  const OwlMood(this.assetPath, this.defaultLabel);

  final String assetPath;
  final String defaultLabel;
}

/// Editorial minimal-geometric owl mascot for CurhAI & KitaTemani.
///
/// Uses finite transitions driven explicitly by caller state and honors
/// [MediaQuery.disableAnimationsOf] so reduced-motion preferences and
/// `pumpAndSettle` widget tests remain fast and predictable.
class OwlMascot extends StatelessWidget {
  const OwlMascot({
    required this.mood,
    super.key,
    this.size = 48,
    this.showContainer = true,
    this.backgroundColor,
    this.borderRadius,
    this.borderColor,
    this.breathingScale = 1.0,
    this.semanticsLabel,
  });

  final OwlMood mood;
  final double size;
  final bool showContainer;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double breathingScale;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    final Duration switchDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 220);
    final Duration scaleDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 650);
    final double effectiveScale =
        disableAnimations ? 1.0 : breathingScale.clamp(0.85, 1.2);
    final double glyphSize = showContainer ? size * 0.86 : size;

    final Widget picture = AnimatedScale(
      scale: effectiveScale,
      duration: scaleDuration,
      curve: Curves.easeInOutSine,
      child: AnimatedSwitcher(
        duration: switchDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: SvgPicture.asset(
          mood.assetPath,
          key: ValueKey<OwlMood>(mood),
          width: glyphSize,
          height: glyphSize,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );

    final Widget framed = showContainer
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.indigoSoft,
              borderRadius: borderRadius ?? BorderRadius.circular(size),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.1)
                  : null,
            ),
            alignment: Alignment.center,
            child: picture,
          )
        : SizedBox(
            width: size,
            height: size,
            child: Center(child: picture),
          );

    return Semantics(
      image: true,
      label: semanticsLabel ?? mood.defaultLabel,
      child: RepaintBoundary(child: framed),
    );
  }
}

/// Monochrome outline owl glyph tinted cleanly for navigation items.
class OwlGlyphIcon extends StatelessWidget {
  const OwlGlyphIcon({
    required this.color,
    super.key,
    this.size = 22,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/mascot/owl_glyph.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
