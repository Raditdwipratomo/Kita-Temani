import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/widgets/code_highlighter.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/main_shell_scaffold.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/core/widgets/status_stepper.dart';
import 'package:kitatemani/features/articles/presentation/controllers/articles_controller.dart';
import 'package:kitatemani/features/articles/presentation/screens/articles_feed_screen.dart';
import 'package:kitatemani/features/articles/presentation/widgets/article_feed_card.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/curhai/presentation/screens/curhai_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/profile_screen.dart';
import 'package:kitatemani/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/screens/my_reports_screen.dart';
import 'package:kitatemani/features/report/presentation/screens/report_detail_screen.dart';
import 'package:kitatemani/l10n/l10n.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isStaff =
        ref.watch(studentProfileProvider.select((p) => p.role.isStaff));

    final List<Widget> pages = isStaff
        ? [
            _CounselorDashboardTabView(
              onOpenReportsTab: ({ReportListFilter? filter}) {
                ref
                    .read(pantauMonitorCategoryProvider.notifier)
                    .setCategory(PantauMonitorCategory.laporan);
                if (filter != null) {
                  ref
                      .read(myReportsControllerProvider.notifier)
                      .setFilter(filter);
                }
                setState(() => _currentTab = 1);
              },
              onOpenArticlesTab: () => setState(() => _currentTab = 2),
              onOpenProfileTab: () => setState(() => _currentTab = 3),
            ),
            const MyReportsTabView(),
            const ArticlesFeedScreen(isTabView: true),
            const ProfileScreen(isTabView: true),
          ]
        : [
            _BerandaTabView(
              onOpenReportsTab: () => setState(() => _currentTab = 2),
              onOpenCurhaiTab: () => setState(() => _currentTab = 1),
              onOpenProfileTab: () => setState(() => _currentTab = 3),
            ),
            const CurhaiScreen(),
            const MyReportsTabView(),
            const ProfileScreen(isTabView: true),
          ];

    return MainShellScaffold(
      currentIndex: _currentTab,
      isCounselorMode: isStaff,
      onTabSelected: (index) => setState(() => _currentTab = index),
      onPanicPressed: () {
        if (!isStaff) {
          Navigator.of(context).pushNamed(AppRoutes.panic);
        }
      },
      body: IndexedStack(
        index: _currentTab,
        children: pages,
      ),
    );
  }
}

class _CounselorDashboardTabView extends ConsumerWidget {
  const _CounselorDashboardTabView({
    required this.onOpenReportsTab,
    required this.onOpenArticlesTab,
    required this.onOpenProfileTab,
  });

  final void Function({ReportListFilter? filter}) onOpenReportsTab;
  final VoidCallback onOpenArticlesTab;
  final VoidCallback onOpenProfileTab;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(studentProfileProvider);
    final reports =
        ref.watch(myReportsControllerProvider.select((s) => s.reports));
    final articles =
        ref.watch(articlesControllerProvider.select((s) => s.articles));
    final articlesNotifier = ref.read(articlesControllerProvider.notifier);
    final previewArticles = articles.take(2).toList();

