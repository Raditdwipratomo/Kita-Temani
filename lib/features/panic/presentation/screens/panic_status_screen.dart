import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';
import 'package:kitatemani/features/panic/presentation/controllers/panic_controller.dart';
import 'package:kitatemani/l10n/l10n.dart';

/// 60-30-10 KitaTemani-Themed Crisis Palette (zero multi-color clash).
/// - 60% Native KitaTemani light surfaces (`AppColors.canvas`, `AppColors.cardWhite`)
/// - 30% Brand Indigo & Ink Navy hierarchy (`AppColors.biruTinta`, `AppColors.inkNavy`)
/// - <=10% Single semantic SOS beacon (`AppColors.sosSoft` / `AppColors.sosDanger`).
abstract final class _SosPalette {
  static const Color canvasNeutral = AppColors.canvas;
  static const Color surfaceWhite = AppColors.cardWhite;
  static const Color surfaceSubtle = AppColors.tintIndigo;
  static const Color surfaceWell = AppColors.canvas;

  static const Color borderHairline = AppColors.borderHairline;
  static const Color borderDivider = Color(0xFFEDF0F8);
  static const Color borderOutlined = AppColors.borderStrong;

  static const Color inkPrimary = AppColors.inkNavy;
  static const Color inkSecondary = Color(0xFF4B5278);
  static const Color inkMuted = AppColors.inkSlate;
  static const Color brandPrimary = AppColors.biruTinta;
  static const Color softShadow = Color(0x0C1D224A);

  // Single controlled semantic SOS accent — used ONLY on the live beacon pill.
  static const Color alertBg = AppColors.sosSoft;
  static const Color alertBorder = Color(0xFFF9CBD0);
  static const Color alertDot = AppColors.sosDanger;
  static const Color alertText = AppColors.crimsonContrast;
}

class PanicStatusScreen extends ConsumerStatefulWidget {
  const PanicStatusScreen({super.key});

  @override
  ConsumerState<PanicStatusScreen> createState() => _PanicStatusScreenState();
}

enum _StopEmergencyChoice { cancel, stopOnly, stopAndNotifyWa }

