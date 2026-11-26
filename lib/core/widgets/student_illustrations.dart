import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';

enum CharacterKind {
  maya,
  mayaPinkTie,
  hijabFriend,
  boyStudent,
  buRinaCounselor,
  pakDimas,
  pakGavin,
  curhaiBot,
  kakSalsa,
}

class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    required this.kind,
    super.key,
    this.size = 56,
    this.backgroundColor,
    this.showCollarDots = false,
  });

  final CharacterKind kind;
  final double size;
  final Color? backgroundColor;
  final bool showCollarDots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFE3E7FF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CharacterPainter(
          kind: kind,
          showCollarDots: showCollarDots,
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter({
    required this.kind,
    this.showCollarDots = false,
  });

  final CharacterKind kind;
  final bool showCollarDots;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (kind == CharacterKind.curhaiBot) {
      _paintBot(canvas, w, h);
      return;
    }

    // 1. Back hair / Hijab
    switch (kind) {
      case CharacterKind.maya:
      case CharacterKind.mayaPinkTie:
        final hairPaint = Paint()..color = const Color(0xFF1F244D);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(w * 0.16, h * 0.14, w * 0.68, h * 0.78),
            topLeft: Radius.circular(w * 0.34),
            topRight: Radius.circular(w * 0.34),
          ),
          hairPaint,
        );
      case CharacterKind.kakSalsa:
        final hairPaint = Paint()..color = const Color(0xFF6B3F2B);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.68, h * 0.72),
            topLeft: Radius.circular(w * 0.34),
            topRight: Radius.circular(w * 0.34),
          ),
          hairPaint,
        );
      case CharacterKind.hijabFriend:
        final hijabOuter = Paint()..color = const Color(0xFF8389F7);
        final path = Path()
          ..moveTo(w * 0.10, h)
          ..quadraticBezierTo(w * 0.15, h * 0.10, w * 0.50, h * 0.10)
          ..quadraticBezierTo(w * 0.85, h * 0.10, w * 0.90, h)
          ..close();
        canvas.drawPath(path, hijabOuter);
      case CharacterKind.buRinaCounselor:
        final bunPaint = Paint()..color = const Color(0xFF3B241A);
        // High bun
        canvas.drawCircle(Offset(w * 0.50, h * 0.15), w * 0.125, bunPaint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.42), w * 0.25, bunPaint);
      case CharacterKind.boyStudent:
      case CharacterKind.pakDimas:
      case CharacterKind.pakGavin:
        final hairPaint = Paint()
          ..color = kind == CharacterKind.boyStudent
              ? const Color(0xFF3E281C)
              : const Color(0xFF212654);
        canvas.drawCircle(Offset(w * 0.50, h * 0.40), w * 0.255, hairPaint);
      case CharacterKind.curhaiBot:
        break;
    }

    // 2. Shoulders / Uniform Shirt
    if (kind != CharacterKind.hijabFriend) {
      final shirtPaint = Paint()
        ..color = kind == CharacterKind.kakSalsa
            ? const Color(0xFFF699B4)
            : Colors.white;
      final shoulderPath = Path()
        ..moveTo(w * 0.11, h)
        ..quadraticBezierTo(w * 0.15, h * 0.73, w * 0.38, h * 0.73)
        ..lineTo(w * 0.62, h * 0.73)
        ..quadraticBezierTo(w * 0.85, h * 0.73, w * 0.89, h)
        ..close();
      canvas.drawPath(shoulderPath, shirtPaint);

      // Subtle collar lapel lines
      final lapelPaint = Paint()
        ..color = const Color(0xFFD6DAF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016;
      canvas.drawLine(
        Offset(w * 0.36, h * 0.73),
        Offset(w * 0.45, h * 0.86),
        lapelPaint,
      );
      canvas.drawLine(
        Offset(w * 0.64, h * 0.73),
        Offset(w * 0.55, h * 0.86),
        lapelPaint,
      );

      // Tie
      if (kind != CharacterKind.kakSalsa) {
        final tieColor = kind == CharacterKind.mayaPinkTie
            ? const Color(0xFFEC7A9A)
            : (kind == CharacterKind.maya
                ? const Color(0xFF565CE6)
                : const Color(0xFF3564D8));
        final tiePath = Path()
          ..moveTo(w * 0.46, h * 0.76)
          ..lineTo(w * 0.54, h * 0.76)
          ..lineTo(w * 0.56, h)
          ..lineTo(w * 0.44, h)
          ..close();
        canvas.drawPath(tiePath, Paint()..color = tieColor);
      }
    } else {
      // Hijab drape fold lines
      final foldPaint = Paint()
        ..color = const Color(0xFF7077EA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015;
      canvas.drawLine(
        Offset(w * 0.32, h * 0.76),
        Offset(w * 0.25, h * 0.96),
        foldPaint,
      );
      canvas.drawLine(
        Offset(w * 0.68, h * 0.76),
        Offset(w * 0.75, h * 0.96),
        foldPaint,
      );
    }

    // 3. Neck & Neck Shadow
    final skinColor = kind == CharacterKind.boyStudent
        ? const Color(0xFFE3AF84)
        : const Color(0xFFF7C49E);
    final skinShadowColor = kind == CharacterKind.boyStudent
        ? const Color(0xFFD19B70)
        : const Color(0xFFE8B089);

    if (kind != CharacterKind.hijabFriend) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.43, h * 0.61, w * 0.14, h * 0.16),
          Radius.circular(w * 0.05),
        ),
        Paint()..color = skinColor,
      );
      canvas.drawArc(
        Rect.fromLTWH(w * 0.43, h * 0.60, w * 0.14, h * 0.09),
        0,
        math.pi,
        true,
        Paint()..color = skinShadowColor,
      );
    }

    // Collar dots on boy student in Splash Screen
    if (showCollarDots) {
      canvas.drawCircle(
        Offset(w * 0.41, h * 0.75),
        w * 0.022,
        Paint()..color = AppColors.primary,
      );
      canvas.drawCircle(
        Offset(w * 0.50, h * 0.75),
        w * 0.022,
        Paint()..color = const Color(0xFFB3C5F7),
      );
      canvas.drawCircle(
        Offset(w * 0.59, h * 0.75),
        w * 0.022,
        Paint()..color = const Color(0xFFB3C5F7),
      );
    }

    // 4. Ears (for boy / counselor / Pak Gavin)
    if (kind == CharacterKind.boyStudent ||
        kind == CharacterKind.pakDimas ||
        kind == CharacterKind.pakGavin ||
        kind == CharacterKind.buRinaCounselor) {
      canvas.drawCircle(
        Offset(w * 0.27, h * 0.49),
        w * 0.045,
        Paint()..color = skinColor,
      );
      canvas.drawCircle(
        Offset(w * 0.73, h * 0.49),
        w * 0.045,
        Paint()..color = skinColor,
      );
    }

    // 5. Face oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.47),
        width: w * 0.45,
        height: h * 0.46,
      ),
      Paint()..color = skinColor,
    );

    // 6. Front Hair Bangs / Fringe
    switch (kind) {
      case CharacterKind.maya:
      case CharacterKind.mayaPinkTie:
        final bangPaint = Paint()..color = const Color(0xFF1F244D);
        final bangPath = Path()
          ..moveTo(w * 0.26, h * 0.42)
          ..quadraticBezierTo(w * 0.38, h * 0.25, w * 0.54, h * 0.30)
          ..quadraticBezierTo(w * 0.68, h * 0.33, w * 0.74, h * 0.43)
          ..quadraticBezierTo(w * 0.72, h * 0.22, w * 0.50, h * 0.21)
          ..quadraticBezierTo(w * 0.28, h * 0.22, w * 0.26, h * 0.42)
          ..close();
        canvas.drawPath(bangPath, bangPaint);
      case CharacterKind.kakSalsa:
        final bangPaint = Paint()..color = const Color(0xFF6B3F2B);
        final bangPath = Path()
          ..moveTo(w * 0.26, h * 0.40)
          ..quadraticBezierTo(w * 0.50, h * 0.28, w * 0.74, h * 0.40)
          ..quadraticBezierTo(w * 0.72, h * 0.22, w * 0.50, h * 0.22)
          ..quadraticBezierTo(w * 0.28, h * 0.22, w * 0.26, h * 0.40)
          ..close();
        canvas.drawPath(bangPath, bangPaint);
      case CharacterKind.boyStudent:
      case CharacterKind.pakDimas:
      case CharacterKind.pakGavin:
      case CharacterKind.buRinaCounselor:
        final topHairColor = kind == CharacterKind.boyStudent
            ? const Color(0xFF3E281C)
            : (kind == CharacterKind.buRinaCounselor
                ? const Color(0xFF3B241A)
                : const Color(0xFF212654));
        final topPath = Path()
          ..moveTo(w * 0.27, h * 0.39)
          ..quadraticBezierTo(w * 0.42, h * 0.29, w * 0.58, h * 0.32)
          ..quadraticBezierTo(w * 0.68, h * 0.34, w * 0.73, h * 0.39)
          ..quadraticBezierTo(w * 0.70, h * 0.21, w * 0.50, h * 0.21)
          ..quadraticBezierTo(w * 0.30, h * 0.21, w * 0.27, h * 0.39)
          ..close();
        canvas.drawPath(topPath, Paint()..color = topHairColor);
      case CharacterKind.hijabFriend:
      case CharacterKind.curhaiBot:
        break;
    }

    // 7. Eyes with cute white catchlights
    final eyePaint = Paint()..color = const Color(0xFF1A1F4A);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.415, h * 0.475),
        width: w * 0.048,
        height: h * 0.064,
      ),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.585, h * 0.475),
        width: w * 0.048,
        height: h * 0.064,
      ),
      eyePaint,
    );
    // White catchlight dots
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(w * 0.408, h * 0.463),
      w * 0.011,
      highlightPaint,
    );
    canvas.drawCircle(
      Offset(w * 0.578, h * 0.463),
      w * 0.011,
      highlightPaint,
    );

    // 8. Soft rosy cheeks
    final blushPaint = Paint()
      ..color = const Color(0xFFF28B8B).withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.355, h * 0.525),
        width: w * 0.075,
        height: h * 0.042,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.645, h * 0.525),
        width: w * 0.075,
        height: h * 0.042,
      ),
      blushPaint,
    );

    // 9. Warm curved smile
    final smilePaint = Paint()
      ..color = const Color(0xFFC24D4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.030
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(w * 0.435, h * 0.535)
      ..quadraticBezierTo(w * 0.50, h * 0.60, w * 0.565, h * 0.535);
    canvas.drawPath(smilePath, smilePaint);
  }

  void _paintBot(Canvas canvas, double w, double h) {
    // Antenna stem & glowing yellow bulb
    canvas.drawLine(
      Offset(w * 0.50, h * 0.14),
      Offset(w * 0.50, h * 0.27),
      Paint()
        ..color = const Color(0xFF7B82F5)
        ..strokeWidth = w * 0.042
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.13),
      w * 0.052,
      Paint()..color = const Color(0xFFF6BE4F),
    );

    // Robot neck & body base
    canvas.drawRect(
      Rect.fromLTWH(w * 0.42, h * 0.74, w * 0.16, h * 0.10),
      Paint()..color = const Color(0xFFB3B8F9),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.28, h * 0.82, w * 0.44, h * 0.18),
        topLeft: Radius.circular(w * 0.14),
        topRight: Radius.circular(w * 0.14),
      ),
      Paint()..color = const Color(0xFFD9DDFC),
    );

    // Side headphone ears
    final earPaint = Paint()..color = const Color(0xFF6B72F2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.40, w * 0.09, h * 0.22),
        Radius.circular(w * 0.045),
      ),
      earPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.81, h * 0.40, w * 0.09, h * 0.22),
        Radius.circular(w * 0.045),
      ),
      earPaint,
    );

    // Outer white rounded helmet shell
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.25, w * 0.68, h * 0.51),
      Radius.circular(w * 0.24),
    );
    canvas.drawRRect(headRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      headRect,
      Paint()
        ..color = const Color(0xFFA5ABFA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.032,
    );

    // Inner dark navy visor screen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.34, w * 0.50, h * 0.33),
        Radius.circular(w * 0.15),
      ),
      Paint()..color = const Color(0xFF23285E),
    );

    // Cute glowing eyes & smile inside visor
    canvas.drawCircle(
      Offset(w * 0.39, h * 0.47),
      w * 0.048,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * 0.61, h * 0.47),
      w * 0.048,
      Paint()..color = Colors.white,
    );
    // Tiny dark pupils
    canvas.drawCircle(
      Offset(w * 0.39, h * 0.47),
      w * 0.018,
      Paint()..color = const Color(0xFF23285E),
    );
    canvas.drawCircle(
      Offset(w * 0.61, h * 0.47),
      w * 0.018,
      Paint()..color = const Color(0xFF23285E),
    );

    final smile = Path()
      ..moveTo(w * 0.43, h * 0.55)
      ..quadraticBezierTo(w * 0.50, h * 0.61, w * 0.57, h * 0.55);
    canvas.drawPath(
      smile,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.030
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.showCollarDots != showCollarDots;
}

