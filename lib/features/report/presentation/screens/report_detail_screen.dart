import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/code_highlighter.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/status_stepper.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_preview.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  const ReportDetailScreen({
    this.reportCode = '',
    this.asCounselor = false,
    super.key,
  });

  final String reportCode;
  final bool asCounselor;

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  ReportDetailData? _detail;
  ReportStatus _selectedStatus = ReportStatus.ditinjau;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail = await ref
        .read(reportRepositoryProvider)
        .getReportDetail(widget.reportCode);
    if (!mounted) return;
    final current = detail.item.status;
    final suggestedNext = switch (current) {
      ReportStatus.diterima => ReportStatus.ditinjau,
      ReportStatus.ditinjau => ReportStatus.tindakLanjut,
      ReportStatus.tindakLanjut => ReportStatus.selesai,
      ReportStatus.selesai => ReportStatus.selesai,
    };
    setState(() {
      _detail = detail;
      _selectedStatus = suggestedNext;
      _isLoading = false;
    });
  }

  Future<void> _applyCounselorStatus({
    required ReportStatus targetStatus,
    String? customNote,
  }) async {
    if (_isUpdatingStatus || widget.reportCode.trim().isEmpty) return;
    setState(() => _isUpdatingStatus = true);
    final resolvedNote = customNote?.trim() ?? '';
    await ref.read(myReportsControllerProvider.notifier).updateReportStatus(
          widget.reportCode,
          nextStatus: targetStatus,
          note: resolvedNote.isEmpty ? null : resolvedNote,
        );
    await _loadDetail();
    if (!mounted) return;
    setState(() => _isUpdatingStatus = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status laporan diperbarui menjadi "${targetStatus.label}".',
        ),
      ),
    );
  }

  ReportStepStage _stageFor(ReportStatus status) {
    return switch (status) {
      ReportStatus.diterima => ReportStepStage.diterima,
      ReportStatus.ditinjau => ReportStepStage.ditinjau,
      ReportStatus.tindakLanjut => ReportStepStage.tindakLanjut,
      ReportStatus.selesai => ReportStepStage.selesai,
    };
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(
      studentProfileProvider.select(
        (p) => (
          isStaff: p.role.isStaff,
          counselorName: p.counselorName,
          name: p.name,
          className: p.className,
          phoneNumber: p.phoneNumber,
          email: p.email,
        ),
      ),
    );
    final detail = _detail;
    final currentStatus = detail?.item.status ?? ReportStatus.diterima;
    final history = detail?.history ?? const [];
    final isCounselor = widget.asCounselor || student.isStaff;
    final evidenceFiles = detail?.item.resolvedEvidenceFiles ?? const [];
    final evidenceLink = detail?.item.evidenceLink?.trim() ?? '';
    final reporterIdentity = detail == null
        ? ''
        : (detail.item.reporterName.trim().isNotEmpty
            ? detail.item.formattedReporterIdentity
            : (!isCounselor && student.name.trim().isNotEmpty
                ? formatReporterIdentity(
                    name: student.name,
                    className: student.className,
                    phone: student.phoneNumber,
                    email: student.email,
                  )
                : formatReporterIdentity(
                    name: detail.item.reporterName,
                    className: detail.item.reporterClass,
                    phone: detail.item.reporterPhone,
                    email: detail.item.reporterEmail,
                  )));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                KtPageHeader(
                  title:
                      isCounselor ? 'Detail & Tindak Lanjut' : 'Detail laporan',
                  trailing:
                      CodeHighlighter(code: widget.reportCode, fontSize: 12),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _loadDetail,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                            children: [
                              // Status & report summary card
                              KtCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'STATUS TINDAK LANJUT',
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
                                          currentStatus.label,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    StatusStepper(
                                      currentStage: _stageFor(currentStatus),
                                    ),
                                    if (detail != null) ...[
                                      const Divider(height: 18),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'DETAIL LAPORAN',
                                              style: AppTextStyles.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.7,
                                                color: AppColors.inkSlate,
                                              ),
                                            ),
                                          ),
                                          if (isCounselor)
                                            KtStatusPill.mint(
                                              'Privasi Terlindungi',
                                              icon: Icons.shield_outlined,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _DetailSummaryRow(
                                        label: 'Identitas pelapor',
                                        value: reporterIdentity,
                                      ),
                                      const SizedBox(height: 6),
                                      _DetailSummaryRow(
                                        label: 'Peran pelapor',
                                        value: detail.item.isVictim
                                            ? 'Korban langsung'
                                            : 'Saksi kejadian',
                                      ),
                                      const SizedBox(height: 6),
                                      _DetailSummaryRow(
                                        label: 'Jenis bullying',
                                        value: detail.item.types.isEmpty
                                            ? 'Umum'
                                            : detail.item.types
                                                .map((t) => t.label)
                                                .join(', '),
                                      ),
                                      const SizedBox(height: 6),
                                      _DetailSummaryRow(
                                        label: 'Tanggal & lokasi',
                                        value:
                                            '${DateFormatter.fullDate(detail.item.occurredAt)} · ${detail.item.location.trim().isEmpty ? 'Belum disebutkan' : detail.item.location.trim()}',
                                      ),
                                      const SizedBox(height: 6),
                                      _DetailSummaryRow(
                                        label: 'Nama korban',
                                        value: detail.item.victimName
                                                .trim()
                                                .isEmpty
                                            ? 'Belum disebutkan'
                                            : detail.item.victimName.trim(),
                                      ),
                                      const SizedBox(height: 6),
                                      _DetailSummaryRow(
                                        label: 'List nama pelaku',
                                        value: detail.item.perpetratorNames
                                                .trim()
                                                .isEmpty
                                            ? 'Belum disebutkan'
                                            : detail.item.perpetratorNames
                                                .trim(),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Cerita kejadian',
                                        style: AppTextStyles.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.canvas,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          detail.item.narrative,
                                          style: AppTextStyles.inter(
                                            fontSize: 13,
                                            color: AppColors.inkNavy,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Counselor interactive status & note panel
                              if (isCounselor) ...[
                                const SizedBox(height: 18),
                                Text(
                                  'PANEL TINDAK LANJUT GURU BK',
                                  style: AppTextStyles.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                    color: AppColors.inkNavy,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                KtCard(
                                  borderColor: AppColors.biruTinta
                                      .withValues(alpha: 0.35),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (currentStatus ==
                                          ReportStatus.diterima) ...[
                                        const KtInfoBanner(
                                          icon: Icons.mark_email_read_outlined,
                                          title: 'Laporan baru masuk (Dikirim)',
                                          message:
                                              'Tandai laporan ini sudah dibaca agar siswa mengetahui laporannya sedang ditinjau Guru BK.',
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            key: const Key(
                                              'counselor_mark_read_button',
                                            ),
                                            onPressed: _isUpdatingStatus
                                                ? null
                                                : () => _applyCounselorStatus(
                                                      targetStatus:
                                                          ReportStatus.ditinjau,
                                                      customNote:
                                                          'Guru BK telah membaca detail laporan dan mulai melakukan verifikasi awal.',
                                                    ),
                                            icon: const Icon(
                                              Icons.done_all_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Tandai Sudah Dibaca',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.biruTinta,
                                              side: const BorderSide(
                                                color: AppColors.biruTinta,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Divider(height: 22),
                                      ],
                                      Text(
                                        'Pilih Tahap Status Laporan',
                                        style: AppTextStyles.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: ReportStatus.values.map((st) {
                                          final selected =
                                              _selectedStatus == st;
                                          return ChoiceChip(
                                            key: Key(
                                              'counselor_stage_${st.wireValue}',
                                            ),
                                            label: Text(st.label),
                                            selected: selected,
                                            showCheckmark: false,
                                            selectedColor: AppColors.indigoSoft,
                                            backgroundColor:
                                                AppColors.cardWhite,
                                            labelStyle: AppTextStyles.inter(
                                              fontSize: 12.5,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? AppColors.biruTinta
                                                  : AppColors.inkNavy,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                color: selected
                                                    ? AppColors.biruTinta
                                                    : AppColors.borderHairline,
                                                width: selected ? 1.4 : 1.1,
                                              ),
                                            ),
                                            onSelected: (_) => setState(
                                              () => _selectedStatus = st,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 14),
                                      AppButton(
                                        key: const Key(
                                          'counselor_save_status_button',
                                        ),
                                        label:
                                            'Simpan Status (${_selectedStatus.label})',
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        isLoading: _isUpdatingStatus,
                                        onPressed: () => _applyCounselorStatus(
                                          targetStatus: _selectedStatus,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Evidence Preview Section
                              if (evidenceFiles.isNotEmpty ||
                                  evidenceLink.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'BUKTI & LAMPIRAN',
                                        style: AppTextStyles.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.7,
                                          color: AppColors.inkNavy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Klik / Ctrl+Klik untuk preview',
                                        textAlign: TextAlign.end,
                                        style: AppTextStyles.inter(
                                          fontSize: 11,
                                          color: AppColors.inkSlate,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                for (final att in evidenceFiles) ...[
                                  EvidencePreviewCard(attachment: att),
                                  const SizedBox(height: 10),
                                ],
                                if (evidenceLink.isNotEmpty)
                                  EvidenceLinkCard(url: evidenceLink),
                              ],
                              const SizedBox(height: 20),

                              // Riwayat Timeline
                              Text(
                                'RIWAYAT TINDAK LANJUT',
                                style: AppTextStyles.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  color: AppColors.inkNavy,
                                ),
                              ),
                              const SizedBox(height: 10),
                              KtCard(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    for (var i = 0;
                                        i < history.length;
                                        i++) ...[
                                      _TimelineRow(
                                        date: DateFormatter.formatDisplay(
                                          history[i].changedAt,
                                        ),
                                        title: history[i].title,
                                        desc: history[i].description,
                                        isDone: true,
                                      ),
                                      if (i < history.length - 1)
                                        const SizedBox(height: 12),
                                    ],
                                    if (currentStatus !=
                                        ReportStatus.selesai) ...[
                                      const SizedBox(height: 12),
                                      const _TimelineRow(
                                        date: 'Berjalan',
                                        title: 'Pendampingan Lanjutan',
                                        desc:
                                            'Penanganan aman tanpa membuka laporan ke siswa lain.',
                                        isDone: false,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              KtInfoBanner(
                                icon: Icons.lock_outline_rounded,
                                message:
                                    'Laporan ini bersifat privat dan hanya dapat diakses oleh pelapor serta ${student.counselorName}.',
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.date,
    required this.title,
    required this.desc,
    required this.isDone,
  });

  final String date;
  final String title;
  final String desc;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isDone ? AppColors.hijau : AppColors.cardWhite,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? AppColors.hijau : const Color(0xFFC9CFE6),
              width: 1.8,
            ),
          ),
          child: isDone
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTextStyles.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: AppTextStyles.inter(
                      fontSize: 11,
                      color: AppColors.inkSlate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: AppTextStyles.inter(
                  fontSize: 12,
                  color: AppColors.inkSlate,
                  height: 1.38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailSummaryRow extends StatelessWidget {
  const _DetailSummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
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
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkNavy,
            ),
          ),
        ),
      ],
    );
  }
}
