import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/articles/presentation/controllers/articles_controller.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/panic/presentation/controllers/counselor_panic_alerts_controller.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';

class _SchoolAiSummaryData {
  const _SchoolAiSummaryData({
    required this.riskCases,
    required this.onlineCases,
    required this.summaryText,
    required this.recommendation,
  });

  final int riskCases;
  final int onlineCases;
  final String summaryText;
  final String recommendation;
}

class SchoolSummaryScreen extends ConsumerStatefulWidget {
  const SchoolSummaryScreen({super.key});

  @override
  ConsumerState<SchoolSummaryScreen> createState() =>
      _SchoolSummaryScreenState();
}

class _SchoolSummaryScreenState extends ConsumerState<SchoolSummaryScreen> {
  bool _isGenerating = false;
  _SchoolAiSummaryData? _aiSummary;
  ReportStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCounselorData);
  }

  Future<void> _loadCounselorData() async {
    if (!ref.read(studentProfileProvider).role.isStaff) return;
    await ref.read(myReportsControllerProvider.notifier).refresh();
    await ref.read(counselorPanicAlertsProvider.notifier).refresh();
    await _generateAiSummary();
  }

  Future<void> _resolvePanicAlert(String alertId) async {
    await ref.read(counselorPanicAlertsProvider.notifier).resolveAlert(alertId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Peringatan darurat ditandai tertangani.'),
      ),
    );
  }

  Future<void> _generateAiSummary() async {
    setState(() => _isGenerating = true);
    final client = ref.read(supabaseClientProvider);
    final student = ref.read(studentProfileProvider);

    if (client != null && client.auth.currentSession != null) {
      try {
        final res = await client.functions.invoke(
          'school-summary',
          body: {'school_slug': student.schoolId, 'period': '7d'},
        );
        final data = res.data;
        if (data is Map && data['summary'] is Map && mounted) {
          final s = Map<String, dynamic>.from(data['summary'] as Map);
          setState(() {
            _isGenerating = false;
            _aiSummary = _SchoolAiSummaryData(
              riskCases: (s['risk_cases'] as num?)?.toInt() ?? 0,
              onlineCases: (s['online_cases'] as num?)?.toInt() ?? 0,
              summaryText: (s['summary_text'] ?? '').toString(),
              recommendation: (s['recommendation'] ?? '').toString(),
            );
          });
          return;
        }
      } on Object {
        // Fall through to honest empty/real count summary below.
      }
    }

    final reports = ref.read(myReportsControllerProvider).reports;
    final risk = reports
        .where(
          (r) => r.types.any((t) => t.name == 'fisik' || t.name == 'verbal'),
        )
        .length;
    final online =
        reports.where((r) => r.types.any((t) => t.name == 'siber')).length;

    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _aiSummary = _SchoolAiSummaryData(
        riskCases: risk,
        onlineCases: online,
        summaryText: reports.isEmpty
            ? 'Belum ada laporan masuk untuk dirangkum pada periode ini.'
            : 'Dari ${reports.length} laporan teragregasi: $risk kasus fisik/verbal & $online kasus siber.',
        recommendation: reports.isEmpty
            ? 'Ringkasan AI akan otomatis dihasilkan setelah ada laporan masuk.'
            : 'Tekan tombol muat ulang di kanan atas untuk menghasilkan analisis AI terbaru.',
      );
    });
  }

  KtStatusPill _statusPillFor(ReportStatus status) {
    switch (status) {
      case ReportStatus.diterima:
        return KtStatusPill.indigo(status.label);
      case ReportStatus.ditinjau:
        return KtStatusPill.indigo(status.label);
      case ReportStatus.tindakLanjut:
        return KtStatusPill.amber(status.label, icon: Icons.flag_outlined);
      case ReportStatus.selesai:
        return KtStatusPill.mint(status.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports =
        ref.watch(myReportsControllerProvider.select((s) => s.reports));
    final panicAlerts = ref.watch(counselorPanicAlertsProvider);
    final articlesCount =
        ref.watch(articlesControllerProvider.select((s) => s.articles.length));
    final student = ref.watch(
      studentProfileProvider.select(
        (p) => (
          isStaff: p.role.isStaff,
          counselorName: p.counselorName,
        ),
      ),
    );
    final summary = _aiSummary;

    if (!student.isStaff) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: KtCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.tintIndigo,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.biruTinta,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Akses Khusus Guru BK',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Halaman ringkasan sekolah hanya tersedia bagi akun staf Guru BK atau Wali Kelas yang berwenang.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 18),
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
        ),
      );
    }

    final filteredReports = _statusFilter == null
        ? reports
        : reports.where((r) => r.status == _statusFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: KtPageHeader(
                  title: 'Insight Sekolah & Panel BK',
                  trailing: IconButton(
                    tooltip: 'Perbarui Ringkasan AI',
                    onPressed: _isGenerating ? null : _loadCounselorData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.biruTinta,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: AppColors.heroCardGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppColors.buttonShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFF6BE4F),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Ringkasan AI Sekolah',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (_isGenerating)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              summary != null
                                  ? '${summary.summaryText}\n• Risiko Fisik/Verbal: ${summary.riskCases} laporan | Online/Siber: ${summary.onlineCases} laporan\n• Rekomendasi: ${summary.recommendation}'
                                  : 'Menghitung tren teragregasi tanpa identitas pelapor...',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.48,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Shortcut Kelola Artikel Edukasi (CRUD Guru BK)
                      KtCard(
                        padding: const EdgeInsets.all(16),
                        color: AppColors.tintIndigo,
                        borderColor:
                            AppColors.biruTinta.withValues(alpha: 0.32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.biruTinta,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kelola Artikel Edukasi ($articlesCount Artikel)',
                                        style: AppTextStyles.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.inkNavy,
                                        ),
                                      ),
                                      Text(
                                        'Buat, edit, atau hapus artikel Ruang Baca untuk siswa',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.articles),
                                  icon: const Icon(
                                    Icons.library_books_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Kelola Ruang Baca'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.biruTinta,
                                    side: const BorderSide(
                                      color: AppColors.biruTinta,
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(AppRoutes.articleCompose),
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('Tulis Artikel'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.biruTinta,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sisi Guru BK menerima Peringatan Darurat (PRD 6.2.1 #8)
                      Text(
                        'PERINGATAN DARURAT MASUK (GURU BK)',
                        style: AppTextStyles.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.inkSlate,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (panicAlerts.isEmpty)
                        const KtInfoBanner(
                          icon: Icons.verified_user_outlined,
                          message:
                              'Tidak ada peringatan darurat aktif saat ini.',
                        )
                      else
                        for (final alert in panicAlerts) ...[
                          KtCard(
                            borderColor: alert.status == 'active'
                                ? AppColors.darurat.withValues(alpha: 0.45)
                                : AppColors.borderHairline,
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.emergency_share_rounded,
                                      color: alert.status == 'active'
                                          ? AppColors.darurat
                                          : AppColors.hijau,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${alert.studentName}${alert.className.isNotEmpty ? ' (${alert.className})' : ''}',
                                        style: AppTextStyles.heading3,
                                      ),
                                    ),
                                    alert.status == 'active'
                                        ? KtStatusPill.sos('Aktif')
                                        : KtStatusPill.mint('Tertangani'),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (alert.schoolName.trim().isNotEmpty)
                                      'Sekolah: ${alert.schoolName.trim()}',
                                    if (alert.situationNote.trim().isNotEmpty)
                                      'Situasi: ${alert.situationNote.trim()}',
                                    if (alert.areaHint.trim().isNotEmpty)
                                      'Area: ${alert.areaHint.trim()}',
                                    'Lokasi: ${alert.locationLabel}',
                                    'Petugas: ${student.counselorName}',
                                  ].join('\n'),
                                  style: AppTextStyles.bodySmall,
                                ),
                                if (alert.status == 'active') ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      key: Key('resolve_panic_${alert.id}'),
                                      onPressed: () =>
                                          _resolvePanicAlert(alert.id),
                                      icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Tandai Tertangani'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.mintText,
                                        side: const BorderSide(
                                          color: AppColors.hijau,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 10),

                      Text(
                        'DAFTAR LAPORAN MASUK (${reports.length} LAPORAN)',
                        style: AppTextStyles.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.inkSlate,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text('Semua (${reports.length})'),
                            selected: _statusFilter == null,
                            showCheckmark: false,
                            selectedColor: AppColors.indigoSoft,
                            onSelected: (_) =>
                                setState(() => _statusFilter = null),
                          ),
                          for (final st in ReportStatus.values)
                            ChoiceChip(
                              label: Text(
                                '${st.label} (${reports.where((r) => r.status == st).length})',
                              ),
                              selected: _statusFilter == st,
                              showCheckmark: false,
                              selectedColor: AppColors.indigoSoft,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = st),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filteredReports.isEmpty)
                        const KtInfoBanner(
                          icon: Icons.inbox_outlined,
                          message: 'Belum ada laporan masuk dari siswa.',
                        )
                      else
                        for (final r in filteredReports)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: KtCard(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ReportDetailScreen(
                                      reportCode: r.code,
                                      asCounselor: true,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                await ref
                                    .read(myReportsControllerProvider.notifier)
                                    .refresh();
                              },
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${r.code} · ${r.primaryType.fullTitle}',
                                          style: AppTextStyles.heading3,
                                        ),
                                      ),
                                      _statusPillFor(r.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lokasi: ${r.location} · Status: ${r.status.label}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  if (r.victimName.trim().isNotEmpty ||
                                      r.perpetratorNames.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (r.victimName.trim().isNotEmpty)
                                          'Korban: ${r.victimName.trim()}',
                                        if (r.perpetratorNames
                                            .trim()
                                            .isNotEmpty)
                                          'Pelaku: ${r.perpetratorNames.trim()}',
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          ref
                                              .read(myReportsControllerProvider
                                                  .notifier)
                                              .simulateStatusUpdate(r.code);
                                        },
                                        child: const Text('Majukan Status'),
                                      ),
                                      const SizedBox(width: 6),
                                      FilledButton.tonalIcon(
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ReportDetailScreen(
                                                reportCode: r.code,
                                                asCounselor: true,
                                              ),
                                            ),
                                          );
                                          if (!mounted) return;
                                          await ref
                                              .read(
                                                myReportsControllerProvider
                                                    .notifier,
                                              )
                                              .refresh();
                                        },
                                        icon: const Icon(
                                          Icons.rate_review_outlined,
                                          size: 16,
                                        ),
                                        label: const Text('Tinjau & Update'),
                                      ),
                                    ],
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
          ],
        ),
      ),
    );
  }
}