/// Fluffy vector cloud matching interface/*.png
class FluffyCloud extends StatelessWidget {
  const FluffyCloud({
    super.key,
    this.width = 76,
    this.color = Colors.white,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.62),
      painter: _CloudPainter(color),
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.42, w * 0.84, h * 0.48),
        Radius.circular(h * 0.24),
      ),
      paint,
    );
    canvas.drawCircle(Offset(w * 0.28, h * 0.52), w * 0.20, paint);
    canvas.drawCircle(Offset(w * 0.52, h * 0.38), w * 0.25, paint);
    canvas.drawCircle(Offset(w * 0.74, h * 0.54), w * 0.18, paint);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 3-leaf botanical cluster matching interface/*.png
class BotanicalLeaves extends StatelessWidget {
  const BotanicalLeaves({
    super.key,
    this.isMint = false,
    this.flipHorizontal = false,
    this.size = 76,
  });

  final bool isMint;
  final bool flipHorizontal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flipHorizontal,
      child: CustomPaint(
        size: Size(size, size * 0.85),
        painter: _LeavesPainter(isMint: isMint),
      ),
    );
  }
}

class _LeavesPainter extends CustomPainter {
  const _LeavesPainter({required this.isMint});
  final bool isMint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final light = isMint ? const Color(0xFFA3EAD4) : const Color(0xFFB5BCFC);
    final mid = isMint ? const Color(0xFF7FD8BE) : const Color(0xFF9198F8);
    final dark = isMint ? const Color(0xFF66C9AB) : const Color(0xFF7880F4);

    // Center tall leaf
    final centerLeaf = Path()
      ..moveTo(w * 0.50, h * 0.95)
      ..quadraticBezierTo(w * 0.32, h * 0.48, w * 0.48, h * 0.05)
      ..quadraticBezierTo(w * 0.66, h * 0.48, w * 0.50, h * 0.95)
      ..close();
    canvas.drawPath(centerLeaf, Paint()..color = light);

    // Left angled leaf
    final leftLeaf = Path()
      ..moveTo(w * 0.48, h * 0.95)
      ..quadraticBezierTo(w * 0.12, h * 0.75, w * 0.06, h * 0.35)
      ..quadraticBezierTo(w * 0.38, h * 0.45, w * 0.48, h * 0.95)
      ..close();
    canvas.drawPath(leftLeaf, Paint()..color = mid);

    // Right angled leaf
    final rightLeaf = Path()
      ..moveTo(w * 0.52, h * 0.95)
      ..quadraticBezierTo(w * 0.62, h * 0.45, w * 0.94, h * 0.38)
      ..quadraticBezierTo(w * 0.86, h * 0.78, w * 0.52, h * 0.95)
      ..close();
    canvas.drawPath(rightLeaf, Paint()..color = dark);
  }

  @override
  bool shouldRepaint(covariant _LeavesPainter oldDelegate) =>
      oldDelegate.isMint != isMint;
}

/// Custom Siren icon matching the exact dome + 3 rays + base bar in interface/*.png
class SirenIcon extends StatelessWidget {
  const SirenIcon({
    super.key,
    this.size = 32,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SirenPainter(color),
    );
  }
}

class _SirenPainter extends CustomPainter {
  const _SirenPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Top 3 rays
    canvas.drawLine(
      Offset(w * 0.50, h * 0.08),
      Offset(w * 0.50, h * 0.20),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.20, h * 0.20),
      Offset(w * 0.29, h * 0.29),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.80, h * 0.20),
      Offset(w * 0.71, h * 0.29),
      stroke,
    );

    // Siren dome arch
    final domePath = Path()
      ..moveTo(w * 0.27, h * 0.72)
      ..lineTo(w * 0.27, h * 0.52)
      ..arcToPoint(
        Offset(w * 0.73, h * 0.52),
        radius: Radius.circular(w * 0.23),
      )
      ..lineTo(w * 0.73, h * 0.72)
      ..close();
    canvas.drawPath(domePath, stroke);

    // Base pedestal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.73, w * 0.60, h * 0.14),
        Radius.circular(w * 0.05),
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SirenPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// True rounded dashed border container matching 02, 09, 11, 13 mockups.
class DashedBorderContainer extends StatelessWidget {
  const DashedBorderContainer({
    required this.child,
    super.key,
    this.borderColor = const Color(0xFFB3B8F8),
    this.backgroundColor = Colors.white,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(14),
    this.strokeWidth = 1.4,
  });

  final Widget child;
  final Color borderColor;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: borderColor,
        radius: borderRadius,
        strokeWidth: strokeWidth,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    const dashWidth = 6.0;
    const dashSpace = 4.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class KitaTemaniLogoMark extends StatelessWidget {
  const KitaTemaniLogoMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 2,
        ),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _LogoSpeechBubblesPainter(),
      ),
    );
  }
}

class _LogoSpeechBubblesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back white speech bubble
    final whiteBubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.29, w * 0.37, h * 0.27),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(whiteBubble, Paint()..color = Colors.white);

    final whiteTail = Path()
      ..moveTo(w * 0.32, h * 0.55)
      ..lineTo(w * 0.29, h * 0.65)
      ..lineTo(w * 0.41, h * 0.55)
      ..close();
    canvas.drawPath(whiteTail, Paint()..color = Colors.white);

    // Front amber speech bubble with crisp dark-indigo ring separator
    final amberRect = Rect.fromLTWH(w * 0.43, h * 0.39, w * 0.34, h * 0.25);
    final amberRRect = RRect.fromRectAndRadius(
      amberRect,
      Radius.circular(w * 0.08),
    );
    final ringPaint = Paint()
      ..color = const Color(0xFF3E45B4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032;
    canvas.drawRRect(amberRRect, ringPaint);
    canvas.drawRRect(amberRRect, Paint()..color = const Color(0xFFFFD54F));

    final amberTail = Path()
      ..moveTo(w * 0.62, h * 0.63)
      ..lineTo(w * 0.67, h * 0.72)
      ..lineTo(w * 0.55, h * 0.63)
      ..close();
    canvas.drawPath(amberTail, Paint()..color = const Color(0xFFFFD54F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Splash school hill & three smiling students scene matching KitaTemani_Interface Screen 01.
class SplashStudentsIllustration extends StatelessWidget {
  const SplashStudentsIllustration({super.key, this.height = 225});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SplashBackdropPainter()),
          ),
          // 3 student characters aligned above the curved ground
          const Positioned(
            bottom: -14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CharacterAvatar(
                  kind: CharacterKind.maya,
                  size: 112,
                  backgroundColor: Colors.transparent,
                ),
                SizedBox(width: 2),
                CharacterAvatar(
                  kind: CharacterKind.boyStudent,
                  size: 120,
                  backgroundColor: Colors.transparent,
                ),
                SizedBox(width: 2),
                CharacterAvatar(
                  kind: CharacterKind.hijabFriend,
                  size: 114,
                  backgroundColor: Colors.transparent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Translucent outer sun aura + warm yellow sun behind center students
    canvas.drawCircle(
      Offset(w * 0.60, h * 0.56),
      w * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      Offset(w * 0.59, h * 0.58),
      w * 0.22,
      Paint()..color = const Color(0xFFFCD335),
    );

    // Stylized school silhouette on the left
    final schoolPaint = Paint()..color = const Color(0xFF424AB8);
    final schoolPath = Path()
      ..moveTo(w * 0.06, h * 0.78)
      ..lineTo(w * 0.06, h * 0.36)
      ..lineTo(w * 0.21, h * 0.24)
      ..lineTo(w * 0.36, h * 0.36)
      ..lineTo(w * 0.36, h * 0.78)
      ..close();
    canvas.drawPath(schoolPath, schoolPaint);

    // Flagpole & coral flag
    canvas.drawLine(
      Offset(w * 0.21, h * 0.24),
      Offset(w * 0.21, h * 0.08),
      Paint()
        ..color = const Color(0xFF383FA4)
        ..strokeWidth = 2.5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.21, h * 0.08, 22, 13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFF66E7C),
    );

    // Curved light hill floor
    final hillPath = Path()
      ..moveTo(0, h * 0.66)
      ..quadraticBezierTo(w * 0.5, h * 0.48, w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillPath, Paint()..color = const Color(0xFFF1F3FD));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shield Check Illustration matching 03_Laporan_Terkirim.png
class ShieldCheckIllustration extends StatelessWidget {
  const ShieldCheckIllustration({super.key, this.size = 210});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.45,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 12,
            left: 16,
            child: FluffyCloud(width: 68),
          ),
          const Positioned(
            top: 28,
            right: 14,
            child: FluffyCloud(width: 56),
          ),
          const Positioned(
            bottom: 4,
            left: 8,
            child: BotanicalLeaves(size: 82),
          ),
          const Positioned(
            bottom: 4,
            right: 8,
            child: BotanicalLeaves(isMint: true, size: 82),
          ),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE5E8FE),
            ),
          ),
          Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD9DDFC),
            ),
          ),
          // Decorative dots & hearts matching 03_Laporan_Terkirim.png
          Positioned(
            top: size * 0.11,
            left: size * 0.42,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Color(0xFFF6BD4F),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: size * 0.08,
            right: size * 0.36,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF66C9AB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: size * 0.34,
            left: size * 0.23,
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFEF6C86),
              size: 18,
            ),
          ),
          Positioned(
            top: size * 0.50,
            right: size * 0.21,
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primaryLight,
              size: 18,
            ),
          ),
          CustomPaint(
            size: Size(size * 0.46, size * 0.54),
            painter: _ShieldPainter(),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    Path buildShield(double inset) {
      final l = inset;
      final r = w - inset;
      final t = inset;
      final b = h - inset;
      return Path()
        ..moveTo(w * 0.5, t)
        ..lineTo(r, t + h * 0.12)
        ..quadraticBezierTo(r, h * 0.65, w * 0.5, b)
        ..quadraticBezierTo(l, h * 0.65, l, t + h * 0.12)
        ..close();
    }

    canvas.drawPath(
      buildShield(0),
      Paint()..color = const Color(0xFF535AE8),
    );
    canvas.drawPath(
      buildShield(w * 0.10),
      Paint()..color = const Color(0xFF6870F5),
    );

    final checkPath = Path()
      ..moveTo(w * 0.32, h * 0.49)
      ..lineTo(w * 0.45, h * 0.61)
      ..lineTo(w * 0.69, h * 0.37);
    canvas.drawPath(
      checkPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.095
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Padlock Illustration matching 08_Arsip_Rahasia_PIN.png
class PadlockHeroIllustration extends StatelessWidget {
  const PadlockHeroIllustration({super.key, this.size = 195});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 16,
            left: 8,
            child: FluffyCloud(width: 68),
          ),
          const Positioned(
            top: 4,
            right: 12,
            child: FluffyCloud(width: 54),
          ),
          const Positioned(
            bottom: 6,
            left: 4,
            child: BotanicalLeaves(size: 80),
          ),
          const Positioned(
            bottom: 6,
            right: 4,
            child: BotanicalLeaves(isMint: true, size: 80),
          ),
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE0E4FD),
            ),
          ),
          Positioned(
            top: size * 0.32,
            left: size * 0.25,
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFEF6C86),
              size: 18,
            ),
          ),
          Positioned(
            top: size * 0.42,
            right: size * 0.23,
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.primaryLight,
              size: 18,
            ),
          ),
          CustomPaint(
            size: Size(size * 0.46, size * 0.56),
            painter: _PadlockPainter(),
          ),
        ],
      ),
    );
  }
}

class _PadlockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shackle arch
    final shacklePath = Path()
      ..moveTo(w * 0.24, h * 0.46)
      ..lineTo(w * 0.24, h * 0.26)
      ..arcToPoint(
        Offset(w * 0.76, h * 0.26),
        radius: Radius.circular(w * 0.26),
      )
      ..lineTo(w * 0.76, h * 0.46);
    canvas.drawPath(
      shacklePath,
      Paint()
        ..color = const Color(0xFF8389F7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..strokeCap = StrokeCap.round,
    );

    // Lock body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.40, w * 0.88, h * 0.56),
        Radius.circular(w * 0.20),
      ),
      Paint()..color = const Color(0xFF565CE8),
    );

    // White keyhole
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.62),
      w * 0.09,
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.455, h * 0.64, w * 0.09, h * 0.16),
        Radius.circular(w * 0.045),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Folder Lock Icon matching 09_Arsip_Rahasia_Daftar.png
class FolderLockIllustration extends StatelessWidget {
  const FolderLockIllustration({super.key, this.width = 66});
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.82),
      painter: _FolderLockPainter(),
    );
  }
}

class _FolderLockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back tab
    final backPath = Path()
      ..moveTo(0, h * 0.22)
      ..quadraticBezierTo(0, h * 0.08, w * 0.14, h * 0.08)
      ..lineTo(w * 0.40, h * 0.08)
      ..lineTo(w * 0.50, h * 0.22)
      ..lineTo(w * 0.88, h * 0.22)
      ..quadraticBezierTo(w, h * 0.22, w, h * 0.36)
      ..lineTo(w, h * 0.86)
      ..quadraticBezierTo(w, h, w * 0.86, h)
      ..lineTo(w * 0.14, h)
      ..quadraticBezierTo(0, h, 0, h * 0.86)
      ..close();
    canvas.drawPath(backPath, Paint()..color = const Color(0xFF8187F6));

    // Front folder plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.28, w, h * 0.72),
        Radius.circular(w * 0.14),
      ),
      Paint()..color = const Color(0xFFA2A8FA),
    );

    // Center lock circle & keyhole
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.62),
      w * 0.14,
      Paint()..color = const Color(0xFF666DF0),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.60),
      w * 0.06,
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.46, h * 0.62, w * 0.08, h * 0.15),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
