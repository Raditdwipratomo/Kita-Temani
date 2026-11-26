import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/permission_service.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';

class AppPermissionsScreen extends ConsumerStatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  ConsumerState<AppPermissionsScreen> createState() =>
      _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends ConsumerState<AppPermissionsScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _isRequestingAll = false;
  AppPermission? _requestingPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _refresh(showSpinner: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(showSpinner: false));
    }
  }

  Future<void> _refresh({bool showSpinner = true}) async {
    if (!mounted) return;
    if (showSpinner) {
      setState(() => _isChecking = true);
    }
    try {
      await ref.read(permissionsControllerProvider.notifier).refresh();
    } finally {
      if (mounted && showSpinner) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handlePermissionAction(
    AppPermission permission,
    AppPermissionState currentState,
  ) async {
    if (_requestingPermission != null || _isRequestingAll) return;

    if (currentState == AppPermissionState.mobileOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin ini hanya dipakai di Android/iOS. Di browser web, KitaTemani menggunakan WhatsApp & tautan telepon.',
          ),
        ),
      );
      return;
    }

    if (currentState == AppPermissionState.permanentlyDenied && !kIsWeb) {
      await ref
          .read(permissionsControllerProvider.notifier)
          .openSystemSettings();
      return;
    }

    setState(() => _requestingPermission = permission);
    AppPermissionState nextState;
    try {
      nextState = await ref
          .read(permissionsControllerProvider.notifier)
          .requestOne(permission);
    } finally {
      if (mounted) {
        setState(() => _requestingPermission = null);
      }
    }
    if (!mounted) return;

    final feedback = switch (nextState) {
      AppPermissionState.granted => '${permission.label} sudah aktif.',
      AppPermissionState.permanentlyDenied => kIsWeb
          ? 'Browser memblokir ${permission.label}. Ubah izin di ikon pengaturan situs pada address bar — status akan otomatis diperbarui.'
          : '${permission.label} ditolak permanen. Buka Pengaturan HP untuk mengaktifkannya.',
      AppPermissionState.denied =>
        '${permission.label} belum diizinkan. Coba ketuk Izinkan lagi saat siap.',
      AppPermissionState.mobileOnly =>
        'Izin ini hanya berlaku di aplikasi seluler.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(feedback)),
    );
  }

  Future<void> _requestAll() async {
    if (_isRequestingAll || _requestingPermission != null) return;
    setState(() => _isRequestingAll = true);
    try {
      await ref.read(permissionsControllerProvider.notifier).requestAllNeeded();
    } finally {
      if (mounted) {
        setState(() => _isRequestingAll = false);
      }
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status izin perangkat telah diperbarui.'),
      ),
    );
  }

  void _goBackToProfile() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    unawaited(
      ref.read(studentProfileProvider.notifier).restoreSessionIfAuthenticated(),
    );
    unawaited(
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
        arguments: 3,
      ),
    );
  }

  IconData _iconFor(AppPermission permission) {
    return switch (permission) {
      AppPermission.camera => Icons.camera_alt_outlined,
      AppPermission.location => Icons.location_on_outlined,
      AppPermission.microphone => Icons.mic_none_rounded,
      AppPermission.sms => Icons.sms_outlined,
      AppPermission.phone => Icons.phone_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(permissionsControllerProvider);

    final applicable = AppPermission.values
        .where((p) => statuses[p] != AppPermissionState.mobileOnly)
        .toList();
    final grantedCount = applicable
        .where((p) => statuses[p] == AppPermissionState.granted)
        .length;
    final allReady = applicable.isNotEmpty && grantedCount == applicable.length;

    const evidencePermissions = [
      AppPermission.camera,
      AppPermission.microphone,
    ];
    const emergencyPermissions = [
      AppPermission.location,
      AppPermission.sms,
      AppPermission.phone,
    ];

    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBackToProfile();
        }
      },
      child: Scaffold(
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
                          title: 'Izin Aplikasi',
                          onBack: _goBackToProfile,
                          trailing: IconButton(
                            tooltip: 'Periksa ulang status izin',
                            onPressed: _isChecking ? null : _refresh,
                            icon: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.biruTinta,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.biruTinta,
                                  ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            children: [
                              // Readiness summary focal card
                              KtCard(
                                color: allReady
                                    ? AppColors.tintMint
                                    : AppColors.tintIndigo,
                                borderColor: allReady
                                    ? AppColors.hijau.withValues(alpha: 0.3)
                                    : AppColors.biruTinta
                                        .withValues(alpha: 0.25),
                                borderRadius: 20,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: allReady
                                                ? AppColors.hijau
                                                    .withValues(alpha: 0.14)
                                                : AppColors.indigoSoft,
                                            borderRadius:
                                                BorderRadius.circular(13),
                                          ),
                                          child: Icon(
                                            allReady
                                                ? Icons.verified_user_rounded
                                                : Icons.shield_outlined,
                                            color: allReady
                                                ? AppColors.hijau
                                                : AppColors.biruTinta,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$grantedCount dari ${applicable.length} izin aktif',
                                                style: AppTextStyles.heading2
                                                    .copyWith(
                                                  fontFeatures: const [
                                                    FontFeature
                                                        .tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                allReady
                                                    ? 'Semua izin utama siap untuk kamera bukti & Tombol Darurat.'
                                                    : 'Aktifkan izin yang diperlukan agar kamera dan Tombol Darurat berjalan cepat.',
                                                style: AppTextStyles.bodySmall
                                                    .copyWith(
                                                  color: AppColors.inkNavy,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: allReady
                                                          ? AppColors.hijau
                                                          : AppColors.biruTinta,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      kIsWeb
                                                          ? 'Sinkron otomatis dengan izin browser'
                                                          : 'Sinkron otomatis dengan izin perangkat',
                                                      style:
                                                          AppTextStyles.inter(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: allReady
                                                            ? AppColors.mintText
                                                            : AppColors
                                                                .inkSlate,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (!allReady) ...[
                                      const SizedBox(height: 12),
                                      AppButton(
                                        label: _isRequestingAll
                                            ? 'Meminta izin…'
                                            : 'Aktifkan semua izin penting',
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        isLoading: _isRequestingAll,
                                        onPressed: _requestAll,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              Text(
                                'Kamera & dokumentasi bukti',
                                style: AppTextStyles.heading3.copyWith(
                                  color: AppColors.inkNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dipakai hanya saat kamu membuka fitur Kamera atau melampirkan bukti.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              for (final perm in evidencePermissions) ...[
                                _PermissionStatusCard(
                                  icon: _iconFor(perm),
                                  permission: perm,
                                  state: statuses[perm] ??
                                      AppPermissionState.denied,
                                  isRequesting: _requestingPermission == perm,
                                  onAction: () => _handlePermissionAction(
                                    perm,
                                    statuses[perm] ?? AppPermissionState.denied,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              const SizedBox(height: 12),
                              Text(
                                'Perlindungan Tombol Darurat',
                                style: AppTextStyles.heading3.copyWith(
                                  color: AppColors.inkNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aktif hanya ketika kamu menahan Tombol Darurat 2 detik.',
                                style: AppTextStyles.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              for (final perm in emergencyPermissions) ...[
                                _PermissionStatusCard(
                                  icon: _iconFor(perm),
                                  permission: perm,
                                  state: statuses[perm] ??
                                      AppPermissionState.denied,
                                  isRequesting: _requestingPermission == perm,
                                  onAction: () => _handlePermissionAction(
                                    perm,
                                    statuses[perm] ?? AppPermissionState.denied,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              const SizedBox(height: 8),
                              const KtInfoBanner(
                                icon: Icons.lock_outline_rounded,
                                message:
                                    'Privasi terjaga: KitaTemani tidak melacak lokasi, kamera, atau mikrofon di latar belakang.',
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
                        label: 'Kembali ke Profil',
                        isOutlined: true,
                        onPressed: _goBackToProfile,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStatusCard extends StatelessWidget {
  const _PermissionStatusCard({
    required this.icon,
    required this.permission,
    required this.state,
    required this.isRequesting,
    required this.onAction,
  });

  final IconData icon;
  final AppPermission permission;
  final AppPermissionState state;
  final bool isRequesting;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isGranted = state == AppPermissionState.granted;
    final isMobileOnly = state == AppPermissionState.mobileOnly;
    final isBlocked = state == AppPermissionState.permanentlyDenied;

    final statusPill = switch (state) {
      AppPermissionState.granted => KtStatusPill.mint(
          'Aktif',
          icon: Icons.check_circle_rounded,
        ),
      AppPermissionState.mobileOnly => KtStatusPill.indigo('Khusus HP'),
      AppPermissionState.permanentlyDenied => KtStatusPill.sos('Diblokir'),
      AppPermissionState.denied => KtStatusPill.amber('Belum aktif'),
    };

    return KtCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGranted ? AppColors.tintMint : AppColors.tintIndigo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isGranted ? AppColors.hijau : AppColors.biruTinta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        permission.label,
                        style: AppTextStyles.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    statusPill,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isMobileOnly
                      ? 'Tersedia di aplikasi Android/iOS. Di web gunakan WhatsApp & tautan telepon.'
                      : permission.description,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                ),
                if (!isGranted && !isMobileOnly) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: isRequesting ? null : onAction,
                      icon: isRequesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isBlocked && !kIsWeb
                                  ? Icons.settings_outlined
                                  : Icons.verified_user_outlined,
                              size: 16,
                            ),
                      label: Text(
                        isRequesting
                            ? 'Meminta…'
                            : (isBlocked && !kIsWeb
                                ? 'Buka pengaturan'
                                : 'Izinkan'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.biruTinta,
                        backgroundColor: AppColors.tintIndigo,
                        side: BorderSide(
                          color: AppColors.biruTinta.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        shape: const StadiumBorder(),
                        textStyle: AppTextStyles.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
