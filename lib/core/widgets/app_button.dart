import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.trailingIcon,
    this.isOutlined = false,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.height = 52,
    this.borderRadius = 26,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final isDanger = backgroundColor == AppColors.darurat ||
        backgroundColor == AppColors.sosDanger;

    final Color textColor = foregroundColor ??
        (isOutlined
            ? AppColors.inkNavy
            : (disabled ? AppColors.inkSlate : Colors.white));

    final Gradient? activeGradient = (!isOutlined &&
            !disabled &&
            (backgroundColor == null || backgroundColor == AppColors.biruTinta))
        ? AppColors.primaryButtonGradient
        : (!isOutlined && !disabled && isDanger
            ? AppColors.panicActiveGradient
            : null);

    final Color solidBg = isOutlined
        ? (backgroundColor ?? AppColors.cardWhite)
        : (disabled
            ? const Color(0xFFDDE1F2)
            : (backgroundColor ?? AppColors.biruTinta));

    final List<BoxShadow>? shadow = (isOutlined || disabled)
        ? null
        : (isDanger ? AppColors.sosShadow : AppColors.buttonShadow);

    final radius = BorderRadius.circular(borderRadius);

    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: textColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: textColor),
              ],
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: activeGradient == null ? solidBg : null,
        gradient: activeGradient,
        borderRadius: radius,
        border: isOutlined
            ? Border.all(
                color: foregroundColor == AppColors.darurat
                    ? AppColors.darurat.withValues(alpha: 0.35)
                    : AppColors.borderHairline,
                width: 1.2,
              )
            : null,
        boxShadow: shadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: radius,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
