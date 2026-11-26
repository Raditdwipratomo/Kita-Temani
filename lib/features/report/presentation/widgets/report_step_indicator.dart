import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';

class ReportStepIndicator extends StatelessWidget {
  const ReportStepIndicator({
    required this.currentStep,
    super.key,
  });

  final int currentStep; // 1: Jenis, 2: Cerita, 3: Kirim

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepItem(
            number: 1,
            label: 'Jenis',
            isActive: currentStep >= 1,
            isCompleted: currentStep > 1,
          ),
          _StepConnector(isActive: currentStep >= 2),
          _StepItem(
            number: 2,
            label: 'Cerita',
            isActive: currentStep >= 2,
            isCompleted: currentStep > 2,
          ),
          _StepConnector(isActive: currentStep >= 3),
          _StepItem(
            number: 3,
            label: 'Kirim',
            isActive: currentStep >= 3,
            isCompleted: false,
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final circleBg = isActive ? AppColors.primary : const Color(0xFFDCE0FC);
    final circleFg = isActive ? Colors.white : AppColors.textSecondary;
    final labelColor = isActive ? AppColors.primary : AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
          ),
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  '$number',
                  style: AppTextStyles.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: circleFg,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.poppins(
            fontSize: 13.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: isActive ? AppColors.primary : const Color(0xFFD5D9F8),
    );
  }
}
