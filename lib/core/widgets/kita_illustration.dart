import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Unified Minimal Editorial Geometric illustration scenes matching the
/// KitaTemani owl mascot across empty states, education, and onboarding cards.
enum IllustrationScene {
  eduBoundary(
    'assets/illustrations/scene_edu_boundary.svg',
    'Ilustrasi membedakan bercanda dan perundungan',
  ),
  eduAlly(
    'assets/illustrations/scene_edu_ally.svg',
    'Ilustrasi menemani teman yang dirundung',
  ),
  eduCyber(
    'assets/illustrations/scene_edu_cyber.svg',
    'Ilustrasi melindungi diri dari cyberbullying',
  ),
  eduSelfcare(
    'assets/illustrations/scene_edu_selfcare.svg',
    'Ilustrasi menenangkan pikiran saat cemas di sekolah',
  ),
  emptyReports(
    'assets/illustrations/scene_empty_reports.svg',
    'Ilustrasi buku catatan laporan masih kosong',
  ),
  reportSent(
    'assets/illustrations/scene_report_sent.svg',
    'Ilustrasi laporan terkirim dengan aman ke Guru BK',
  ),
  welcomeLogin(
    'assets/illustrations/scene_welcome_login.svg',
    'Ilustrasi selamat datang di ruang aman KitaTemani',
  ),
  guardianContacts(
    'assets/illustrations/scene_guardian_contacts.svg',
    'Ilustrasi lingkaran kontak darurat tepercaya',
  ),
  heroBanner(
    'assets/illustrations/scene_hero_owl.svg',
    'Ilustrasi maskot burung hantu KitaTemani menyapa hangat',
  );

  const IllustrationScene(this.assetPath, this.defaultLabel);

  final String assetPath;
  final String defaultLabel;
}

/// Renders a crisp, zero-clipart vector [IllustrationScene] cleanly at any
/// screen density without unbounded animations.
class KitaIllustration extends StatelessWidget {
  const KitaIllustration({
    required this.scene,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticsLabel,
  });

  final IllustrationScene scene;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticsLabel ?? scene.defaultLabel,
      child: RepaintBoundary(
        child: SvgPicture.asset(
          scene.assetPath,
          width: width,
          height: height,
          fit: fit,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
