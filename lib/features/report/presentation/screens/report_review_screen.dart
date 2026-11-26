import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_preview.dart';
import 'package:kitatemani/features/report/presentation/widgets/report_step_indicator.dart';

class ReportReviewScreen extends ConsumerStatefulWidget {
  const ReportReviewScreen({super.key});

  @override
  ConsumerState<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends ConsumerState<ReportReviewScreen> {
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    final controller = ref.read(submitReportControllerProvider.notifier);
    final result = await controller.submitCurrentDraft();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result case Ok()) {
      await Navigator.of(context).pushReplacementNamed(AppRoutes.reportSent);
    } else if (result case Err(:final failure)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.darurat,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(submitReportControllerProvider);
    final student = ref.watch(studentProfileProvider);

    final reporterName =
        student.name.trim().isNotEmpty ? student.name.trim() : 'Siswa';
    final reporterLabel = student.className.trim().isNotEmpty
        ? '$reporterName (${student.className.trim()})'
        : reporterName;
    final reporterIdentity = student.className.trim().isNotEmpty
        ? '$reporterName · ${student.className.trim()}'
        : reporterName;

    final typeNames = draft.selectedTypes.map((t) => t.label).join(', ');
    final narrativeText = draft.narrative.trim().isEmpty
        ? 'Laporan bullying di lingkungan sekolah untuk ditinjau secara privat oleh Guru BK.'
        : draft.narrative.trim();

    final evidenceList = <String>[
      if (draft.attachments.isNotEmpty)
        '${draft.attachments.length} dokumen (PDF/DOCX)',
      if (draft.evidenceLink.trim().isNotEmpty) '1 link bukti terlampir',
    ];
    final evidenceSummary = evidenceList.isEmpty
        ? 'Tidak ada lampiran tambahan'
        : evidenceList.join(' · ');

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      KtPageHeader(
                        title: 'Tinjau laporan',
                        trailing: KtStatusPill.indigo('Langkah 3 dari 3'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: ReportStepIndicator(currentStep: 3),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          children: [
                            Text(
                              'Pastikan detail laporanmu sudah sesuai sebelum dikirim ke Guru BK.',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 14),

                            // Summary Card
                            KtCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'RINGKASAN LAPORAN',
                                          style: AppTextStyles.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.7,
                                            color: AppColors.inkSlate,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      KtStatusPill.indigo(
                                        draft.isVictim
                                            ? 'Korban langsung'
                                            : 'Saksi kejadian',
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 22),
                                  _SummaryRow(
                                    label: 'Pelapor',
                                    value: reporterLabel,
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryRow(
                                    label: 'Nama korban',
                                    value: draft.victimName.trim().isEmpty
                                        ? 'Belum disebutkan'
                                        : draft.victimName.trim(),
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryRow(
                                    label: 'List nama pelaku',
                                    value: draft.perpetratorNames.trim().isEmpty
                                        ? 'Belum disebutkan'
                                        : draft.perpetratorNames.trim(),
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryRow(
                                    label: 'Jenis bullying',
                                    value:
                                        typeNames.isEmpty ? 'Umum' : typeNames,
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryRow(
                                    label: 'Tanggal & lokasi',
                                    value:
                                        '${draft.whenLabel} · ${draft.location.trim().isEmpty ? 'Belum disebutkan' : draft.location.trim()}',
                                  ),
                                  const SizedBox(height: 8),
                                  _SummaryRow(
                                    label: 'Bukti & link',
                                    value: evidenceSummary,
                                  ),
                                  if (draft.evidenceFiles.isNotEmpty ||
                                      draft.attachments.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: (draft.evidenceFiles.isNotEmpty
                                              ? draft.evidenceFiles
                                              : draft.attachments
                                                  .map(
                                                    (f) => EvidenceAttachment(
                                                        fileName: f),
                                                  )
                                                  .toList())
                                          .map(
                                            (item) => EvidenceAttachmentChip(
                                              attachment: item,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                  if (draft.evidenceLink.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    EvidenceLinkCard(
                                      url: draft.evidenceLink.trim(),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Text(
                                    'Kronologi kejadian:',
                                    style: AppTextStyles.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.canvas,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      narrativeText,
                                      style: AppTextStyles.inter(
                                        fontSize: 13,
                                        color: AppColors.inkNavy,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Mint Card: Diterima Guru BK
                            KtCard(
                              color: AppColors.tintMint,
                              borderColor:
                                  AppColors.hijau.withValues(alpha: 0.25),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.hijau,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'DITERIMA GURU BK',
                                          style: AppTextStyles.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: AppColors.mintText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _BulletLine(
                                    text:
                                        'Identitasmu ($reporterIdentity) agar Guru BK bisa mendampingi tepat sasaran.',
                                    color: AppColors.hijau,
                                  ),
                                  const _BulletLine(
                                    text:
                                        'Jenis bullying, nama korban, list nama pelaku, tanggal, lokasi, & kronologi ceritamu.',
                                    color: AppColors.hijau,
                                  ),
                                  const _BulletLine(
                                    text:
                                        'Lampiran dokumen bukti (PDF/DOCX maks. 2 MB) & link bukti jika disertakan.',
                                    color: AppColors.hijau,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Privacy Guarantee Card: Dijaga Rahasia
                            const KtCard(
                              padding: EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: AppColors.biruTinta,
                                        size: 19,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'DIJAGA RAHASIA',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: AppColors.inkNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  _BulletLine(
                                    text:
                                        'Laporanmu tidak pernah dibuka ke siswa lain atau terduga pelaku.',
                                    color: AppColors.biruTinta,
                                  ),
                                  _BulletLine(
                                    text:
                                        'Lokasi GPS real-time saat kamu mengisi laporan tidak dibagikan.',
                                    color: AppColors.biruTinta,
                                  ),
                                  _BulletLine(
                                    text:
                                        'Riwayat curhat pribadimu di Curhai tetap terpisah dan rahasia.',
                                    color: AppColors.biruTinta,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(
                  top: BorderSide(color: AppColors.borderHairline, width: 1),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: AppButton(
                      label: 'Kirim Laporan Sekarang',
                      isLoading: _isSubmitting,
                      onPressed: _submitReport,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: AppTextStyles.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSlate,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkNavy,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.inter(
                fontSize: 12,
                color: AppColors.inkNavy,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
