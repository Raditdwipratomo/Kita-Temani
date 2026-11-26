import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/utils/evidence_link_parser.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/core/widgets/kitatemani_widgets.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_preview.dart';
import 'package:kitatemani/features/report/presentation/widgets/report_step_indicator.dart';
import 'package:kitatemani/l10n/l10n.dart';

class ReportStoryScreen extends ConsumerStatefulWidget {
  const ReportStoryScreen({super.key});

  @override
  ConsumerState<ReportStoryScreen> createState() => _ReportStoryScreenState();
}

class _ReportStoryScreenState extends ConsumerState<ReportStoryScreen> {
  late final TextEditingController _narrativeController;
  late final TextEditingController _perpetratorsController;
  late final TextEditingController _victimNameController;
  late final TextEditingController _linkController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(submitReportControllerProvider);
    _narrativeController = TextEditingController(text: draft.narrative);
    _perpetratorsController =
        TextEditingController(text: draft.perpetratorNames);
    _victimNameController = TextEditingController(text: draft.victimName);
    _linkController = TextEditingController(text: draft.evidenceLink);
  }

  @override
  void dispose() {
    _narrativeController.dispose();
    _perpetratorsController.dispose();
    _victimNameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _syncDraft() {
    ref.read(submitReportControllerProvider.notifier)
      ..updateNarrative(_narrativeController.text)
      ..updatePerpetratorNames(_perpetratorsController.text)
      ..updateVictimName(_victimNameController.text)
      ..updateEvidenceLink(_linkController.text);
  }

  void _onNext() {
    ScaffoldMessenger.of(context).clearSnackBars();
    _syncDraft();
    Navigator.of(context).pushNamed(AppRoutes.reportReview);
  }

  String _formatSize(int byteCount) {
    if (byteCount < 1024) return '$byteCount B';
    if (byteCount < 1024 * 1024) {
      return '${(byteCount / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteCount / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _pickDocument() async {
    final media = ref.read(mediaServiceProvider);
    final result = await media.pickEvidenceDocument();
    if (!mounted) return;
    if (result.isCancelled) return;

    if (result.isSuccess && result.evidence != null) {
      final picked = result.evidence!;
      ref
          .read(submitReportControllerProvider.notifier)
          .addPickedEvidence(picked);
      final sizeLabel = picked.sizeBytes != null
          ? ' (${_formatSize(picked.sizeBytes!)})'
          : '';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content:
                Text('${picked.fileName}$sizeLabel dilampirkan ke laporan.'),
          ),
        );
      return;
    }

    if (result.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: AppColors.darurat,
          ),
        );
    }
  }

  Future<void> _openAddLinkSheet() async {
    final savedLink = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddEvidenceLinkSheet(initialUrl: _linkController.text),
    );

    if (savedLink != null && mounted) {
      _linkController.text = savedLink;
      ref
          .read(submitReportControllerProvider.notifier)
          .updateEvidenceLink(savedLink);
    }
  }

  InputDecoration _cardInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.inter(
        fontSize: 13.5,
        color: AppColors.textMuted,
        height: 1.5,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        title: L10n.reportStoryTitle,
                        onBack: () {
                          _syncDraft();
                          Navigator.of(context).pop();
                        },
                        trailing: KtStatusPill.mint(
                          'Privat & aman',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: ReportStepIndicator(currentStep: 2),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            Text(
                              'Tuliskan dengan bahasamu sendiri agar Guru BK mudah memahami situasinya.',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 16),

                            // 1) Input teks: Cerita kejadian
                            Text(
                              'CERITA KEJADIAN',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            KtCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: TextField(
                                key: const Key('report_narrative_input'),
                                controller: _narrativeController,
                                maxLines: 7,
                                minLines: 5,
                                onChanged: controller.updateNarrative,
                                style: AppTextStyles.inter(
                                  fontSize: 14,
                                  color: AppColors.inkNavy,
                                  height: 1.5,
                                ),
                                decoration: _cardInputDecoration(
                                  'Contoh: Saat jam istirahat kedua di dekat kantin, beberapa kakak kelas mengejek dan mengambil tas saya...',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2) Input teks: List nama pelaku
                            Text(
                              'LIST NAMA PELAKU',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tulis satu atau beberapa nama pelaku (pisahkan dengan koma atau baris baru). Boleh cantumkan kelas/ciri jika tidak tahu nama lengkap.',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            KtCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: TextField(
                                key: const Key('report_perpetrators_input'),
                                controller: _perpetratorsController,
                                maxLines: 4,
                                minLines: 2,
                                textCapitalization: TextCapitalization.words,
                                onChanged: controller.updatePerpetratorNames,
                                style: AppTextStyles.inter(
                                  fontSize: 14,
                                  color: AppColors.inkNavy,
                                  height: 1.5,
                                ),
                                decoration: _cardInputDecoration(
                                  'Contoh: Andi (XII-IPA 1), Budi (XII-IPA 2)',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3) Input teks: Nama korban
                            Text(
                              'NAMA KORBAN',
                              style: AppTextStyles.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            KtCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: TextField(
                                key: const Key('report_victim_name_input'),
                                controller: _victimNameController,
                                maxLines: 2,
                                minLines: 1,
                                textCapitalization: TextCapitalization.words,
                                onChanged: controller.updateVictimName,
                                style: AppTextStyles.inter(
                                  fontSize: 14,
                                  color: AppColors.inkNavy,
                                  height: 1.5,
                                ),
                                decoration: _cardInputDecoration(
                                  'Contoh: Radit Pratama (XI-MIPA 2)',
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Evidence section header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'BUKTI DOKUMEN ATAU LINK',
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
                                  'PDF / DOCX · Maks. 2 MB',
                                  style: AppTextStyles.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.biruTinta,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lampirkan dokumen pendukung berformat PDF atau DOCX dengan ukuran maksimal 2 MB, atau sertakan tautan bukti.',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: 12),

                            // 1) Upload File/Dokumen (PDF / DOCX maks. 2 MB)
                            KtCard(
                              onTap: _pickDocument,
                              color: AppColors.cardWhite,
                              borderColor: AppColors.borderHairline,
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.indigoSoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.description_outlined,
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
                                          'Lampirkan file / dokumen',
                                          style: AppTextStyles.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Hanya format PDF atau DOCX · Maksimal 2 MB',
                                          style: AppTextStyles.inter(
                                            fontSize: 11.5,
                                            color: AppColors.inkSlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.add_rounded,
                                    color: AppColors.biruTinta,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 2) Tambah link bukti
                            KtCard(
                              onTap: _openAddLinkSheet,
                              color: AppColors.cardWhite,
                              borderColor: draft.evidenceLink.trim().isNotEmpty
                                  ? AppColors.biruTinta
                                  : AppColors.borderHairline,
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.tintSky,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.link_rounded,
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
                                          'Tambah link bukti',
                                          style: AppTextStyles.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          draft.evidenceLink.trim().isNotEmpty
                                              ? draft.evidenceLink.trim()
                                              : 'YouTube, Google Drive, video, atau tautan bukti lainnya',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.inter(
                                            fontSize: 11.5,
                                            color: draft.evidenceLink
                                                    .trim()
                                                    .isNotEmpty
                                                ? AppColors.biruTinta
                                                : AppColors.inkSlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    draft.evidenceLink.trim().isNotEmpty
                                        ? Icons.edit_outlined
                                        : Icons.add_rounded,
                                    color: AppColors.biruTinta,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),

                            if (draft.attachments.isNotEmpty ||
                                draft.evidenceFiles.isNotEmpty ||
                                draft.evidenceLink.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (draft.evidenceLink.trim().isNotEmpty)
                                    EvidenceLinkChip(
                                      url: draft.evidenceLink.trim(),
                                      onRemove: () {
                                        _linkController.clear();
                                        controller.updateEvidenceLink('');
                                      },
                                    ),
                                  ...(draft.evidenceFiles.isNotEmpty
                                          ? draft.evidenceFiles
                                          : draft.attachments
                                              .map((f) => EvidenceAttachment(
                                                  fileName: f))
                                              .toList())
                                      .map(
                                    (item) => EvidenceAttachmentChip(
                                      attachment: item,
                                      onRemove: () => controller
                                          .removeAttachment(item.fileName),
                                    ),
                                  ),
                                ],
                              ),
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: AppButton(
                            label: 'Kembali',
                            isOutlined: true,
                            onPressed: () {
                              _syncDraft();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: AppButton(
                            label: 'Tinjau laporan',
                            onPressed: _onNext,
                          ),
                        ),
                      ],
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

class _AddEvidenceLinkSheet extends StatefulWidget {
  const _AddEvidenceLinkSheet({required this.initialUrl});

  final String initialUrl;

  @override
  State<_AddEvidenceLinkSheet> createState() => _AddEvidenceLinkSheetState();
}

class _AddEvidenceLinkSheetState extends State<_AddEvidenceLinkSheet> {
  late final TextEditingController _controller;
  ParsedEvidenceLink? _parsed;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
    _parsed = parseEvidenceLink(widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      Navigator.of(context).pop('');
      return;
    }
    final parsed = parseEvidenceLink(raw);
    if (parsed == null) {
      setState(() {
        _errorText =
            'Masukkan tautan yang valid (misal https://youtu.be/... atau https://drive.google.com/file/d/...)';
      });
      return;
    }
    Navigator.of(context).pop(parsed.normalizedUrl);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final hasText = _controller.text.trim().isNotEmpty;
    final isPlayable = parsed?.isPlayable ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tambah link bukti', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
            'Tempelkan tautan video YouTube, Google Drive, media sosial, atau bukti lainnya.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autofocus: true,
            onChanged: (value) {
              setState(() {
                _parsed = parseEvidenceLink(value);
                _errorText = null;
              });
            },
            onSubmitted: (_) => _onSave(),
            decoration: InputDecoration(
              hintText:
                  'https://youtu.be/... atau https://drive.google.com/file/d/...',
              prefixIcon: const Icon(Icons.link_rounded),
              errorText: _errorText,
            ),
          ),
          if (hasText && parsed != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isPlayable ? AppColors.tintMint : AppColors.tintIndigo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPlayable
                      ? AppColors.hijau.withValues(alpha: 0.25)
                      : AppColors.borderHairline,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPlayable
                        ? Icons.play_circle_filled_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18,
                    color:
                        isPlayable ? AppColors.mintText : AppColors.biruTinta,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parsed.detectionHint,
                      style: AppTextStyles.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPlayable
                            ? AppColors.mintText
                            : AppColors.biruTinta,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: 'Simpan link bukti',
            onPressed: _onSave,
          ),
        ],
      ),
    );
  }
}
