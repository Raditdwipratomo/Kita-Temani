import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/widgets/code_highlighter.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/status_stepper.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/panic/presentation/controllers/counselor_panic_alerts_controller.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/l10n/l10n.dart';

enum PantauMonitorCategory {
  laporan('Laporan'),
  panic('Panic Button');

  const PantauMonitorCategory(this.label);
  final String label;
}

class PantauMonitorCategoryNotifier extends Notifier<PantauMonitorCategory> {
  @override
  PantauMonitorCategory build() => PantauMonitorCategory.laporan;

  void setCategory(PantauMonitorCategory category) {
    state = category;
  }
}

final pantauMonitorCategoryProvider =
    NotifierProvider<PantauMonitorCategoryNotifier, PantauMonitorCategory>(
  PantauMonitorCategoryNotifier.new,
);

class MyReportsTabView extends ConsumerWidget {
  const MyReportsTabView({super.key});

  ReportStepStage _stageFor(ReportStatus status) {
    switch (status) {
      case ReportStatus.diterima:
        return ReportStepStage.diterima;
      case ReportStatus.ditinjau:
        return ReportStepStage.ditinjau;
      case ReportStatus.tindakLanjut:
        return ReportStepStage.tindakLanjut;
      case ReportStatus.selesai:
        return ReportStepStage.selesai;
    }
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

  Future<void> _refreshAll(WidgetRef ref, bool isStaff) async {
    await ref.read(myReportsControllerProvider.notifier).refresh();
    if (isStaff) {
      await ref.read(counselorPanicAlertsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffInfo = ref.watch(
      studentProfileProvider.select(
        (p) => (
          isStaff: p.role.isStaff,
          counselorName: p.counselorName,
        ),
      ),
    );
    final isStaff = staffInfo.isStaff;
    final reportsData = ref.watch(
      myReportsControllerProvider.select(
        (s) => (
          filter: s.filter,
          allEmpty: s.reports.isEmpty,
          totalCount: s.reports.length,
          filtered: s.filteredReports,
        ),
      ),
    );
    final panicAlerts = isStaff
        ? ref.watch(counselorPanicAlertsProvider)
        : const <CounselorPanicAlert>[];
    final category = isStaff
        ? ref.watch(pantauMonitorCategoryProvider)
        : PantauMonitorCategory.laporan;

    final filter = reportsData.filter;
    final visibleReports = category == PantauMonitorCategory.panic
        ? const <AnonymousReportItem>[]
        : reportsData.filtered;
    final visiblePanics = category == PantauMonitorCategory.laporan
        ? const <CounselorPanicAlert>[]
        : panicAlerts;
    final activePanicCount = panicAlerts.where((a) => a.isActive).length;

    final bool isCompletelyEmpty = isStaff
        ? (visibleReports.isEmpty && visiblePanics.isEmpty)
        : visibleReports.isEmpty;
    final int totalFeedItems = visiblePanics.length + visibleReports.length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double maxContentWidth = 720;
            final double horizontalPadding =
                constraints.maxWidth > maxContentWidth
                    ? (constraints.maxWidth - maxContentWidth) / 2 + 20
                    : 18;
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                92,
              ),
              itemCount: isCompletelyEmpty ? 2 : 1 + totalFeedItems,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isStaff
                                  ? 'Pantau Laporan & SOS'
                                  : L10n.myReportsTitle,
                              style: AppTextStyles.heading1,
                            ),
                          ),
                          CircleActionButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Muat ulang laporan',
                            onTap: () => unawaited(_refreshAll(ref, isStaff)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Counselor 2-Tab Bar: Laporan & Panic Button
                      if (isStaff) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.borderHairline,
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _PantauTabButton(
                                  key: const Key('pantau_category_laporan'),
                                  label: 'Laporan',
                                  badgeText: '${reportsData.totalCount}',
                                  icon: Icons.assignment_outlined,
                                  selected:
                                      category == PantauMonitorCategory.laporan,
                                  onTap: () => ref
                                      .read(
                                        pantauMonitorCategoryProvider.notifier,
                                      )
                                      .setCategory(
                                        PantauMonitorCategory.laporan,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _PantauTabButton(
                                  key: const Key('pantau_category_panic'),
                                  label: 'Panic Button',
                                  badgeText: activePanicCount > 0
                                      ? '$activePanicCount Aktif'
                                      : '${panicAlerts.length}',
                                  icon: Icons.emergency_share_outlined,
                                  isDangerAccent: activePanicCount > 0,
                                  selected:
                                      category == PantauMonitorCategory.panic,
                                  onTap: () => ref
                                      .read(
                                        pantauMonitorCategoryProvider.notifier,
                                      )
                                      .setCategory(PantauMonitorCategory.panic),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Status Filter Pills for Reports
                      if (!isStaff ||
                          category != PantauMonitorCategory.panic) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterPill(
                                label: 'Semua',
                                selected: filter == ReportListFilter.semua,
                                onTap: () => ref
                                    .read(myReportsControllerProvider.notifier)
                                    .setFilter(ReportListFilter.semua),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Dikirim',
                                selected: filter == ReportListFilter.dikirim,
                                onTap: () => ref
                                    .read(myReportsControllerProvider.notifier)
                                    .setFilter(ReportListFilter.dikirim),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Dibaca',
                                selected: filter == ReportListFilter.dibaca,
                                onTap: () => ref
                                    .read(myReportsControllerProvider.notifier)
                                    .setFilter(ReportListFilter.dibaca),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Ditindak',
                                selected: filter == ReportListFilter.ditindak,
                                onTap: () => ref
                                    .read(myReportsControllerProvider.notifier)
                                    .setFilter(ReportListFilter.ditindak),
                              ),
                              const SizedBox(width: 8),
                              _FilterPill(
                                label: 'Selesai',
                                selected: filter == ReportListFilter.selesai,
                                onTap: () => ref
                                    .read(myReportsControllerProvider.notifier)
                                    .setFilter(ReportListFilter.selesai),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                }

                if (isCompletelyEmpty) {
                  final String emptyTitle;
                  final String emptyBody;
                  if (isStaff) {
                    if (category == PantauMonitorCategory.panic) {
                      emptyTitle = 'Belum ada sinyal Panic Button';
                      emptyBody =
                          'Sinyal darurat SOS yang dikirim siswa akan langsung muncul di sini untuk segera ditangani Guru BK.';
                    } else if (!reportsData.allEmpty) {
                      emptyTitle = 'Belum ada laporan pada filter ini';
                      emptyBody = 'Ubah filter untuk melihat laporan lainnya.';
                    } else {
                      emptyTitle = 'Belum ada laporan masuk dari siswa';
                      emptyBody =
                          'Laporan bullying yang dikirim siswa akan muncul di sini untuk ditinjau Guru BK.';
                    }
                  } else {
                    emptyTitle = reportsData.allEmpty
                        ? 'Belum ada laporan yang dibuat'
                        : 'Belum ada laporan pada filter ini';
                    emptyBody = reportsData.allEmpty
                        ? 'Laporan bullying yang kamu kirim ke Guru BK akan tercatat rapi dan bisa kamu pantau statusnya di sini.'
                        : 'Ubah filter untuk melihat laporan lainnya.';
                  }

                  return KtCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tintIndigo,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const KitaIllustration(
                            scene: IllustrationScene.emptyReports,
                            width: 112,
                            height: 90,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading3,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          emptyBody,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall,
                        ),
                        if (reportsData.allEmpty && !isStaff) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pushNamed(AppRoutes.reportType),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Buat laporan pertama'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.biruTinta,
                              backgroundColor: AppColors.tintIndigo,
                              side: BorderSide(
                                color:
                                    AppColors.biruTinta.withValues(alpha: 0.25),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 11,
                              ),
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final itemIndex = index - 1;
                if (itemIndex < visiblePanics.length) {
                  final alert = visiblePanics[itemIndex];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PanicAlertMonitorCard(
                      alert: alert,
                      counselorName: staffInfo.counselorName,
                      onResolve: () async {
                        await ref
                            .read(counselorPanicAlertsProvider.notifier)
                            .resolveAlert(alert.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sinyal Panic Button ditandai tertangani.',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                final report = visibleReports[itemIndex - visiblePanics.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: KtCard(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReportDetailScreen(
                            reportCode: report.code,
                            asCounselor: isStaff,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        await _refreshAll(ref, isStaff);
                      }
                    },
                    borderColor: AppColors.biruTinta.withValues(alpha: 0.55),
                    borderWidth: 1.4,
                    borderRadius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormatter.dayMonth(report.occurredAt)} · ${report.location}',
                                style: AppTextStyles.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkSlate,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusPillFor(report.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CodeHighlighter(code: report.code, fontSize: 12),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                report.types.map((t) => t.label).join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isStaff &&
                            report.reporterName.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Pelapor: ${report.formattedReporterIdentity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkSlate,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        StatusStepper(
                          currentStage: _stageFor(report.status),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: isStaff
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.biruTinta,
              elevation: 2,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.reportType),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'Buat laporan',
                style: AppTextStyles.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

class _PantauTabButton extends StatelessWidget {
  const _PantauTabButton({
    required this.label,
    required this.badgeText,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isDangerAccent = false,
    super.key,
  });

  final String label;
  final String badgeText;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDangerAccent;

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        isDangerAccent ? AppColors.darurat : AppColors.biruTinta;
    final Color bg = selected ? activeColor : Colors.transparent;
    final Color fg = selected
        ? Colors.white
        : (isDangerAccent ? AppColors.crimsonContrast : AppColors.inkNavy);
    final Color badgeBg = selected
        ? Colors.white.withValues(alpha: 0.22)
        : (isDangerAccent ? AppColors.sosSoft : AppColors.tintIndigo);
    final Color badgeFg = selected
        ? Colors.white
        : (isDangerAccent ? AppColors.crimsonContrast : AppColors.biruTinta);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText,
                style: AppTextStyles.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: badgeFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanicAlertMonitorCard extends StatelessWidget {
  const _PanicAlertMonitorCard({
    required this.alert,
    required this.counselorName,
    required this.onResolve,
  });

  final CounselorPanicAlert alert;
  final String counselorName;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final isActive = alert.isActive;
    final timeText = alert.startedAt != null
        ? DateFormatter.formatDisplay(alert.startedAt!)
        : null;

    return KtCard(
      color: isActive
          ? AppColors.sosSoft.withValues(alpha: 0.45)
          : AppColors.cardWhite,
      borderColor: isActive
          ? AppColors.darurat.withValues(alpha: 0.5)
          : AppColors.borderHairline,
      borderWidth: isActive ? 1.4 : 1.0,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.sosSoft : AppColors.tintMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.emergency_share_rounded,
                  size: 18,
                  color: isActive ? AppColors.darurat : AppColors.hijau,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.studentName}${alert.className.isNotEmpty ? ' (${alert.className})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading3,
                    ),
                    Text(
                      timeText != null
                          ? 'Sinyal Panic Button · $timeText'
                          : 'Sinyal Panic Button',
                      style: AppTextStyles.inter(
                        fontSize: 11.5,
                        color: isActive
                            ? AppColors.crimsonContrast
                            : AppColors.inkSlate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isActive
                  ? KtStatusPill.sos('SOS Aktif')
                  : KtStatusPill.mint('Tertangani'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (alert.schoolName.trim().isNotEmpty)
                'Sekolah: ${alert.schoolName.trim()}',
              if (alert.situationNote.trim().isNotEmpty)
                'Situasi: ${alert.situationNote.trim()}',
              if (alert.areaHint.trim().isNotEmpty)
                'Area: ${alert.areaHint.trim()}',
              'Lokasi: ${alert.locationLabel}',
              'Petugas: $counselorName',
            ].join('\n'),
            style: AppTextStyles.bodySmall.copyWith(height: 1.45),
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: Key('pantau_resolve_panic_${alert.id}'),
                onPressed: onResolve,
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                ),
                label: const Text('Tandai Tertangani'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.mintText,
                  side: const BorderSide(color: AppColors.hijau),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.biruTinta : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.biruTinta : AppColors.borderHairline,
            width: 1.1,
          ),
          boxShadow: selected ? AppColors.buttonShadow : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.inkSlate,
          ),
        ),
      ),
    );
  }
}