class _PanicStatusScreenState extends ConsumerState<PanicStatusScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _pulseController;
  final ValueNotifier<int> _elapsedSeconds = ValueNotifier<int>(0);
  final Set<String> _openedWaPhones = {};

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds.value++;
      ref.read(panicControllerProvider.notifier).tickSecond();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  static String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static EmergencyContact? _primaryContactFrom(
    List<EmergencyContact> contacts,
  ) {
    for (final c in contacts) {
      if (c.isPrimary && c.isActive) return c;
    }
    for (final c in contacts) {
      if (c.isPrimary) return c;
    }
    for (final c in contacts) {
      if (c.isActive) return c;
    }
    return contacts.isNotEmpty ? contacts.first : null;
  }

  Future<void> _sendViaWhatsApp({
    required String phone,
    required String contactName,
    required String message,
  }) async {
    final launcher = ref.read(emergencyLauncherProvider);
    final launched = await launcher.openWhatsApp(
      context,
      phone: phone,
      contactName: contactName,
      message: message,
    );
    if (mounted && launched) {
      setState(() => _openedWaPhones.add(phone));
    }
  }

  Future<void> _copyMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _SosPalette.inkPrimary,
        content: Text('Pesan darurat disalin ke papan klip.'),
      ),
    );
  }

  Future<void> _refreshGps() async {
    final ok =
        await ref.read(panicControllerProvider.notifier).refreshLocation();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _SosPalette.inkPrimary,
        content: Text(
          ok
              ? 'Koordinat GPS & pesan WhatsApp berhasil diperbarui.'
              : 'GPS belum tersedia. Pastikan izin lokasi aktif di perangkat/browser.',
        ),
      ),
    );
  }

  Future<void> _stopEmergency() async {
    final choice = await showDialog<_StopEmergencyChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _SosPalette.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Text(
          'Hentikan mode darurat?',
          style: AppTextStyles.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _SosPalette.inkPrimary,
          ),
        ),
        content: Text(
          'Pastikan kamu sudah berada di tempat aman. Status darurat akan ditandai selesai untuk Guru BK.',
          style: AppTextStyles.inter(
            fontSize: 13.5,
            color: _SosPalette.inkSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_StopEmergencyChoice.stopOnly),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _SosPalette.brandPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Ya, saya aman'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(ctx)
                      .pop(_StopEmergencyChoice.stopAndNotifyWa),
                  icon: const Icon(Icons.chat_outlined, size: 17),
                  label: const Text('Aman & Kabari WA'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _SosPalette.inkPrimary,
                    side: const BorderSide(
                      color: _SosPalette.borderOutlined,
                      width: 1.2,
                    ),
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_StopEmergencyChoice.cancel),
                  style: TextButton.styleFrom(
                    foregroundColor: _SosPalette.inkMuted,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text('Tetap aktif'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == null || choice == _StopEmergencyChoice.cancel) return;

    final safeMsg =
        ref.read(panicControllerProvider.notifier).buildSafeWhatsAppMessage();
    final primaryContact =
        ref.read(emergencyContactsControllerProvider.notifier).primaryContact;
    final student = ref.read(studentProfileProvider);
    final launcher = ref.read(emergencyLauncherProvider);

    await ref.read(panicControllerProvider.notifier).markSafeAndStop();
    if (!mounted) return;

    if (choice == _StopEmergencyChoice.stopAndNotifyWa) {
      final targetPhone = primaryContact?.phone ?? student.counselorPhone;
      final targetName =
          primaryContact?.name ?? student.counselorName.split(',').first;
      await launcher.openWhatsApp(
        context,
        phone: targetPhone,
        contactName: targetName,
        message: safeMsg,
      );
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _SosPalette.inkPrimary,
        content: Text(
          'Mode darurat diakhiri. Status aman telah dikirim ke Guru BK.',
        ),
      ),
    );
    await Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(emergencyContactsControllerProvider);
    final primaryContact = _primaryContactFrom(contacts);
    final panicState = ref.watch(
      panicControllerProvider.select(
        (s) => (
          locationLabel: s.locationLabel,
          isRefreshingLocation: s.isRefreshingLocation,
          whatsappMessage: s.whatsappMessage,
          situationTag: s.situationTag,
          areaHint: s.areaHint,
          position: s.position,
          triggeredAt: s.triggeredAt,
        ),
      ),
    );
    final panicCtrl = ref.read(panicControllerProvider.notifier);
    final launcher = ref.read(emergencyLauncherProvider);
    final student = ref.watch(
      studentProfileProvider.select(
        (p) => (
          counselorName: p.counselorName,
          counselorPhone: p.counselorPhone,
          name: p.name,
          shortName: p.shortName,
          className: p.className,
          schoolName: p.schoolName,
        ),
      ),
    );
    final whatsappMessage = panicCtrl.resolveWhatsAppMessage();
    final counselorShort = student.counselorName.split(',').first;
    final hasGps = panicState.position != null &&
        panicState.position!.shortLink.isNotEmpty;

    final secondaryContacts = primaryContact == null
        ? const <EmergencyContact>[]
        : contacts
            .where((c) => c.id != primaryContact.id && c.isActive)
            .toList();

    final quickTargetName = primaryContact?.name ?? '$counselorShort (Guru BK)';
    final quickTargetPhone = primaryContact?.phone ?? student.counselorPhone;

    // Build unified grouped contact entries (iOS / Figma Untitled UI style)
    final contactEntries = <Widget>[
      if (primaryContact != null)
        _EmergencyContactRow(
          title: primaryContact.name,
          badgeLabel: 'Utama',
          subtitle: _openedWaPhones.contains(primaryContact.phone)
              ? '✓ WhatsApp dibuka (${primaryContact.phone})'
              : 'Siap kirim WhatsApp (${primaryContact.phone})',
          isOpened: _openedWaPhones.contains(primaryContact.phone),
          avatarIcon: _openedWaPhones.contains(primaryContact.phone)
              ? Icons.check_circle_outline_rounded
              : Icons.person_outline_rounded,
          waLabel: 'Chat WA ${primaryContact.name}',
          callLabel: 'Hubungi ${primaryContact.name}',
          onChatWa: () => _sendViaWhatsApp(
            phone: primaryContact.phone,
            contactName: primaryContact.name,
            message: whatsappMessage,
          ),
          onCall: () => launcher.openDialer(
            context,
            phone: primaryContact.phone,
            contactName: primaryContact.name,
          ),
        )
      else
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.emergencyContacts),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _SosPalette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 19,
                      color: _SosPalette.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Belum ada kontak keluarga terdaftar. Ketuk untuk menambah kontak darurat WhatsApp.',
                      style: AppTextStyles.inter(
                        fontSize: 12.5,
                        color: _SosPalette.inkSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: _SosPalette.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      for (final contact in secondaryContacts)
        _EmergencyContactRow(
          title: '${contact.name} (${contact.roleLabel})',
          subtitle: _openedWaPhones.contains(contact.phone)
              ? '✓ WhatsApp dibuka (${contact.phone})'
              : 'Siap kirim WhatsApp (${contact.phone})',
          isOpened: _openedWaPhones.contains(contact.phone),
          avatarIcon: _openedWaPhones.contains(contact.phone)
              ? Icons.check_circle_outline_rounded
              : Icons.person_outline_rounded,
          waLabel: 'Chat WA ${contact.name}',
          callLabel: 'Hubungi',
          onChatWa: () => _sendViaWhatsApp(
            phone: contact.phone,
            contactName: contact.name,
            message: whatsappMessage,
          ),
          onCall: () => launcher.openDialer(
            context,
            phone: contact.phone,
            contactName: contact.name,
          ),
        ),
      _EmergencyContactRow(
        title: '$counselorShort (Guru BK)',
        subtitle: _openedWaPhones.contains(student.counselorPhone)
            ? '✓ WhatsApp dibuka · Panel BK ternotifikasi (${student.counselorPhone})'
            : '✓ Panel BK ternotifikasi · WA: ${student.counselorPhone}',
        isOpened: _openedWaPhones.contains(student.counselorPhone),
        avatarIcon: Icons.school_outlined,
        waLabel: 'Chat WA $counselorShort',
        callLabel: 'Hubungi $counselorShort',
        onChatWa: () => _sendViaWhatsApp(
          phone: student.counselorPhone,
          contactName: counselorShort,
          message: whatsappMessage,
        ),
        onCall: () => launcher.openDialer(
          context,
          phone: student.counselorPhone,
          contactName: counselorShort,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: _SosPalette.canvasNeutral,
      body: Column(
        children: [
          // 1. Calm Light Monochrome Header — Single restrained Red Live Beacon
          Container(
            decoration: const BoxDecoration(
              color: _SosPalette.surfaceWhite,
              border: Border(
                bottom: BorderSide(
                  color: _SosPalette.borderHairline,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: _SosPalette.softShadow,
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar: Single red live status pill + neutral monospace timer
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _SosPalette.alertBg,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _SosPalette.alertBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RepaintBoundary(
                                    child: AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (_, __) {
                                        final scale = 0.85 +
                                            (_pulseController.value * 0.32);
                                        final haloOpacity = 0.14 +
                                            (_pulseController.value * 0.24);
                                        return SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Transform.scale(
                                                scale: scale,
                                                child: Container(
                                                  width: 11,
                                                  height: 11,
                                                  decoration: BoxDecoration(
                                                    color: _SosPalette.alertDot
                                                        .withValues(
                                                      alpha: haloOpacity,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 6.5,
                                                height: 6.5,
                                                decoration: const BoxDecoration(
                                                  color: _SosPalette.alertDot,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'DARURAT AKTIF',
                                    style: AppTextStyles.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.55,
                                      color: _SosPalette.alertText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _SosPalette.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _SosPalette.borderHairline,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 13.5,
                                    color: _SosPalette.inkSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  RepaintBoundary(
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _elapsedSeconds,
                                      builder: (_, seconds, __) => Text(
                                        _formatElapsed(seconds),
                                        style: AppTextStyles.code(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _SosPalette.inkPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          L10n.panicSentTitle,
                          style: AppTextStyles.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _SosPalette.inkPrimary,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Panel Guru BK ternotifikasi · ${panicState.locationLabel}',
                          style: AppTextStyles.inter(
                            fontSize: 12.8,
                            color: _SosPalette.inkMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Restrained Neutral Telemetry Pills (zero neon colors)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const _NeutralStatusPill(
                              icon: Icons.verified_user_outlined,
                              label: 'Guru BK ternotifikasi',
                            ),
                            _NeutralStatusPill(
                              icon: hasGps
                                  ? Icons.my_location_rounded
                                  : Icons.location_searching_rounded,
                              label: hasGps
                                  ? 'Koordinat GPS aktif'
                                  : 'GPS belum terkunci',
                              onTap: panicState.isRefreshingLocation
                                  ? null
                                  : _refreshGps,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Scrollable Calm Neutral Action Workspace
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    // Priority #1 Action Card — KitaTemani Brand Indigo CTA
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _SosPalette.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _SosPalette.borderHairline,
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: _SosPalette.softShadow,
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _SosPalette.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.bolt_rounded,
                                  size: 20,
                                  color: _SosPalette.brandPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kirim pesan darurat ke WhatsApp sekarang',
                                      style: AppTextStyles.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: _SosPalette.inkPrimary,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pesan sudah berisi nama, kelas, sekolah, waktu, dan lokasi GPS. Ketuk tombol di bawah untuk langsung membuka WhatsApp.',
                                      style: AppTextStyles.inter(
                                        fontSize: 12.5,
                                        color: _SosPalette.inkMuted,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendViaWhatsApp(
                                phone: quickTargetPhone,
                                contactName: quickTargetName,
                                message: whatsappMessage,
                              ),
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                              ),
                              label: Text('Kirim WhatsApp ke $quickTargetName'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _SosPalette.brandPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                textStyle: AppTextStyles.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Clean Paper-Styled SOS Message Preview Card
                    Container(
                      decoration: BoxDecoration(
                        color: _SosPalette.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _SosPalette.borderHairline,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 13, 12, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _SosPalette.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.article_outlined,
                                    size: 15.5,
                                    color: _SosPalette.brandPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pesan SOS siap kirim WhatsApp',
                                    style: AppTextStyles.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: _SosPalette.inkPrimary,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _copyMessage(whatsappMessage),
                                  icon:
                                      const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Salin'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _SosPalette.brandPrimary,
                                    backgroundColor: _SosPalette.surfaceSubtle,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    textStyle: AppTextStyles.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _SosPalette.brandPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _SosPalette.surfaceWell,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: _SosPalette.borderHairline,
                                ),
                              ),
                              child: Text(
                                whatsappMessage,
                                style: AppTextStyles.inter(
                                  fontSize: 12.2,
                                  color: _SosPalette.inkPrimary,
                                  height: 1.52,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: _SosPalette.borderDivider,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                            child: Row(
                              children: [
                                Icon(
                                  hasGps
                                      ? Icons.gps_fixed_rounded
                                      : Icons.gps_not_fixed_rounded,
                                  size: 15,
                                  color: _SosPalette.brandPrimary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    hasGps
                                        ? 'Tautan Google Maps siap dikirim'
                                        : 'Lokasi GPS belum terkunci',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _SosPalette.inkMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: panicState.isRefreshingLocation
                                      ? null
                                      : _refreshGps,
                                  icon: panicState.isRefreshingLocation
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _SosPalette.brandPrimary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.my_location_rounded,
                                          size: 14,
                                        ),
                                  label: Text(
                                    panicState.isRefreshingLocation
                                        ? 'Mencari…'
                                        : 'Perbarui GPS',
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _SosPalette.brandPrimary,
                                    backgroundColor: _SosPalette.surfaceSubtle,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    textStyle: AppTextStyles.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _SosPalette.brandPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Grouped Emergency Contacts Container (Apple HIG / Figma Untitled UI)
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 9),
                      child: Text(
                        'Kirim WhatsApp & hubungi kontak',
                        style: AppTextStyles.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _SosPalette.inkSecondary,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _SosPalette.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _SosPalette.borderHairline,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Column(
                          children: [
                            for (var i = 0; i < contactEntries.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: _SosPalette.borderDivider,
                                ),
                              contactEntries[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Calm Tactile Bottom Safety Dock (Outlined Brand Indigo — cohesive KitaTemani theme)
          Container(
            decoration: const BoxDecoration(
              color: _SosPalette.surfaceWhite,
              border: Border(
                top: BorderSide(color: _SosPalette.borderHairline, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: _SosPalette.softShadow,
                  blurRadius: 14,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: GestureDetector(
                      onLongPress: _stopEmergency,
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _stopEmergency,
                          icon: const Icon(
                            Icons.verified_user_outlined,
                            size: 19,
                          ),
                          label: const Text('Saya sudah aman · tahan 2 detik'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _SosPalette.brandPrimary,
                            backgroundColor: _SosPalette.surfaceWhite,
                            side: const BorderSide(
                              color: _SosPalette.brandPrimary,
                              width: 1.4,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: AppTextStyles.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _SosPalette.brandPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralStatusPill extends StatelessWidget {
  const _NeutralStatusPill({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: _SosPalette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _SosPalette.borderHairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: _SosPalette.brandPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _SosPalette.inkSecondary,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  const _EmergencyContactRow({
    required this.title,
    required this.subtitle,
    required this.isOpened,
    required this.avatarIcon,
    required this.waLabel,
    required this.callLabel,
    required this.onChatWa,
    required this.onCall,
    this.badgeLabel,
  });

  final String title;
  final String? badgeLabel;
  final String subtitle;
  final bool isOpened;
  final IconData avatarIcon;
  final String waLabel;
  final String callLabel;
  final VoidCallback onChatWa;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _SosPalette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  avatarIcon,
                  color: _SosPalette.brandPrimary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _SosPalette.inkPrimary,
                            ),
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: _SosPalette.surfaceSubtle,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _SosPalette.borderHairline,
                              ),
                            ),
                            child: Text(
                              badgeLabel!,
                              style: AppTextStyles.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _SosPalette.brandPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.inter(
                        fontSize: 12,
                        fontWeight: isOpened ? FontWeight.w600 : FontWeight.w500,
                        color: isOpened
                            ? _SosPalette.brandPrimary
                            : _SosPalette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: onChatWa,
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    waLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _SosPalette.brandPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    textStyle: AppTextStyles.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: Text(
                    callLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _SosPalette.surfaceWhite,
                    foregroundColor: _SosPalette.inkPrimary,
                    side: const BorderSide(
                      color: _SosPalette.borderOutlined,
                      width: 1,
                    ),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    textStyle: AppTextStyles.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _SosPalette.inkPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
