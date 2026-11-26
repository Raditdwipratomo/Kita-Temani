import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/report/data/repositories/report_repository_impl.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _classController;
  late final TextEditingController _schoolController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(studentProfileProvider);
    _nameController = TextEditingController(
      text: current.name.trim() == 'Maya Putri' ? '' : current.name.trim(),
    );
    _classController = TextEditingController(
      text: current.isProfileCompleted ? current.className.trim() : '',
    );
    _schoolController = TextEditingController(
      text: current.isProfileCompleted ? current.schoolName.trim() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveBiodata() async {
    final name = _nameController.text.trim();
    final className = _classController.text.trim();
    final schoolName = _schoolController.text.trim();

    if (name.isEmpty) {
      _showSnack('Masukkan nama lengkapmu terlebih dahulu.');
      return;
    }
    if (className.isEmpty) {
      _showSnack('Masukkan kelasmu (contoh: XI-2).');
      return;
    }
    if (schoolName.isEmpty) {
      _showSnack('Masukkan nama sekolahmu terlebih dahulu.');
      return;
    }

    setState(() => _isSaving = true);
    final res =
        await ref.read(studentProfileProvider.notifier).saveProfileAndSync(
              name: name,
              className: className,
              schoolName: schoolName,
              schoolId: defaultSchoolSlug,
              counselorName: defaultCounselorName,
              isPrivateMode: false,
              isProfileCompleted: true,
              role: UserRole.siswa,
            );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res case Err(:final failure)) {
      _showSnack(failure.message);
      return;
    }

    await Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  Future<void> _switchAccount() async {
    final repo = ref.read(reportRepositoryProvider);
    if (repo is ReportRepositoryImpl) {
      await repo.clearLocalCache();
    }
    await ref.read(studentProfileProvider.notifier).signOut();
    if (!mounted) return;
    await Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.schoolLogin, (route) => false);
  }

  TextStyle _labelStyle() => AppTextStyles.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.inkNavy,
      );

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const KtPageHeader(
                  title: 'Lengkapi Biodata',
                  subtitle:
                      'Isi identitasmu sebelum masuk ke beranda KitaTemani',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KtCard(
                          color: AppColors.tintMint,
                          borderColor: AppColors.hijau.withValues(alpha: 0.22),
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const KitaIllustration(
                                scene: IllustrationScene.welcomeLogin,
                                width: 74,
                                height: 52,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kenalan singkat dulu ya',
                                      style: AppTextStyles.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.inkNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Data ini membantu Guru BK mendampingimu dengan cepat dan tepat.',
                                      style: AppTextStyles.inter(
                                        fontSize: 12,
                                        color: AppColors.inkSlate,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (profile.email.trim().isNotEmpty) ...[
                          KtCard(
                            color: AppColors.tintIndigo,
                            borderColor:
                                AppColors.biruTinta.withValues(alpha: 0.25),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  size: 20,
                                  color: AppColors.biruTinta,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Masuk dengan akun',
                                        style: AppTextStyles.inter(
                                          fontSize: 11.5,
                                          color: AppColors.inkSlate,
                                        ),
                                      ),
                                      Text(
                                        profile.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.inkNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                KtStatusPill.mint('Terhubung'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        KtCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nama lengkap', style: _labelStyle()),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: Radit Dwi',
                                  prefixIcon: Icon(Icons.person_outline_rounded,
                                      size: 20),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Kelas', style: _labelStyle()),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _classController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: XI-2 / X IPA 1',
                                  prefixIcon:
                                      Icon(Icons.class_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Nama sekolah', style: _labelStyle()),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _schoolController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Contoh: SMAN 1 Nusantara',
                                  prefixIcon:
                                      Icon(Icons.school_outlined, size: 20),
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppButton(
                                label: 'Simpan Biodata & Lanjut',
                                isLoading: _isSaving,
                                onPressed: _saveBiodata,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const KtInfoBanner(
                          title: 'Biodata dijaga rahasia',
                          message:
                              'Nama, kelas, dan asal sekolahmu membantu Guru BK mendampingimu dengan tepat. Identitasmu tidak pernah dibuka ke siswa lain.',
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                            onPressed: _isSaving ? null : _switchAccount,
                            child: Text(
                              'Ganti akun / Keluar',
                              style: AppTextStyles.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSlate,
                              ),
                            ),
                          ),
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
