import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';

class CodeHighlighter extends StatelessWidget {
  const CodeHighlighter({
    required this.code,
    super.key,
    this.fontSize = 13,
  });

  final String code;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.72,
        vertical: fontSize * 0.32,
      ),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.biruTinta.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
      child: Text(
        code,
        style: AppTextStyles.code(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.biruTinta,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
