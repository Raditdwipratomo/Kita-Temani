import 'package:flutter/material.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';

/// Circular 40x40 control button matching the Figma hairline-border circle style.
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.size = 40,
    this.iconSize = 20,
    this.iconColor = AppColors.inkNavy,
    this.backgroundColor = AppColors.cardWhite,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderHairline, width: 1.1),
            boxShadow: AppColors.circleControlShadow,
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

/// Standard page header with circular back control, Poppins title, optional subtitle and trailing action.
class KtPageHeader extends StatelessWidget {
  const KtPageHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showBack = true,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showBack) ...[
            CircleActionButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Kembali',
              onTap: onBack ??
                  () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      nav.pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (route) => false,
                      );
                    }
                  },
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkNavy,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: AppTextStyles.inter(
                      fontSize: 12,
                      color: AppColors.inkSlate,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Clean card container with 1px hairline border (#E2E6F3) and soft surface fill.
class KtCard extends StatelessWidget {
  const KtCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.cardWhite,
    this.borderColor = AppColors.borderHairline,
    this.borderWidth = 1.1,
    this.borderRadius = 18,
    this.gradient,
    this.boxShadow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final box = Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: boxShadow,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: box,
      ),
    );
  }
}

/// Compact pill status tag used across Beranda, Laporanku, Detail, Profil, and Kontak.
class KtStatusPill extends StatelessWidget {
  const KtStatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    super.key,
    this.icon,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final Color? borderColor;

  factory KtStatusPill.indigo(String label, {IconData? icon}) => KtStatusPill(
        label: label,
        backgroundColor: AppColors.indigoSoft,
        foregroundColor: AppColors.biruTinta,
        icon: icon,
      );

  factory KtStatusPill.mint(String label, {IconData? icon}) => KtStatusPill(
        label: label,
        backgroundColor: AppColors.tintMint,
        foregroundColor: AppColors.mintText,
        icon: icon,
      );

  factory KtStatusPill.amber(String label, {IconData? icon}) => KtStatusPill(
        label: label,
        backgroundColor: AppColors.amberTint,
        foregroundColor: AppColors.amberText,
        borderColor: const Color(0xFFF3D587),
        icon: icon,
      );

  factory KtStatusPill.sos(String label, {IconData? icon}) => KtStatusPill(
        label: label,
        backgroundColor: AppColors.sosSoft,
        foregroundColor: AppColors.darurat,
        icon: icon,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted callout banner for privacy notes and contextual help.
class KtInfoBanner extends StatelessWidget {
  const KtInfoBanner({
    required this.message,
    super.key,
    this.title,
    this.icon = Icons.shield_outlined,
    this.backgroundColor = AppColors.tintIndigo,
    this.borderColor = AppColors.borderHairline,
    this.iconColor = AppColors.biruTinta,
    this.textColor = AppColors.inkSlate,
    this.trailing,
    this.onTap,
  });

  final String? title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KtCard(
      color: backgroundColor,
      borderColor: borderColor,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: title != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTextStyles.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: AppTextStyles.inter(
                    fontSize: 12.5,
                    color: textColor,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Minimal vector Google "G" mark rendered natively with CustomPainter.
class GoogleLogoMark extends StatelessWidget {
  const GoogleLogoMark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final strokeWidth = s * 0.19;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: (s - strokeWidth) / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red top-left arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.65, 1.85, false, paint);

    // Yellow bottom-left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.35, false, paint);

    // Green bottom-right arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.55, 1.85, false, paint);

    // Blue right arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.15, 0.78, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.50, s * 0.41, s * 0.44, strokeWidth),
        Radius.circular(strokeWidth * 0.25),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
