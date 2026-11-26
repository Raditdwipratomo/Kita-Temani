import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/permission_service.dart';
import 'package:kitatemani/core/utils/phone_number.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';
import 'package:kitatemani/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:kitatemani/features/report/data/repositories/report_repository_impl.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    this.isTabView = false,
    super.key,
  });

  final bool isTabView;

  void _showHelpCenterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text('Pusat Bantuan & Konseling', style: AppTextStyles.heading2),
            const SizedBox(height: 12),
            const KtInfoBanner(
              title: 'Layanan SAPA 129 (KemenPPPA)',
              icon: Icons.support_agent_rounded,
              message:
                  'Hotline perlindungan anak & remaja: 129 atau WhatsApp 08111-129-129 (24 jam).',
            ),
            const SizedBox(height: 10),
            const KtInfoBanner(
              title: 'Kerahasiaan & Privasi',
              icon: Icons.lock_outline_rounded,
              message:
                  'Laporan hanya dapat diakses oleh dirimu dan Guru BK sekolah yang berwenang. Obrolan CurhAI hanya tersimpan di perangkatmu.',
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Tutup',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Text('Keluar dari akun?', style: AppTextStyles.heading2),
        content: Text(
          'Kode laporan lokal di HP ini akan dihapus saat keluar. Pastikan kamu sudah mencatat nomor tiket penting.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darurat,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: const Text('Keluar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSlate,
                    minimumSize: const Size(double.infinity, 42),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final repo = ref.read(reportRepositoryProvider);
    if (repo is ReportRepositoryImpl) {
      await repo.clearLocalCache();
    }
    await ref.read(studentProfileProvider.notifier).signOut();
    if (!context.mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.schoolLogin,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(studentProfileProvider);
    final contacts = ref.watch(emergencyContactsControllerProvider);
    final reports =
        ref.watch(myReportsControllerProvider.select((s) => s.reports));
    final permStates = ref.watch(permissionsControllerProvider);
    final activeCount = contacts.where((c) => c.isActive).length;
    final applicablePerms = AppPermission.values
        .where((p) => permStates[p] != AppPermissionState.mobileOnly)
        .toList();
    final grantedPermsCount = applicablePerms
        .where((p) => permStates[p] == AppPermissionState.granted)
        .length;
    final permissionsReady = applicablePerms.isNotEmpty &&
        grantedPermsCount == applicablePerms.length;

    final readinessChecks = [
      permissionsReady,
      activeCount > 0,
      student.schoolName.trim().isNotEmpty,
    ];
    final readyCount = readinessChecks.where((ok) => ok).length;
    final allReady = readyCount == readinessChecks.length;

    final completenessPercent = student.profileCompletenessPercent;
    final formattedPhone = student.phoneNumber.trim().isNotEmpty
        ? PhoneNumber.formatDisplay(student.phoneNumber)
        : '';

    final metricItems = student.role.isStaff
        ? <_MetricEntry>[
            _MetricEntry(
              value: '${reports.length}',
              label: 'Laporan Masuk',
              icon: Icons.assignment_outlined,
              iconColor: AppColors.biruTinta,
            ),
            _MetricEntry(
              value:
                  '${reports.where((r) => r.status != ReportStatus.selesai).length}',
              label: 'Perlu Tindakan',
              icon: Icons.pending_actions_rounded,
              iconColor: AppColors.amberText,
            ),
            _MetricEntry(
              value:
                  '${reports.where((r) => r.status == ReportStatus.selesai).length}',
              label: 'Selesai',
              icon: Icons.task_alt_rounded,
              iconColor: AppColors.mintText,
            ),
          ]
        : <_MetricEntry>[
            _MetricEntry(
              value: '${reports.length}',
              label: 'Laporan',
              icon: Icons.description_outlined,
              iconColor: AppColors.biruTinta,
            ),
            _MetricEntry(
              value:
                  '${reports.where((r) => r.status == ReportStatus.selesai).length}',
              label: 'Selesai',
              icon: Icons.task_alt_rounded,
              iconColor: AppColors.mintText,
            ),
            _MetricEntry(
              value: '$activeCount',
              label: 'Kontak Aktif',
              icon: Icons.shield_outlined,
              iconColor: AppColors.biruTinta,
            ),
          ];

    final menuRows = <_GroupedMenuItemData>[
      if (!student.role.isStaff) ...[
        _GroupedMenuItemData(
          icon: Icons.contact_phone_outlined,
          iconColor: AppColors.biruTinta,
          iconBackground: AppColors.tintIndigo,
          title: 'Kontak darurat',
          subtitle: 'Penerima WhatsApp darurat (${contacts.length} kontak)',
          trailing: _QuietCountBadge(
            label: '${contacts.length}',
            background: AppColors.tintIndigo,
            foreground: AppColors.biruTinta,
          ),
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.emergencyContacts),
        ),
        _GroupedMenuItemData(
          icon: Icons.security_rounded,
          iconColor: permissionsReady ? AppColors.mintText : AppColors.amberText,
          iconBackground:
              permissionsReady ? AppColors.tintMint : AppColors.amberTint,
          title: 'Izin Aplikasi',
          subtitle: 'Kamera, Lokasi GPS, Mikrofon, & SMS darurat',
          trailing: _QuietCountBadge(
            label: permissionsReady
                ? 'Siap'
                : '$grantedPermsCount/${applicablePerms.length}',
            background:
                permissionsReady ? AppColors.tintMint : AppColors.amberTint,
            foreground:
                permissionsReady ? AppColors.mintText : AppColors.amberText,
          ),
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.appPermissions),
        ),
      ],
      if (student.role.isStaff) ...[
        _GroupedMenuItemData(
          icon: Icons.admin_panel_settings_outlined,
          iconColor: AppColors.biruTinta,
          iconBackground: AppColors.tintIndigo,
          title: 'Panel Guru BK & Insight AI',
          subtitle: 'Tinjau laporan masuk & ringkasan kondisi sekolah',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.schoolSummary),
        ),
        _GroupedMenuItemData(
          icon: Icons.menu_book_outlined,
          iconColor: AppColors.mintText,
          iconBackground: AppColors.tintMint,
          title: 'Kelola Ruang Baca & Artikel',
          subtitle: 'Buat, edit, atau hapus artikel edukasi untuk siswa',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.articles),
        ),
        _GroupedMenuItemData(
          icon: Icons.edit_note_rounded,
          iconColor: AppColors.skyText,
          iconBackground: AppColors.tintSky,
          title: 'Tulis Artikel Edukasi Baru',
          subtitle: 'Publikasikan panduan konseling resmi Guru BK',
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.articleCompose),
        ),
      ],
      _GroupedMenuItemData(
        icon: Icons.help_outline_rounded,
        iconColor: const Color(0xFF555C80),
        iconBackground: const Color(0xFFF1F3FA),
        title: 'Pusat bantuan',
        subtitle: 'Panduan keselamatan, FAQ & hotline SAPA 129',
        onTap: () => _showHelpCenterSheet(context),
      ),
    ];

    final editActionButton = Tooltip(
      message: 'Ubah profil',
      child: Material(
        color: AppColors.cardWhite,
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.borderHairline.withValues(alpha: 0.9),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.editProfile),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.edit_outlined,
              size: 19,
              color: AppColors.inkNavy,
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                if (isTabView)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: Row(
                      children: [
                        Text('Profil saya', style: AppTextStyles.heading1),
                        const Spacer(),
                        editActionButton,
                      ],
                    ),
                  )
                else
                  KtPageHeader(
                    title: 'Profil saya',
                    trailing: editActionButton,
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                    children: [
                      // 1. Editorial Identity Header Card (Dribbble Wellness x Figma Untitled UI)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFE5E9F6),
                            width: 1.1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0B1D224A),
                              blurRadius: 16,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => Navigator.of(context)
                                .pushNamed(AppRoutes.editProfile),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Editorial horizontal split: framed avatar + structured identity
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F5FE),
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: const Color(0xFFE0E5F8),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: ProfileAvatarWidget(
                                              profile: student,
                                              size: 58,
                                              borderRadius: 18,
                                            ),
                                          ),
                                          Positioned(
                                            right: -3,
                                            bottom: -3,
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: AppColors.biruTinta,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.cardWhite,
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.edit_rounded,
                                                size: 11.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name.isNotEmpty
                                                  ? student.name
                                                  : 'Belum diisi',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.poppins(
                                                fontSize: 17.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.inkNavy,
                                                letterSpacing: -0.25,
                                              ),
                                            ),
                                            const SizedBox(height: 5),

                                            // Calm Metadata Chips (restrained 2-tone palette)
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 5,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 9,
                                                    vertical: 3.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFECF8F2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            99),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.verified_rounded,
                                                        size: 13,
                                                        color:
                                                            AppColors.mintText,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          student
                                                              .schoolBadgeLabel,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: AppTextStyles
                                                              .inter(
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .mintText,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (student.educationLevelLabel
                                                    .isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 9,
                                                      vertical: 3.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF2F4FA),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              99),
                                                    ),
                                                    child: Text(
                                                      student
                                                          .educationLevelLabel,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          AppTextStyles.inter(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                            0xFF4B5278),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),

                                            // Quiet contact info (email & phone)
                                            if (student.email
                                                    .trim()
                                                    .isNotEmpty ||
                                                formattedPhone.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                spacing: 10,
                                                runSpacing: 3,
                                                children: [
                                                  if (student.email
                                                      .trim()
                                                      .isNotEmpty)
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const GoogleLogoMark(
                                                            size: 12.5),
                                                        const SizedBox(
                                                            width: 4),
                                                        Flexible(
                                                          child: Text(
                                                            student.email,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: AppTextStyles
                                                                .inter(
                                                              fontSize: 11.5,
                                                              color: AppColors
                                                                  .inkSlate,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  if (formattedPhone.isNotEmpty)
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.phone_outlined,
                                                          size: 13,
                                                          color: AppColors
                                                              .inkSlate,
                                                        ),
                                                        const SizedBox(
                                                            width: 3),
                                                        Flexible(
                                                          child: Text(
                                                            formattedPhone,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: AppTextStyles
                                                                .inter(
                                                              fontSize: 11.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  const Color(
                                                                0xFF4B5278,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Subtle inline Profile Completeness Bar (only when < 100%)
                                  if (completenessPercent < 100) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Text(
                                          'Kelengkapan profil',
                                          style: AppTextStyles.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.inkSlate,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(99),
                                            child: LinearProgressIndicator(
                                              value: completenessPercent / 100,
                                              minHeight: 4.5,
                                              backgroundColor:
                                                  const Color(0xFFE8ECF7),
                                              color: AppColors.biruTinta,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$completenessPercent%',
                                          style: AppTextStyles.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.biruTinta,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 15,
                                          color: AppColors.biruTinta,
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  // Unified Neutral Metric Strip (replaces rainbow pastel boxes)
                                  _ProfileMetricStrip(items: metricItems),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. Refined Emergency Readiness Card (3-segment visual progress)
                      if (!student.role.isStaff) ...[
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                          decoration: BoxDecoration(
                            color: AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE5E9F6),
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: allReady
                                          ? AppColors.tintMint
                                          : AppColors.amberTint,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      allReady
                                          ? Icons.verified_user_rounded
                                          : Icons.shield_outlined,
                                      size: 14.5,
                                      color: allReady
                                          ? AppColors.mintText
                                          : AppColors.amberText,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Kesiapan darurat',
                                      style: AppTextStyles.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.inkNavy,
                                      ),
                                    ),
                                  ),
                                  _QuietCountBadge(
                                    label:
                                        '$readyCount dari ${readinessChecks.length} siap',
                                    background: allReady
                                        ? AppColors.tintMint
                                        : AppColors.amberTint,
                                    foreground: allReady
                                        ? AppColors.mintText
                                        : AppColors.amberText,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),

                              // 3-segment calm readiness bar
                              Row(
                                children: [
                                  for (var i = 0;
                                      i < readinessChecks.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(width: 6),
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: i < readyCount
                                              ? AppColors.hijau
                                              : const Color(0xFFE8ECF7),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),

                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => Navigator.of(context)
                                    .pushNamed(AppRoutes.appPermissions),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 1.5),
                                  child: _ReadinessCheckRow(
                                    isDone: permissionsReady,
                                    showChevron: !permissionsReady,
                                    label: permissionsReady
                                        ? 'Izin kamera, lokasi & mikrofon aktif ($grantedPermsCount/${applicablePerms.length})'
                                        : 'Izin aplikasi: $grantedPermsCount/${applicablePerms.length} aktif · ketuk untuk atur',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _ReadinessCheckRow(
                                isDone: activeCount > 0,
                                label: activeCount > 0
                                    ? '$activeCount kontak aktif + ${student.counselorName.split(',').first} siap'
                                    : 'Belum ada kontak keluarga aktif · ${student.counselorName.split(',').first} siap',
                              ),
                              const SizedBox(height: 4),
                              _ReadinessCheckRow(
                                isDone: student.schoolName.trim().isNotEmpty,
                                label: student.schoolName.trim().isNotEmpty
                                    ? 'Terhubung ke ${student.schoolName}'
                                    : 'Nama sekolah belum dilengkapi',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 3. Grouped Settings List (Apple HIG / Figma Community Untitled UI)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          student.role.isStaff
                              ? 'Menu konselor & admin'
                              : 'Keamanan & bantuan',
                          style: AppTextStyles.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF555C80),
                          ),
                        ),
                      ),
                      _GroupedMenuCard(items: menuRows),
                      const SizedBox(height: 14),

                      // 4. Restrained Sign-Out Action Tile
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFF2DADF),
                            width: 1.1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            splashColor:
                                AppColors.darurat.withValues(alpha: 0.08),
                            onTap: () => _confirmSignOut(context, ref),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                    color: AppColors.crimsonContrast,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Keluar dari akun',
                                    style: AppTextStyles.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.crimsonContrast,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Kode laporan lokal di perangkat ikut terhapus saat keluar. Catat dulu kodenya.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.inter(
                            fontSize: 11.5,
                            color: AppColors.inkSlate,
                            height: 1.45,
                          ),
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
    );
  }
}

class _MetricEntry {
  const _MetricEntry({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
}

class _ProfileMetricStrip extends StatelessWidget {
  const _ProfileMetricStrip({required this.items});

  final List<_MetricEntry> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE8ECF7),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  indent: 4,
                  endIndent: 4,
                  color: Color(0xFFE1E6F3),
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 14,
                          color: items[i].iconColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            items[i].value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuietCountBadge extends StatelessWidget {
  const _QuietCountBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: AppTextStyles.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _ReadinessCheckRow extends StatelessWidget {
  const _ReadinessCheckRow({
    required this.label,
    this.isDone = true,
    this.showChevron = false,
  });

  final String label;
  final bool isDone;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          size: 16.5,
          color: isDone ? AppColors.hijau : AppColors.amberText,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.inter(
              fontSize: 12.5,
              fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
              color: isDone ? AppColors.inkNavy : AppColors.amberText,
              height: 1.35,
            ),
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: AppColors.amberText,
          ),
        ],
      ],
    );
  }
}

class _GroupedMenuItemData {
  const _GroupedMenuItemData({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
}

class _GroupedMenuCard extends StatelessWidget {
  const _GroupedMenuCard({required this.items});

  final List<_GroupedMenuItemData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5E9F6),
          width: 1.1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 64,
                  endIndent: 16,
                  color: Color(0xFFEDF0F8),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: items[i].onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: items[i].iconBackground,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            items[i].icon,
                            size: 19,
                            color: items[i].iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].title,
                                style: AppTextStyles.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkNavy,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                items[i].subtitle,
                                style: AppTextStyles.inter(
                                  fontSize: 12,
                                  color: AppColors.inkSlate,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (items[i].trailing != null) ...[
                          const SizedBox(width: 8),
                          items[i].trailing!,
                        ],
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: Color(0xFF9AA1BE),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
