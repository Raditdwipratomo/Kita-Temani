import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/widgets/report_step_indicator.dart';
import 'package:kitatemani/l10n/l10n.dart';

class ReportTypeScreen extends ConsumerStatefulWidget {
  const ReportTypeScreen({super.key});

  @override
  ConsumerState<ReportTypeScreen> createState() => _ReportTypeScreenState();
}

class _ReportTypeScreenState extends ConsumerState<ReportTypeScreen> {
  late final TextEditingController _locationController;
  late final FocusNode _locationFocusNode;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(
      text: ref.read(submitReportControllerProvider).location,
    );
    _locationFocusNode = FocusNode()..addListener(_onLocationFocusChanged);
  }

  void _onLocationFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _locationFocusNode
      ..removeListener(_onLocationFocusChanged)
      ..dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    SubmitReportController controller,
    DateTime current,
  ) async {
    final now = DateTime.now();
    final safeInitial = current.isAfter(now) ? now : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2028, 12, 31),
      helpText: 'Pilih tanggal kejadian',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      controller.updateOccurredAt(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReportDraftState>(submitReportControllerProvider, (_, next) {
      if (_locationController.text != next.location) {
        _locationController.text = next.location;
        _locationController.selection = TextSelection.collapsed(
          offset: next.location.length,
        );
      }
    });
    final draft = ref.watch(submitReportControllerProvider);
    final controller = ref.read(submitReportControllerProvider.notifier);

    return Scaffold(
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
                        title: L10n.reportBullyingTitle,
                        trailing: KtStatusPill.indigo(
                          'Privat & Rahasia',
                          icon: Icons.lock_outline_rounded,
                        ),
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        child: ReportStepIndicator(currentStep: 1),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          children: [
                            // Role segmented switch: Aku yang mengalami / Aku melihat kejadian
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.indigoSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  _RoleSegment(
                                    label: 'Aku yang mengalami',
                                    selected: draft.isVictim,
                                    onTap: () =>
                                        controller.updateIsVictim(true),
                                  ),
                                  _RoleSegment(
                                    label: 'Aku melihat kejadian',
                                    selected: !draft.isVictim,
                                    onTap: () =>
                                        controller.updateIsVictim(false),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Jenis perundungan
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'PILIH JENIS BULLYING',
                                    style: AppTextStyles.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.7,
                                      color: AppColors.inkNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bisa pilih > 1',
                                  style: AppTextStyles.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkSlate,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            _BullyingTypeCard(
                              icon: Icons.front_hand_outlined,
                              accentColor: AppColors.coralText,
                              softBackground: AppColors.tintCoral,
                              title: 'Fisik',
                              subtitle:
                                  'Dorongan, pukulan, tendangan, atau perusakan barang pribadi.',
                              selected: draft.selectedTypes
                                  .contains(BullyingType.fisik),
                              onTap: () =>
                                  controller.toggleType(BullyingType.fisik),
                            ),
                            const SizedBox(height: 10),
                            _BullyingTypeCard(
                              icon: Icons.record_voice_over_outlined,
                              accentColor: AppColors.amberText,
                              softBackground: AppColors.amberTint,
                              title: 'Verbal',
                              subtitle:
                                  'Ejekan, panggilan menghina, membentak, atau ancaman lisan.',
                              selected: draft.selectedTypes
                                  .contains(BullyingType.verbal),
                              onTap: () =>
                                  controller.toggleType(BullyingType.verbal),
                            ),
                            const SizedBox(height: 10),
                            _BullyingTypeCard(
                              icon: Icons.phonelink_ring_outlined,
                              accentColor: AppColors.skyText,
                              softBackground: AppColors.tintSky,
                              title: 'Siber (Online)',
                              subtitle:
                                  'Teror di grup chat WhatsApp, media sosial, atau sebar foto tanpa izin.',
                              selected: draft.selectedTypes
                                  .contains(BullyingType.siber),
                              onTap: () =>
                                  controller.toggleType(BullyingType.siber),
                            ),
                            const SizedBox(height: 22),

                            // Date Input Picker ("Kapan kejadiannya?") matching Screen 07 requirement
                            Text(
                              'KAPAN KEJADIANNYA?',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            KtCard(
                              onTap: () => _pickDate(
                                context,
                                controller,
                                draft.occurredAt,
                              ),
                              borderRadius: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.indigoSoft,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today_rounded,
                                      color: AppColors.biruTinta,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormatter.fullDate(
                                            draft.occurredAt,
                                          ),
                                          style: AppTextStyles.poppins(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.inkNavy,
                                          ),
                                        ),
                                        Text(
                                          'Ketuk untuk pilih tanggal kejadian',
                                          style: AppTextStyles.inter(
                                            fontSize: 11.5,
                                            color: AppColors.inkSlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.biruTinta,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Lokasi
                            Text(
                              'DI MANA LOKASINYA?',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            KtCard(
                              borderRadius: 16,
                              borderColor: _locationFocusNode.hasFocus
                                  ? AppColors.biruTinta
                                  : AppColors.borderHairline,
                              borderWidth:
                                  _locationFocusNode.hasFocus ? 1.5 : 1.1,
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
                                      color: AppColors.indigoSoft,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.place_outlined,
                                      color: AppColors.biruTinta,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      key: const Key('report_location_input'),
                                      controller: _locationController,
                                      focusNode: _locationFocusNode,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textInputAction: TextInputAction.done,
                                      maxLines: 1,
                                      maxLength: 120,
                                      buildCounter: (
                                        _, {
                                        required currentLength,
                                        required isFocused,
                                        required maxLength,
                                      }) =>
                                          null,
                                      style: AppTextStyles.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.inkNavy,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Contoh: Dekat kantin, Kelas XI-2, atau grup WhatsApp',
                                        hintStyle: AppTextStyles.inter(
                                          fontSize: 13.5,
                                          color: AppColors.textMuted,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: controller.updateLocation,
                                    ),
                                  ),
                                  if (draft.location.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: AppColors.inkSlate,
                                      ),
                                      tooltip: 'Hapus lokasi',
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        _locationController.clear();
                                        controller.updateLocation('');
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Boleh tulis nama ruang, area sekolah, luar sekolah, atau platform online.',
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
                ),
              ),
            ),

            // Bottom action container (full width bar with 720px centered button)
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
                      label: 'Lanjut ke Cerita Kejadian',
                      trailingIcon: Icons.chevron_right_rounded,
                      onPressed: () {
                        controller.updateLocation(
                          _locationController.text.trim(),
                        );
                        Navigator.of(context).pushNamed(AppRoutes.reportStory);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSegment extends StatelessWidget {
  const _RoleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.cardWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: selected
                ? Border.all(
                    color: AppColors.biruTinta.withValues(alpha: 0.35),
                    width: 1.2,
                  )
                : null,
            boxShadow: selected ? AppColors.circleControlShadow : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.poppins(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.biruTinta : AppColors.inkSlate,
            ),
          ),
        ),
      ),
    );
  }
}

class _BullyingTypeCard extends StatelessWidget {
  const _BullyingTypeCard({
    required this.icon,
    required this.accentColor,
    required this.softBackground,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final Color softBackground;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KtCard(
      onTap: onTap,
      color: selected ? softBackground : AppColors.cardWhite,
      borderColor: selected ? accentColor : AppColors.borderHairline,
      borderWidth: selected ? 1.5 : 1.1,
      borderRadius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? accentColor : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? accentColor : const Color(0xFFC9CFE6),
                width: 1.4,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? Colors.white : softBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accentColor, size: 19),
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
    );
  }
}