    final dikirimCount =
        reports.where((r) => r.status == ReportStatus.diterima).length;
    final dibacaCount =
        reports.where((r) => r.status == ReportStatus.ditinjau).length;
    final ditindakCount =
        reports.where((r) => r.status == ReportStatus.tindakLanjut).length;
    final selesaiCount =
        reports.where((r) => r.status == ReportStatus.selesai).length;
    final recentReports = reports.take(3).toList();

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

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                28,
              ),
              children: [
                // 1. Counselor Top Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: onOpenProfileTab,
                      child: ProfileAvatarWidget(
                        profile: student,
                        size: 44,
                        borderRadius: 14,
                        showShadow: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard Konselor & Admin',
                            style: AppTextStyles.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.biruTinta,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  student.name.trim().isNotEmpty
                                      ? student.name.trim()
                                      : (student.shortName.trim().isNotEmpty
                                          ? student.shortName.trim()
                                          : 'Guru BK'),
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.poppins(
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkNavy,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              KtStatusPill.indigo(
                                'Guru BK',
                                icon: Icons.verified_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    CircleActionButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Muat ulang laporan sekolah',
                      onTap: () => ref
                          .read(myReportsControllerProvider.notifier)
                          .refresh(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. 4-Stage Status Monitoring Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pemantauan Status Laporan',
                      style: AppTextStyles.heading2,
                    ),
                    TextButton(
                      onPressed: () =>
                          onOpenReportsTab(filter: ReportListFilter.semua),
                      child: const Text('Buka Pantau'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CounselorStageCountCard(
                        title: 'Dikirim',
                        subtitle: 'Laporan baru masuk',
                        count: dikirimCount,
                        icon: Icons.mark_email_unread_outlined,
                        background: AppColors.tintIndigo,
                        accent: AppColors.biruTinta,
                        onTap: () =>
                            onOpenReportsTab(filter: ReportListFilter.dikirim),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CounselorStageCountCard(
                        title: 'Dibaca',
                        subtitle: 'Sedang ditinjau BK',
                        count: dibacaCount,
                        icon: Icons.visibility_outlined,
                        background: AppColors.tintSky,
                        accent: AppColors.skyText,
                        onTap: () =>
                            onOpenReportsTab(filter: ReportListFilter.dibaca),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CounselorStageCountCard(
                        title: 'Ditindak',
                        subtitle: 'Pendampingan berjalan',
                        count: ditindakCount,
                        icon: Icons.flag_outlined,
                        background: AppColors.amberTint,
                        accent: AppColors.amberText,
                        onTap: () =>
                            onOpenReportsTab(filter: ReportListFilter.ditindak),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CounselorStageCountCard(
                        title: 'Selesai',
                        subtitle: 'Penanganan tuntas',
                        count: selesaiCount,
                        icon: Icons.task_alt_rounded,
                        background: AppColors.tintMint,
                        accent: AppColors.mintText,
                        onTap: () =>
                            onOpenReportsTab(filter: ReportListFilter.selesai),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 4. Antrean Laporan Masuk Terbaru
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Antrean Laporan Masuk (${reports.length})',
                      style: AppTextStyles.heading2,
                    ),
                    GestureDetector(
                      onTap: () =>
                          onOpenReportsTab(filter: ReportListFilter.semua),
                      child: Text(
                        'Lihat semua',
                        style: AppTextStyles.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.biruTinta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (recentReports.isEmpty)
                  KtCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.tintIndigo,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.inbox_outlined,
                            color: AppColors.biruTinta,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum ada laporan masuk dari siswa',
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Laporan perundungan yang dikirim siswa akan langsung tampil di sini untuk diperbarui statusnya.',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final report in recentReports)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: KtCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReportDetailScreen(
                                reportCode: report.code,
                                asCounselor: true,
                              ),
                            ),
                          );
                          if (context.mounted) {
                            await ref
                                .read(myReportsControllerProvider.notifier)
                                .refresh();
                          }
                        },
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CodeHighlighter(
                                  code: report.code,
                                  fontSize: 12,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${DateFormatter.dayMonth(report.occurredAt)} · ${report.types.map((t) => t.label).join(', ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _statusPillFor(report.status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Lokasi: ${report.location}',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            StatusStepper(
                              currentStage: _stageFor(report.status),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (report.status == ReportStatus.diterima)
                                  TextButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(myReportsControllerProvider
                                              .notifier)
                                          .updateReportStatus(
                                            report.code,
                                            nextStatus: ReportStatus.ditinjau,
                                            note:
                                                'Guru BK telah membaca detail laporan dan mulai melakukan verifikasi awal.',
                                          );
                                    },
                                    icon: const Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Tandai Dibaca'),
                                  ),
                                const SizedBox(width: 6),
                                FilledButton.tonalIcon(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ReportDetailScreen(
                                          reportCode: report.code,
                                          asCounselor: true,
                                        ),
                                      ),
                                    );
                                    if (context.mounted) {
                                      await ref
                                          .read(myReportsControllerProvider
                                              .notifier)
                                          .refresh();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.rate_review_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Tinjau & Update Status'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 18),

                // 5. Kelola Artikel Edukasi & Ruang Baca
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kelola Artikel Edukasi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.articleCompose),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Tulis'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.biruTinta,
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenArticlesTab,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.biruTinta,
                      ),
                      child: const Text('Kelola semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                KtCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: Column(
                    children: [
                      for (var i = 0; i < previewArticles.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.borderHairline,
                          ),
                        ArticleFeedCard(
                          article: previewArticles[i],
                          compact: true,
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.articleDetail,
                            arguments: previewArticles[i].id,
                          ),
                          onCommentTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.articleDetail,
                            arguments: <String, dynamic>{
                              'articleId': previewArticles[i].id,
                              'scrollToComments': true,
                            },
                          ),
                          onClap: () => articlesNotifier
                              .clapArticle(previewArticles[i].id),
                          onBookmark: () => articlesNotifier
                              .toggleBookmark(previewArticles[i].id),
                          onEdit: () => Navigator.of(context).pushNamed(
                            AppRoutes.articleCompose,
                            arguments: previewArticles[i],
                          ),
                          onDelete: () => articlesNotifier
                              .deleteArticle(previewArticles[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CounselorStageCountCard extends StatelessWidget {
  const _CounselorStageCountCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.background,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color background;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KtCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count · $title',
                  style: AppTextStyles.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkNavy,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.inter(
                    fontSize: 11.5,
                    color: AppColors.inkSlate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BerandaTabView extends ConsumerWidget {
  const _BerandaTabView({
    required this.onOpenReportsTab,
    required this.onOpenCurhaiTab,
    required this.onOpenProfileTab,
  });

  final VoidCallback onOpenReportsTab;
  final VoidCallback onOpenCurhaiTab;
  final VoidCallback onOpenProfileTab;

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

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(studentProfileProvider);
    final reports =
        ref.watch(myReportsControllerProvider.select((s) => s.reports));
    final latestReport = reports.isNotEmpty ? reports.first : null;
    final articles =
        ref.watch(articlesControllerProvider.select((s) => s.articles));
    final articlesNotifier = ref.read(articlesControllerProvider.notifier);
    final previewArticles = articles.take(3).toList();

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
            final double innerWidth =
                constraints.maxWidth - (horizontalPadding * 2);
            final bool isWide = innerWidth >= 520;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                28,
              ),
              children: [
                // Top greeting bar (tapping monogram switches to Profil tab 3)
                Row(
                  children: [
                    GestureDetector(
                      onTap: onOpenProfileTab,
                      child: ProfileAvatarWidget(
                        profile: student,
                        size: 42,
                        borderRadius: 13,
                        respectDisguisedMode: true,
                        showShadow: !student.isDisguisedMode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.isDisguisedMode
                                ? 'Catatan Belajar Harian'
                                : _greetingForNow(),
                            style: AppTextStyles.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkSlate,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  student.shortName.isNotEmpty
                                      ? student.shortName
                                      : 'Pengguna',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.poppins(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkNavy,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (student.role.isStaff ||
                                  student.className.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !student.isDisguisedMode
                                        ? AppColors.tintIndigo
                                        : (student.role.isStaff
                                            ? AppColors.indigoSoft
                                            : AppColors.cardWhite),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !student.isDisguisedMode
                                          ? AppColors.biruTinta
                                              .withValues(alpha: 0.22)
                                          : (student.role.isStaff
                                              ? AppColors.biruTinta
                                                  .withValues(alpha: 0.25)
                                              : AppColors.borderHairline),
                                    ),
                                  ),
                                  child: Text(
                                    student.role.isStaff
                                        ? 'Guru BK'
                                        : student.className,
                                    style: AppTextStyles.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: (!student.isDisguisedMode ||
                                              student.role.isStaff)
                                          ? AppColors.biruTinta
                                          : AppColors.inkSlate,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (student.role.isStaff) ...[
                  const SizedBox(height: 14),
                  KtCard(
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRoutes.schoolSummary),
                    color: AppColors.tintIndigo,
                    borderColor: AppColors.biruTinta.withValues(alpha: 0.35),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.biruTinta,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Panel Guru BK & Insight AI',
                                    style: AppTextStyles.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.inkNavy,
                                    ),
                                  ),
                                  Text(
                                    'Tinjau laporan masuk siswa & ringkasan kondisi sekolah',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: AppColors.biruTinta,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            KtStatusPill.indigo(
                              'Dikirim: ${reports.where((r) => r.status == ReportStatus.diterima).length}',
                            ),
                            KtStatusPill.indigo(
                              'Dibaca: ${reports.where((r) => r.status == ReportStatus.ditinjau).length}',
                            ),
                            KtStatusPill.amber(
                              'Ditindak: ${reports.where((r) => r.status == ReportStatus.tindakLanjut).length}',
                            ),
                            KtStatusPill.mint(
                              'Selesai: ${reports.where((r) => r.status == ReportStatus.selesai).length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Primary Editorial Safe-Space Hero
                _ReportHeroBanner(
                  isDisguisedMode: student.isDisguisedMode,
                  isWide: isWide,
                  onCreateReport: () {
                    Navigator.of(context).pushNamed(AppRoutes.reportType);
                  },
                ),
                const SizedBox(height: 14),

                // Two quick action cards (Curhai & Kamera)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _QuickEntryCard(
                          leading: student.isDisguisedMode
                              ? null
                              : OwlMascot(
                                  mood: OwlMood.warm,
                                  size: 38,
                                  showContainer: true,
                                  backgroundColor: AppColors.tintMint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: AppColors.mintText,
                          iconBackground: AppColors.tintMint,
                          title: 'Curhai',
                          description:
                              'Cerita pelan-pelan, didengar tanpa dihakimi',
                          onTap: onOpenCurhaiTab,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickEntryCard(
                          icon: Icons.photo_camera_outlined,
                          iconColor: AppColors.amberText,
                          iconBackground: AppColors.amberTint,
                          title: 'Kamera',
                          description: 'Ambil foto bukti langsung dengan aman',
                          onTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.camera);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Section "Laporanmu"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(L10n.trackReportTitle, style: AppTextStyles.heading2),
                    GestureDetector(
                      onTap: onOpenReportsTab,
                      child: Text(
                        'Lihat semua',
                        style: AppTextStyles.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.biruTinta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (latestReport != null)
                  KtCard(
                    onTap: onOpenReportsTab,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${DateFormatter.dayMonth(latestReport.occurredAt)} · ${latestReport.types.map((t) => t.label).join(', ')}',
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            KtStatusPill.indigo(latestReport.status.label),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CodeHighlighter(
                          code: latestReport.code,
                          fontSize: 12.5,
                        ),
                        const SizedBox(height: 16),
                        StatusStepper(
                          currentStage: _stageFor(latestReport.status),
                        ),
                      ],
                    ),
                  )
                else
                  KtCard(
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.reportType),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        if (student.isDisguisedMode)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.indigoSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              color: AppColors.biruTinta,
                              size: 22,
                            ),
                          )
                        else
                          Container(
                            width: 72,
                            height: 58,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.tintIndigo,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const KitaIllustration(
                              scene: IllustrationScene.emptyReports,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum ada laporan',
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Laporan yang kamu kirim akan tampil dan bisa dipantau statusnya di sini.',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.inkSlate,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),

                // Section "Ruang Baca & Artikel" (Medium x X x Quora editorial preview stream)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ruang Baca & Artikel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading2,
                      ),
                    ),
                    if (student.role.isStaff)
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pushNamed(AppRoutes.articleCompose),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Tulis'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.biruTinta,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          textStyle: AppTextStyles.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.articles),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.biruTinta,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        textStyle: AppTextStyles.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Lihat semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                KtCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: Column(
                    children: [
                      for (var i = 0; i < previewArticles.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.borderHairline,
                          ),
                        ArticleFeedCard(
                          article: previewArticles[i],
                          compact: true,
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.articleDetail,
                            arguments: previewArticles[i].id,
                          ),
                          onCommentTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.articleDetail,
                            arguments: <String, dynamic>{
                              'articleId': previewArticles[i].id,
                              'scrollToComments': true,
                            },
                          ),
                          onClap: () => articlesNotifier
                              .clapArticle(previewArticles[i].id),
                          onBookmark: () => articlesNotifier
                              .toggleBookmark(previewArticles[i].id),
                        ),
                      ],
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.borderHairline,
                      ),
                      InkWell(
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.articles),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Jelajahi semua artikel & diskusi (${articles.length})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.biruTinta,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: AppColors.biruTinta,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportHeroBanner extends StatelessWidget {
  const _ReportHeroBanner({
    required this.isDisguisedMode,
    required this.isWide,
    required this.onCreateReport,
  });

  final bool isDisguisedMode;
  final bool isWide;
  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    final titleText = isDisguisedMode
        ? 'Catat progres belajarmu'
        : 'Ada yang perlu\ndilaporkan?';

    final Color surfaceBorder = isDisguisedMode
        ? AppColors.borderHairline
        : const Color(0xFFDCE2F5);

    final primaryAction = Material(
      color: isDisguisedMode ? AppColors.inkNavy : const Color(0xFF4E56E0),
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onCreateReport,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDisguisedMode
                    ? Icons.note_add_outlined
                    : Icons.edit_note_rounded,
                size: 19,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  L10n.quickReport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget? safeSpaceLabel = isDisguisedMode
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F7EF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: AppColors.mintText,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Privat & rahasia',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mintText,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          );

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDisguisedMode
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x121D224A),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDisguisedMode
                    ? const [
                        Color(0xFFF6F7FB),
                        Color(0xFFEEF0F7),
                      ]
                    : const [
                        Color(0xFFFFFFFF),
                        Color(0xFFF7F8FE),
                        Color(0xFFF1F9F5),
                      ],
              ),
              border: Border.all(
                color: surfaceBorder,
                width: 1.15,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: CustomPaint(
              painter: _HeroJoyfulPainter(isDisguisedMode: isDisguisedMode),
              child: Padding(
                padding: EdgeInsets.all(isWide ? 24 : 20),
                child: isWide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (safeSpaceLabel != null) ...[
                                        safeSpaceLabel,
                                        const SizedBox(height: 12),
                                      ],
                                      Text(
                                        titleText,
                                        style: AppTextStyles.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.inkNavy,
                                          height: 1.18,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        L10n.heroBannerBody,
                                        style: AppTextStyles.inter(
                                          fontSize: 13.5,
                                          color: const Color(0xFF555C80),
                                          height: 1.48,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  primaryAction,
                                ],
                              ),
                            ),
                            if (!isDisguisedMode) ...[
                              const SizedBox(width: 10),
                              const Center(
                                child: KitaIllustration(
                                  scene: IllustrationScene.heroBanner,
                                  width: 140,
                                  height: 112,
                                ),
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: Color(0xFFE4E8F5),
                              ),
                            ),
                            const Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _HeroGuaranteeItem(
                                    icon: Icons.verified_user_outlined,
                                    iconColor: AppColors.mintText,
                                    iconBackground: AppColors.tintMint,
                                    title: 'Hanya ke Guru BK',
                                    subtitle: 'Tidak tampil ke siswa lain',
                                  ),
                                  SizedBox(height: 14),
                                  _HeroGuaranteeItem(
                                    icon: Icons.photo_filter_outlined,
                                    iconColor: AppColors.biruTinta,
                                    iconBackground: AppColors.tintIndigo,
                                    title: 'Bukti dibersihkan',
                                    subtitle: 'Metadata lokasi foto dihapus',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, box) {
                          final double artWidth = box.maxWidth < 310
                              ? 104
                              : (box.maxWidth < 360 ? 124 : 142);
                          final double artHeight = artWidth * 0.80;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (safeSpaceLabel != null) ...[
                                          safeSpaceLabel,
                                          const SizedBox(height: 10),
                                        ],
                                        Text(
                                          titleText,
                                          style: AppTextStyles.poppins(
                                            fontSize: 21.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.inkNavy,
                                            height: 1.18,
                                            letterSpacing: -0.45,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          L10n.heroBannerBody,
                                          style: AppTextStyles.inter(
                                            fontSize: 13,
                                            color: const Color(0xFF555C80),
                                            height: 1.48,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isDisguisedMode) ...[
                                    const SizedBox(width: 8),
                                    KitaIllustration(
                                      scene: IllustrationScene.heroBanner,
                                      width: artWidth,
                                      height: artHeight,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              primaryAction,
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGuaranteeItem extends StatelessWidget {
  const _HeroGuaranteeItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkNavy,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.inter(
                  fontSize: 11.5,
                  color: const Color(0xFF5D6487),
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

class _HeroJoyfulPainter extends CustomPainter {
  const _HeroJoyfulPainter({required this.isDisguisedMode});

  final bool isDisguisedMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (isDisguisedMode) return;

    // Gentle sunlit botanical curve anchored quietly under the illustration side
    final softHillPath = Path()
      ..moveTo(size.width * 0.48, size.height)
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.62,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..close();

    final hillPaint = Paint()
      ..color = const Color(0xFFDDF3E8).withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    canvas.drawPath(softHillPath, hillPaint);

    // Subtle warm sunlit corner glow behind the tree foliage
    final warmWashPaint = Paint()
      ..color = const Color(0xFFFFF2CC).withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.88, size.height * 0.22),
        width: size.width * 0.38,
        height: size.height * 0.72,
      ),
      warmWashPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroJoyfulPainter oldDelegate) =>
      oldDelegate.isDisguisedMode != isDisguisedMode;
}

class _QuickEntryCard extends StatelessWidget {
  const _QuickEntryCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.onTap,
    this.leading,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.borderHairline,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  leading ??
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 19,
                        ),
                      ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkNavy,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: AppTextStyles.inter(
                  fontSize: 12.5,
                  color: AppColors.inkSlate,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
