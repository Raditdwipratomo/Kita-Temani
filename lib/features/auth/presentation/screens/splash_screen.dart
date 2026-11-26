import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/owl_mascot.dart';
import 'package:kitatemani/core/widgets/student_illustrations.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/l10n/l10n.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2400), _goNext);
  }

  Future<void> _goNext() async {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

    final restored = await ref
        .read(studentProfileProvider.notifier)
        .restoreSessionIfAuthenticated();
    if (!mounted) return;
    if (!restored) {
      await Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }
    final profile = ref.read(studentProfileProvider);
    final target =
        profile.needsProfileSetup ? AppRoutes.completeProfile : AppRoutes.home;
    await Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _goNext,
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.splashGradient,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Spacer(flex: 3),
                const KitaTemaniLogoMark(size: 96),
                const SizedBox(height: 18),
                Text(
                  L10n.appTitle,
                  style: AppTextStyles.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  L10n.splashTagline,
                  style: AppTextStyles.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const Spacer(flex: 3),
                const _SplashMascotFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashMascotFooter extends StatelessWidget {
  const _SplashMascotFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OwlMascot(
            mood: OwlMood.warm,
            size: 112,
            showContainer: true,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Teman amanmu di sekolah',
              style: AppTextStyles.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.inkNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
