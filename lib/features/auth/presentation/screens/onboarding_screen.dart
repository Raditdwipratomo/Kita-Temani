import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/permission_service.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/l10n/l10n.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  Map<AppPermission, bool> _permissions = {
    AppPermission.sms: true,
    AppPermission.location: true,
    AppPermission.microphone: true,
    AppPermission.phone: true,
  };

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (_pageIndex < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await ref.read(permissionServiceProvider).requestEmergencyBundle();
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(AppRoutes.schoolLogin);
  }

  void _onSkip() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.schoolLogin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              // Top bar: pill step indicator & Lewati
              Row(
                children: [
                  Row(
                    children: List.generate(3, (i) {
                      final active = i == _pageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 24 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.biruTinta
                              : AppColors.borderHairline,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkSlate,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      L10n.btnSkip,
                      style: AppTextStyles.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSlate,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _pageIndex = idx),
                  children: [
                    const _SlideJanji(),
                    const _SlideCaraKerja(),
                    _SlideIzin(
                      permissions: _permissions,
                      onTogglePermission: (perm, val) {
                        setState(() {
                          _permissions = {..._permissions, perm: val};
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: _pageIndex == 2 ? L10n.btnStart : L10n.btnNext,
                trailingIcon: _pageIndex == 2
                    ? Icons.arrow_forward_rounded
                    : Icons.chevron_right_rounded,
                onPressed: _onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideJanji extends StatelessWidget {
  const _SlideJanji();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soft illustrated hero panel
          KtCard(
            color: AppColors.tintIndigo,
            borderColor: AppColors.indigoSoft,
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                const OwlMascot(
                  mood: OwlMood.reassuring,
                  size: 72,
                  backgroundColor: Color(0xFFE3E7FF),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KtStatusPill.indigo(
                        'KITA TEMANI',
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Laporanmu dijaga privat & aman di sekolah.',
                        style: AppTextStyles.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkNavy,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            L10n.onboardingTitle1,
            style: AppTextStyles.displayLarge.copyWith(fontSize: 25),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.onboardingBody1,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 18),
          const _FeatureTile(
            icon: Icons.lock_outline_rounded,
            iconBg: AppColors.indigoSoft,
            iconColor: AppColors.biruTinta,
            title: 'Privat & rahasia',
            description:
                'Identitas dan isi laporanmu hanya dibaca oleh Guru BK sekolah, tidak pernah dibuka ke siswa lain.',
          ),
          const SizedBox(height: 10),
          const _FeatureTile(
            icon: Icons.school_outlined,
            iconBg: AppColors.tintMint,
            iconColor: AppColors.hijau,
            title: 'Langsung ditinjau Guru BK',
            description:
                'Laporan terhubung langsung dengan ruang BK dan bisa kamu pantau langkah demi langkah.',
          ),
          const SizedBox(height: 10),
          const _FeatureTile(
            icon: Icons.emergency_share_outlined,
            iconBg: AppColors.sosSoft,
            iconColor: AppColors.darurat,
            title: 'Tombol Darurat siap menjaga',
            description:
                'Tahan 2 detik saat situasi genting untuk mengirim peringatan lokasi ke keluarga & Guru BK.',
          ),
        ],
      ),
    );
  }
}

class _SlideCaraKerja extends StatelessWidget {
  const _SlideCaraKerja();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KtCard(
            color: AppColors.tintIndigo,
            borderColor: AppColors.indigoSoft,
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                const OwlMascot(
                  mood: OwlMood.warm,
                  size: 68,
                  backgroundColor: Color(0xFFE3E7FF),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KtStatusPill.mint(
                        'ALUR AMAN · 3 LANGKAH',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bisa curhat dulu ke Curhai atau kirim bukti aman ke BK.',
                        style: AppTextStyles.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkNavy,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            L10n.onboardingTitle2,
            style: AppTextStyles.displayLarge.copyWith(fontSize: 25),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.onboardingBody2,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 18),
          const _StepNumberCard(
            step: '1',
            badgeBg: AppColors.indigoSoft,
            badgeColor: AppColors.biruTinta,
            title: 'Ceritakan kejadian & lampirkan bukti',
            description:
                'Pilih jenis bullying, tanggal kejadian, cerita, foto kamera, file, atau link bukti dengan EXIF otomatis dibersihkan.',
          ),
          const SizedBox(height: 10),
          _StepNumberCard(
            step: '2',
            badgeBg: AppColors.amberTint,
            badgeColor: AppColors.amberText,
            title: 'Terima Nomor Tiket Laporan',
            descriptionWidget: RichText(
              text: TextSpan(
                style: AppTextStyles.inter(
                  fontSize: 12.5,
                  color: AppColors.inkSlate,
                  height: 1.42,
                ),
                children: [
                  const TextSpan(text: 'Laporanmu mendapat tiket '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.indigoSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'KT-XXXX-XXXX',
                        style: AppTextStyles.code(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.biruTinta,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(
                    text: ' dan tersimpan aman di akunmu.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _StepNumberCard(
            step: '3',
            badgeBg: AppColors.tintMint,
            badgeColor: AppColors.mintText,
            title: 'Guru BK menindaklanjuti secara privat',
            description:
                'Pantau perkembangan status laporanmu langkah demi langkah tanpa membuka identitas ke siswa lain.',
          ),
        ],
      ),
    );
  }
}

class _SlideIzin extends StatelessWidget {
  const _SlideIzin({
    required this.permissions,
    required this.onTogglePermission,
  });

  final Map<AppPermission, bool> permissions;
  final void Function(AppPermission, bool) onTogglePermission;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KtStatusPill.sos(
            'KESELAMATAN & PRIVASI',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            L10n.onboardingTitle3,
            style: AppTextStyles.displayLarge.copyWith(fontSize: 25),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.onboardingBody3,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          _PermissionToggleCard(
            icon: Icons.sms_outlined,
            title: 'Kirim SMS Darurat',
            subtitle:
                'Mengirim peringatan & link lokasi ke orang tua serta Guru BK saat darurat.',
            value: permissions[AppPermission.sms] ?? false,
            onChanged: (v) => onTogglePermission(AppPermission.sms, v),
          ),
          const SizedBox(height: 10),
          _PermissionToggleCard(
            icon: Icons.location_on_outlined,
            title: 'Lokasi Presisi',
            subtitle:
                'Menyertakan koordinat titik aman hanya saat Tombol Darurat ditahan.',
            value: permissions[AppPermission.location] ?? false,
            onChanged: (v) => onTogglePermission(AppPermission.location, v),
          ),
          const SizedBox(height: 10),
          _PermissionToggleCard(
            icon: Icons.mic_none_rounded,
            title: 'Rekaman Audio Cadangan',
            subtitle:
                'Merekam suara otomatis terenkripsi ke ruang laporan darurat saat SOS ditahan.',
            value: permissions[AppPermission.microphone] ?? false,
            onChanged: (v) => onTogglePermission(AppPermission.microphone, v),
          ),
          const SizedBox(height: 10),
          _PermissionToggleCard(
            icon: Icons.contacts_outlined,
            title: 'Pilih Kontak Darurat',
            subtitle:
                'Memudahkan memilih kontak orang tua atau wali dari daftar teleponmu.',
            value: permissions[AppPermission.phone] ?? false,
            onChanged: (v) => onTogglePermission(AppPermission.phone, v),
          ),
          const SizedBox(height: 14),
          const KtInfoBanner(
            icon: Icons.lock_outline_rounded,
            message:
                'Privasi dijamin: Lokasi & mikrofon HANYA aktif ketika kamu menahan Tombol Darurat 2 detik. Tidak pernah melacak di latar belakang.',
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
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
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkNavy,
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
        ],
      ),
    );
  }
}

class _StepNumberCard extends StatelessWidget {
  const _StepNumberCard({
    required this.step,
    required this.badgeBg,
    required this.badgeColor,
    required this.title,
    this.description,
    this.descriptionWidget,
  });

  final String step;
  final Color badgeBg;
  final Color badgeColor;
  final String title;
  final String? description;
  final Widget? descriptionWidget;

  @override
  Widget build(BuildContext context) {
    return KtCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                step,
                style: AppTextStyles.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkNavy,
                  ),
                ),
                const SizedBox(height: 3),
                if (descriptionWidget != null)
                  descriptionWidget!
                else if (description != null)
                  Text(
                    description!,
                    style: AppTextStyles.inter(
                      fontSize: 12.5,
                      color: AppColors.inkSlate,
                      height: 1.4,
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

class _PermissionToggleCard extends StatelessWidget {
  const _PermissionToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return KtCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.indigoSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.biruTinta, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.inter(
                    fontSize: 11.5,
                    color: AppColors.inkSlate,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.biruTinta,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
