import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/config/env.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kita_illustration.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/domain/entities/student_profile.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SchoolLoginScreen extends ConsumerStatefulWidget {
  const SchoolLoginScreen({super.key});

  @override
  ConsumerState<SchoolLoginScreen> createState() => _SchoolLoginScreenState();
}

class _SchoolLoginScreenState extends ConsumerState<SchoolLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSub;
  bool _isHandlingExternalAuth = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(supabaseClientProvider);
    _authSub = client?.auth.onAuthStateChange.listen((data) async {
      if (data.event != AuthChangeEvent.signedIn ||
          _isLoading ||
          _isHandlingExternalAuth ||
          !mounted) {
        return;
      }
      _isHandlingExternalAuth = true;
      final restored = await ref
          .read(studentProfileProvider.notifier)
          .restoreSessionIfAuthenticated();
      if (!mounted) return;
      _isHandlingExternalAuth = false;
      if (restored) {
        await _navigateAfterAuth(ref.read(studentProfileProvider));
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _navigateAfterAuth(StudentProfile profile) async {
    if (!mounted) return;
    final target =
        profile.needsProfileSetup ? AppRoutes.completeProfile : AppRoutes.home;
    await Navigator.of(context)
        .pushNamedAndRemoveUntil(target, (route) => false);
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Masukkan alamat email yang valid.');
      return;
    }
    if (password.length < 6) {
      _showSnack('Kata sandi minimal 6 karakter.');
      return;
    }

    if (_isRegisterMode && password != _confirmPasswordController.text) {
      _showSnack('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    setState(() => _isLoading = true);
    final notifier = ref.read(studentProfileProvider.notifier);

    if (_isRegisterMode) {
      final draft = StudentProfile(
        id: 'student-pending',
        schoolId: defaultSchoolSlug,
        schoolName: '',
        name: '',
        shortName: '',
        className: '',
        safeDaysCount: 1,
        counselorName: defaultCounselorName,
        email: email,
        isGoogleConnected: true,
        isProfileCompleted: false,
        role: UserRole.siswa,
      );
      final res = await notifier.signUpWithEmail(
        email: email,
        password: password,
        profile: draft,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res case Ok(:final value)) {
        await _navigateAfterAuth(value);
      } else if (res case Err(:final failure)) {
        _showSnack(failure.message);
      }
      return;
    }

    final res = await notifier.signInWithEmail(
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res case Ok(:final value)) {
      await _navigateAfterAuth(value);
    } else if (res case Err(:final failure)) {
      _showSnack(failure.message);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    final notifier = ref.read(studentProfileProvider.notifier);
    final res = await notifier.launchGoogleOAuth();
    if (!mounted) return;

    if (res case Ok(:final value) when value) {
      setState(() => _isLoading = false);
      _showSnack('Mengalihkan ke login Google...');
      return;
    }

    if (res case Err(:final failure)) {
      setState(() => _isLoading = false);
      _showSnack(failure.message);
      return;
    }

    if (Env.useSupabase || ref.read(supabaseClientProvider) != null) {
      setState(() => _isLoading = false);
      _showSnack(
        'Login Google belum tersedia saat ini. Silakan masuk menggunakan Email & Kata Sandi.',
      );
      return;
    }

    // Offline / headless test fallback: send directly to Biodata setup screen.
    notifier.prepareBiodataDraft(
      email: _emailController.text.trim().isEmpty
          ? 'siswa@gmail.com'
          : _emailController.text.trim(),
      isGoogleConnected: true,
    );
    setState(() => _isLoading = false);
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.completeProfile,
      (route) => false,
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModePillButton(
              label: 'Masuk',
              selected: !_isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModePillButton(
              label: 'Daftar Akun',
              selected: _isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return KtCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Email', style: _fieldLabelStyle()),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'nama@gmail.com',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Text('Kata sandi', style: _fieldLabelStyle()),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: _isRegisterMode
                  ? 'Minimal 6 karakter'
                  : 'Masukkan kata sandi',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.inkSlate,
                ),
              ),
            ),
          ),
          if (_isRegisterMode) ...[
            const SizedBox(height: 12),
            Text('Konfirmasi kata sandi', style: _fieldLabelStyle()),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(
                hintText: 'Ulangi kata sandi',
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
              ),
            ),
          ],
          const SizedBox(height: 18),
          AppButton(
            label: _isRegisterMode ? 'Daftar sebagai Siswa' : 'Masuk',
            isLoading: _isLoading,
            onPressed: _submitAuth,
          ),
        ],
      ),
    );
  }

  TextStyle _fieldLabelStyle() => AppTextStyles.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.inkNavy,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const KtPageHeader(
                  title: 'Masuk ke KitaTemani',
                  subtitle:
                      'Masuk dengan akunmu untuk dukungan dan pelaporan aman',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KtCard(
                          color: AppColors.tintIndigo,
                          borderColor: AppColors.indigoSoft,
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const KitaIllustration(
                                scene: IllustrationScene.welcomeLogin,
                                width: 82,
                                height: 58,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ruang amanmu di sekolah',
                                      style: AppTextStyles.poppins(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.inkNavy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cerita, lapor, dan cari bantuan tanpa rasa takut.',
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
                        _buildModeSwitcher(),
                        const SizedBox(height: 14),
                        _buildFormCard(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'atau lanjutkan lewat',
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        KtCard(
                          onTap: _isLoading ? null : _handleGoogleLogin,
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const GoogleLogoMark(size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Lanjutkan dengan Google',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkNavy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const KtInfoBanner(
                          title: 'Dijaga privat & rahasia',
                          message:
                              'Identitas dan laporanmu dijaga ketat kerahasiaannya. Hanya kamu dan Guru BK yang berwenang yang dapat membaca laporan.',
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

class _ModePillButton extends StatelessWidget {
  const _ModePillButton({
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected ? AppColors.cardShadow : const [],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.poppins(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.biruTinta : AppColors.inkSlate,
            ),
          ),
        ),
      ),
    );
  }
}
