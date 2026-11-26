import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/emergency_contacts/presentation/controllers/emergency_contacts_controller.dart';
import 'package:kitatemani/features/panic/presentation/controllers/panic_controller.dart';
import 'package:kitatemani/l10n/l10n.dart';

class PanicButtonScreen extends ConsumerStatefulWidget {
  const PanicButtonScreen({super.key});

  @override
  ConsumerState<PanicButtonScreen> createState() => _PanicButtonScreenState();
}

class _PanicButtonScreenState extends ConsumerState<PanicButtonScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _situationOptions = [
    'Diancam / diikuti',
    'Bullying fisik',
    'Terjebak / tidak aman',
    'Butuh dijemput',
  ];

  late AnimationController _holdController;
  Timer? _countdownTimer;
  final ValueNotifier<int> _countdownSeconds = ValueNotifier<int>(5);
  bool _isInGracePeriod = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        _startGracePeriod();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    _countdownTimer?.cancel();
    _countdownSeconds.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    if (_isInGracePeriod) return;
    HapticFeedback.lightImpact();
    _holdController.forward();
  }

  void _onHoldEnd() {
    if (_isInGracePeriod) return;
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  void _startGracePeriod() {
    _countdownSeconds.value = 5;
    setState(() {
      _isInGracePeriod = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds.value <= 1) {
        timer.cancel();
        _triggerEmergencyNow();
      } else {
        _countdownSeconds.value--;
      }
    });
  }

  void _cancelGracePeriod() {
    _countdownTimer?.cancel();
    _holdController.reset();
    _countdownSeconds.value = 5;
    setState(() {
      _isInGracePeriod = false;
    });
  }

  Future<void> _triggerEmergencyNow() async {
    if (_isSending) return;
    _countdownTimer?.cancel();
    setState(() => _isSending = true);
    try {
      await ref
          .read(panicControllerProvider.notifier)
          .triggerEmergency()
          .timeout(const Duration(seconds: 5));
    } on Object {
      // Never freeze on countdown screen even if GPS or network times out.
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(AppRoutes.panicActive);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(emergencyContactsControllerProvider);
    final counselorName =
        ref.watch(studentProfileProvider.select((p) => p.counselorName));
    final selectedSituation =
        ref.watch(panicControllerProvider.select((s) => s.situationTag));
    final activeContacts = contacts.where((c) => c.isActive).toList();
    final activeFamilyCount = activeContacts.length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 28,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        KtPageHeader(
                          title: L10n.panicTitle,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          trailing: KtStatusPill.sos(
                            'Siaga',
                            icon: Icons.sensors_rounded,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          L10n.panicQuestion,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.heading1,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          L10n.panicSubtitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tactile SOS Hold Button or 5s Grace Countdown
                    if (_isInGracePeriod)
                      _GraceCountdownCard(
                        secondsListenable: _countdownSeconds,
                        isSending: _isSending,
                        onCancel: _cancelGracePeriod,
                        onSendNow: _triggerEmergencyNow,
                      )
                    else
                      Semantics(
                        button: true,
                        label: 'Tahan 2 detik untuk kirim SOS darurat',
                        child: Listener(
                          onPointerDown: (_) => _onHoldStart(),
                          onPointerUp: (_) => _onHoldEnd(),
                          onPointerCancel: (_) => _onHoldEnd(),
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _holdController,
                              child: const _SosHoldBottomLabel(),
                              builder: (context, bottomLabel) {
                                final progress = _holdController.value;
                                return SizedBox(
                                  width: 236,
                                  height: 236,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Outer pulsing coral aura
                                      Container(
                                        width: 224 + (progress * 12),
                                        height: 224 + (progress * 12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.sosSoft
                                              .withValues(alpha: 0.72),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 210,
                                        height: 210,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 7,
                                          backgroundColor: AppColors.darurat
                                              .withValues(alpha: 0.16),
                                          valueColor: const AlwaysStoppedAnimation<
                                              Color>(
                                            AppColors.darurat,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 184,
                                        height: 184,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: AppColors.panicActiveGradient,
                                          boxShadow: AppColors.sosShadow,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.touch_app_rounded,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              progress > 0.05
                                                  ? 'TAHAN (${((1 - progress) * 2).toStringAsFixed(1)}s)'
                                                  : 'TAHAN 2 DETIK',
                                              style: AppTextStyles.poppins(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            if (bottomLabel != null)
                                              bottomLabel,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Column(
                      children: [
                        // Optional 1-tap situation context (never blocks 2s SOS hold)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Situasi cepat (opsional)',
                            style: AppTextStyles.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSlate,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _situationOptions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final label = _situationOptions[idx];
                              final selected = selectedSituation == label;
                              return ChoiceChip(
                                label: Text(label),
                                selected: selected,
                                showCheckmark: false,
                                selectedColor: AppColors.sosSoft,
                                backgroundColor: AppColors.cardWhite,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                labelStyle: AppTextStyles.inter(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppColors.crimsonContrast
                                      : AppColors.inkNavy,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: selected
                                        ? AppColors.darurat
                                        : AppColors.borderHairline,
                                  ),
                                ),
                                onSelected: (_) => ref
                                    .read(panicControllerProvider.notifier)
                                    .setSituationTag(label),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Recipient Preview Card (no 112 option)
                        KtCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'PENERIMA PERINGATAN ($activeFamilyCount+ KONTAK)',
                                    style: AppTextStyles.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.inkSlate,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context)
                                        .pushNamed(AppRoutes.emergencyContacts),
                                    child: Text(
                                      'Kelola kontak',
                                      style: AppTextStyles.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.biruTinta,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final contact in activeContacts)
                                    _RecipientBadge(
                                      name: contact.name,
                                      role: contact.isPrimary
                                          ? 'Utama'
                                          : contact.roleLabel,
                                    ),
                                  _RecipientBadge(
                                    name: counselorName.split(',').first,
                                    role: 'Guru BK',
                                  ),
                                ],
                              ),
                              if (activeContacts.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Belum ada kontak keluarga aktif. Ketuk "Kelola kontak" untuk menambahkan.',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const KtInfoBanner(
                          icon: Icons.chat_outlined,
                          message:
                              'Biodata lengkap, lokasi GPS, dan pesan darurat detail langsung disiapkan untuk dikirim lewat WhatsApp ke keluarga & Guru BK.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SosHoldBottomLabel extends StatelessWidget {
  const _SosHoldBottomLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Kirim SOS Darurat',
      style: AppTextStyles.inter(
        fontSize: 11.5,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

class _GraceCountdownCard extends StatelessWidget {
  const _GraceCountdownCard({
    required this.secondsListenable,
    required this.isSending,
    required this.onCancel,
    required this.onSendNow,
  });

  final ValueListenable<int> secondsListenable;
  final bool isSending;
  final VoidCallback onCancel;
  final VoidCallback onSendNow;

  @override
  Widget build(BuildContext context) {
    return KtCard(
      color: AppColors.sosSoft,
      borderColor: AppColors.darurat.withValues(alpha: 0.45),
      borderRadius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          if (isSending)
            Text(
              'Menyiapkan pesan darurat WhatsApp…',
              textAlign: TextAlign.center,
              style: AppTextStyles.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.crimsonContrast,
              ),
            )
          else
            ValueListenableBuilder<int>(
              valueListenable: secondsListenable,
              builder: (_, seconds, __) => Text(
                'Mengirim SOS dalam $seconds detik…',
                textAlign: TextAlign.center,
                style: AppTextStyles.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.crimsonContrast,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            isSending
                ? 'Mengambil koordinat GPS & mengirim notifikasi ke Panel Guru BK.'
                : 'Ketuk Batal jika tombol tertekan tidak sengaja.',
            textAlign: TextAlign.center,
            style: AppTextStyles.inter(
              fontSize: 12.5,
              color: AppColors.crimsonContrast,
            ),
          ),
          const SizedBox(height: 18),
          if (isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: CircularProgressIndicator(color: AppColors.darurat),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.inkNavy,
                      side: const BorderSide(color: AppColors.borderHairline),
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSendNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darurat,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Kirim sekarang'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecipientBadge extends StatelessWidget {
  const _RecipientBadge({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tintIndigo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHairline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 14,
            color: AppColors.biruTinta,
          ),
          const SizedBox(width: 5),
          Text(
            '$name ($role)',
            style: AppTextStyles.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.inkNavy,
            ),
          ),
        ],
      ),
    );
  }
}
