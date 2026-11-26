import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';

enum ReportStepStage {
  diterima('Dikirim'),
  ditinjau('Dibaca'),
  tindakLanjut('Ditindak'),
  selesai('Selesai');

  const ReportStepStage(this.label);
  final String label;
}

class StatusStepper extends StatelessWidget {
  const StatusStepper({
    required this.currentStage,
    super.key,
  });

  final ReportStepStage currentStage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep(ReportStepStage.diterima),
        _buildConnector(0),
        _buildStep(ReportStepStage.ditinjau),
        _buildConnector(1),
        _buildStep(ReportStepStage.tindakLanjut),
        _buildConnector(2),
        _buildStep(ReportStepStage.selesai),
      ],
    );
  }

  Widget _buildStep(ReportStepStage stage) {
    final isDone = stage.index < currentStage.index;
    final isCurrent = stage.index == currentStage.index;
    final stepNumber = '${stage.index + 1}';

    Widget circle;
    if (isDone) {
      circle = Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.hijau,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    } else if (isCurrent) {
      final activeColor = stage == ReportStepStage.tindakLanjut
          ? AppColors.amberText
          : AppColors.biruTinta;
      circle = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            stepNumber,
            style: AppTextStyles.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      circle = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD2D7EE), width: 1.4),
        ),
        child: Center(
          child: Text(
            stepNumber,
            style: AppTextStyles.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSlate,
            ),
          ),
        ),
      );
    }

    final labelColor = isDone
        ? AppColors.hijau
        : (isCurrent
            ? (stage == ReportStepStage.tindakLanjut
                ? AppColors.amberText
                : AppColors.biruTinta)
            : AppColors.inkSlate);

    return Expanded(
      flex: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: 5),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.inter(
              fontSize: 11,
              fontWeight:
                  (isCurrent || isDone) ? FontWeight.w600 : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(int indexBefore) {
    final isDone = indexBefore < currentStage.index;
    return Expanded(
      flex: 1,
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: isDone ? AppColors.hijau : AppColors.borderHairline,
      ),
    );
  }
}
