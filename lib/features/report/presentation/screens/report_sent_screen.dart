import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/code_highlighter.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/status_stepper.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/l10n/l10n.dart';

class ReportSentScreen extends ConsumerWidget {
  const ReportSentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code =
        ref.watch(submitReportControllerProvider).lastSubmittedCode ?? '-';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tintMint,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.hijau.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: const KitaIllustration(
                      scene: IllustrationScene.reportSent,
                      width: 156,
                      height: 124,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    L10n.reportSentTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading1,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kamu sudah mengambil langkah berani. Guru BK akan segera meninjau laporanmu secara privat dan aman.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 22),

                  // Ticket Card ("NOMOR TIKET LAPORAN")
                  KtCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text(
                          'NOMOR TIKET LAPORAN',
                          style: AppTextStyles.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.inkSlate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        CodeHighlighter(code: code, fontSize: 20),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nomor tiket disalin ke papan klip',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Salin tiket'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.inkNavy,
                                  side: const BorderSide(
                                    color: AppColors.borderHairline,
                                    width: 1.2,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    AppRoutes.myReports,
                                    (route) => false,
                                  );
                                },
                                icon: const Icon(
                                  Icons.track_changes_rounded,
                                  size: 16,
                                ),
                                label: const Text('Pantau laporan'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.biruTinta,
                                  backgroundColor: AppColors.tintIndigo,
                                  side: BorderSide(
                                    color: AppColors.biruTinta
                                        .withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stepper
                  KtCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUS LAPORAN SAAT INI',
                          style: AppTextStyles.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.inkSlate,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const StatusStepper(
                            currentStage: ReportStepStage.diterima),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const KtInfoBanner(
                    icon: Icons.verified_user_outlined,
                    message:
                        'Nomor tiket dan riwayat laporanmu tersimpan aman di akunmu, dan hanya bisa diakses olehmu serta Guru BK sekolah.',
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    label: 'Kembali ke Beranda',
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
