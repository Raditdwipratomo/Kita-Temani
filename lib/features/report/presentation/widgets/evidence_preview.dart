import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/file_bytes_helper.dart';
import 'package:kitatemani/core/utils/evidence_link_parser.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_document_viewer.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_docx_viewer.dart';
import 'package:kitatemani/features/report/presentation/widgets/evidence_media_player.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a full-screen interactive preview modal for an uploaded evidence item.
Future<void> showEvidencePreviewDialog(
  BuildContext context,
  EvidenceAttachment attachment,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) => _EvidencePreviewDialog(attachment: attachment),
  );
}

/// Opens a full-screen preview/player modal for an external evidence link
/// (YouTube, Google Drive video/file, direct video URL, or web link).
Future<void> showEvidenceLinkPreviewDialog(
  BuildContext context,
  String rawUrl,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) => _EvidenceLinkPreviewDialog(rawUrl: rawUrl),
  );
}

Future<void> _launchExternalUrl(BuildContext context, String rawUrl) async {
  final parsed = parseEvidenceLink(rawUrl);
  final target = parsed?.normalizedUrl ?? rawUrl.trim();
  final uri = Uri.tryParse(target);
  var launched = false;
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      launched = false;
    }
  }
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tidak dapat membuka tautan di browser eksternal.'),
      ),
    );
  }
}

_LinkVisualStyle _styleForLink(ParsedEvidenceLink? parsed) {
  return switch (parsed?.kind) {
    EvidenceLinkKind.youtube => const _LinkVisualStyle(
        icon: Icons.smart_display_rounded,
        iconColor: Color(0xFFD92D20),
        badgeBg: Color(0xFFFFECEC),
        bannerTint: Color(0xFFD92D20),
      ),
    EvidenceLinkKind.googleDrive => const _LinkVisualStyle(
        icon: Icons.video_library_rounded,
        iconColor: AppColors.biruTinta,
        badgeBg: AppColors.tintSky,
        bannerTint: AppColors.biruTinta,
      ),
    EvidenceLinkKind.googleDriveFolder => const _LinkVisualStyle(
        icon: Icons.folder_outlined,
        iconColor: AppColors.amberText,
        badgeBg: AppColors.amberTint,
        bannerTint: AppColors.amberText,
      ),
    EvidenceLinkKind.directVideo => const _LinkVisualStyle(
        icon: Icons.videocam_rounded,
        iconColor: AppColors.biruTinta,
        badgeBg: AppColors.tintIndigo,
        bannerTint: AppColors.biruTinta,
      ),
    EvidenceLinkKind.directPdf => const _LinkVisualStyle(
        icon: Icons.picture_as_pdf_rounded,
        iconColor: AppColors.darurat,
        badgeBg: Color(0xFFFFECEC),
        bannerTint: AppColors.darurat,
      ),
    EvidenceLinkKind.directDocx => const _LinkVisualStyle(
        icon: Icons.description_rounded,
        iconColor: AppColors.biruTinta,
        badgeBg: AppColors.tintIndigo,
        bannerTint: AppColors.biruTinta,
      ),
    _ => const _LinkVisualStyle(
        icon: Icons.link_rounded,
        iconColor: AppColors.biruTinta,
        badgeBg: AppColors.tintIndigo,
        bannerTint: AppColors.biruTinta,
      ),
  };
}

class _LinkVisualStyle {
  const _LinkVisualStyle({
    required this.icon,
    required this.iconColor,
    required this.badgeBg,
    required this.bannerTint,
  });

  final IconData icon;
  final Color iconColor;
  final Color badgeBg;
  final Color bannerTint;
}

class EvidenceAttachmentChip extends StatelessWidget {
  const EvidenceAttachmentChip({
    required this.attachment,
    this.onRemove,
    super.key,
  });

  final EvidenceAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = attachment.isVideo;
    return Tooltip(
      message: isVideo
          ? 'Klik untuk memutar video bukti'
          : 'Klik / Ctrl+Klik atau tekan ikon mata untuk lihat preview',
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => showEvidencePreviewDialog(context, attachment),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderHairline, width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniThumb(attachment: attachment),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 168),
                  child: Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: AppColors.indigoSoft,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => showEvidencePreviewDialog(context, attachment),
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVideo
                                ? Icons.play_arrow_rounded
                                : Icons.visibility_outlined,
                            size: isVideo ? 15 : 13.5,
                            color: AppColors.biruTinta,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isVideo ? 'Putar' : 'Preview',
                            style: AppTextStyles.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.biruTinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: AppColors.darurat,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EvidenceLinkChip extends StatelessWidget {
  const EvidenceLinkChip({
    required this.url,
    this.onRemove,
    super.key,
  });

  final String url;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    final parsed = parseEvidenceLink(trimmed);
    final style = _styleForLink(parsed);
    final isPlayable = parsed?.isPlayable ?? false;
    final hasInlinePreview = parsed?.hasInlinePreview ?? false;

    return Tooltip(
      message: isPlayable
          ? 'Klik untuk memutar video tautan (${parsed!.badgeLabel})'
          : (hasInlinePreview
              ? 'Klik untuk melihat pratinjau dokumen (${parsed!.badgeLabel})'
              : 'Klik untuk membuka pratinjau tautan bukti'),
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => showEvidenceLinkPreviewDialog(context, trimmed),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderHairline, width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: style.badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(style.icon, size: 16, color: style.iconColor),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 168),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (parsed != null &&
                          parsed.kind != EvidenceLinkKind.externalLink)
                        Text(
                          parsed.badgeLabel,
                          style: AppTextStyles.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: style.iconColor,
                          ),
                        ),
                      Text(
                        trimmed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: AppColors.indigoSoft,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () =>
                        showEvidenceLinkPreviewDialog(context, trimmed),
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlayable
                                ? Icons.play_arrow_rounded
                                : (hasInlinePreview
                                    ? Icons.visibility_outlined
                                    : Icons.open_in_new_rounded),
                            size: isPlayable ? 15 : 13,
                            color: AppColors.biruTinta,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isPlayable
                                ? 'Putar'
                                : (hasInlinePreview ? 'Preview' : 'Buka'),
                            style: AppTextStyles.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.biruTinta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: AppColors.darurat,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniThumb extends StatelessWidget {
  const _MiniThumb({required this.attachment});

  final EvidenceAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage &&
        attachment.bytes != null &&
        attachment.bytes!.isNotEmpty) {
      final cachePx = (28 * MediaQuery.devicePixelRatioOf(context)).round();
      final safeCachePx = cachePx > 0 ? cachePx : null;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          attachment.bytes!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          cacheWidth: safeCachePx,
          cacheHeight: safeCachePx,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _iconBox(),
        ),
      );
    }
    if (attachment.isImage &&
        attachment.previewUrl != null &&
        attachment.previewUrl!.isNotEmpty) {
      final cachePx = (28 * MediaQuery.devicePixelRatioOf(context)).round();
      final safeCachePx = cachePx > 0 ? cachePx : null;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          attachment.previewUrl!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          cacheWidth: safeCachePx,
          cacheHeight: safeCachePx,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _iconBox(),
        ),
      );
    }
    return _iconBox();
  }

  Widget _iconBox() {
    final IconData icon;
    final Color iconColor;
    final Color bgColor;
    if (attachment.isVideo) {
      icon = Icons.videocam_rounded;
      iconColor = AppColors.biruTinta;
      bgColor = AppColors.tintIndigo;
    } else if (attachment.isImage) {
      icon = Icons.image_outlined;
      iconColor = AppColors.biruTinta;
      bgColor = AppColors.tintIndigo;
    } else if (attachment.isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      iconColor = AppColors.darurat;
      bgColor = AppColors.tintCoral;
    } else if (attachment.isDocx) {
      icon = Icons.description_rounded;
      iconColor = AppColors.biruTinta;
      bgColor = AppColors.tintIndigo;
    } else if (attachment.kind == 'suara') {
      icon = Icons.audiotrack_outlined;
      iconColor = AppColors.biruTinta;
      bgColor = AppColors.tintIndigo;
    } else {
      icon = Icons.attach_file_rounded;
      iconColor = AppColors.biruTinta;
      bgColor = AppColors.tintIndigo;
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }
}

/// Visual preview card for uploaded evidence inside Detail Laporan.
class EvidencePreviewCard extends StatelessWidget {
  const EvidencePreviewCard({
    required this.attachment,
    super.key,
  });

  final EvidenceAttachment attachment;

  Widget _buildImagePreview(BuildContext context) {
    final cacheH = (170 * MediaQuery.devicePixelRatioOf(context)).round();
    final safeCacheH = cacheH > 0 ? cacheH : null;
    if (attachment.bytes != null && attachment.bytes!.isNotEmpty) {
      return Image.memory(
        attachment.bytes!,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheHeight: safeCacheH,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _emptyImagePlaceholder(),
      );
    }
    if (attachment.previewUrl != null && attachment.previewUrl!.isNotEmpty) {
      return Image.network(
        attachment.previewUrl!,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheHeight: safeCacheH,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 170,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => _emptyImagePlaceholder(),
      );
    }
    return _emptyImagePlaceholder();
  }

  Widget _buildVideoBanner() {
    return Container(
      height: 146,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF161B33), Color(0xFF242B4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 1.4,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'VIDEO',
                style: AppTextStyles.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Putar video',
                    style: AppTextStyles.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyImagePlaceholder() {
    return Container(
      height: 120,
      width: double.infinity,
      color: AppColors.tintIndigo,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            attachment.isImage
                ? Icons.image_outlined
                : Icons.attach_file_rounded,
            size: 32,
            color: AppColors.biruTinta,
          ),
          const SizedBox(height: 6),
          Text(
            'Ketuk tombol Preview untuk melihat lampiran',
            style: AppTextStyles.inter(
              fontSize: 12,
              color: AppColors.inkSlate,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDocSize(int byteCount) {
    if (byteCount < 1024) return '$byteCount B';
    if (byteCount < 1024 * 1024) {
      return '${(byteCount / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteCount / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = attachment.isVideo;
    final effectiveSize = attachment.sizeBytes ?? attachment.bytes?.length;
    final IconData leadingIcon;
    final Color leadingColor;
    if (isVideo) {
      leadingIcon = Icons.videocam_rounded;
      leadingColor = AppColors.biruTinta;
    } else if (attachment.isImage) {
      leadingIcon = Icons.image_outlined;
      leadingColor = AppColors.biruTinta;
    } else if (attachment.isPdf) {
      leadingIcon = Icons.picture_as_pdf_rounded;
      leadingColor = AppColors.darurat;
    } else if (attachment.isDocx) {
      leadingIcon = Icons.description_rounded;
      leadingColor = AppColors.biruTinta;
    } else {
      leadingIcon = Icons.attach_file_rounded;
      leadingColor = AppColors.biruTinta;
    }

    return Tooltip(
      message: isVideo
          ? 'Klik atau tekan Putar Video untuk memutar video bukti'
          : 'Klik / Ctrl+Klik atau tekan Lihat Preview untuk memperbesar',
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => showEvidencePreviewDialog(context, attachment),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderHairline, width: 1.1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attachment.isImage)
                  Stack(
                    children: [
                      _buildImagePreview(context),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.zoom_in_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Perbesar',
                                style: AppTextStyles.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isVideo)
                  _buildVideoBanner(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        leadingIcon,
                        size: 18,
                        color: leadingColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            if (isVideo)
                              Text(
                                'Video siap diputar',
                                style: AppTextStyles.inter(
                                  fontSize: 11,
                                  color: AppColors.biruTinta,
                                ),
                              )
                            else if (attachment.isPdf || attachment.isDocx)
                              Text(
                                '${attachment.isPdf ? 'Dokumen PDF' : 'Dokumen DOCX'}${effectiveSize != null ? ' · ${_formatDocSize(effectiveSize)}' : ''}',
                                style: AppTextStyles.inter(
                                  fontSize: 11,
                                  color: AppColors.inkSlate,
                                ),
                              )
                            else if (attachment.exifStripped &&
                                attachment.isImage)
                              Text(
                                'EXIF dihapus otomatis',
                                style: AppTextStyles.inter(
                                  fontSize: 11,
                                  color: AppColors.mintText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () =>
                            showEvidencePreviewDialog(context, attachment),
                        icon: Icon(
                          isVideo
                              ? Icons.play_circle_outline_rounded
                              : Icons.visibility_outlined,
                          size: 16,
                        ),
                        label: Text(isVideo ? 'Putar Video' : 'Lihat Preview'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.biruTinta,
                          backgroundColor: AppColors.indigoSoft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: AppTextStyles.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}

/// Interactive preview card for attached evidence links (YouTube, Google Drive,
/// direct video URL, or regular web links) inside Review & Detail Laporan.
class EvidenceLinkCard extends StatelessWidget {
  const EvidenceLinkCard({
    required this.url,
    super.key,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    final parsed = parseEvidenceLink(trimmed);
    final style = _styleForLink(parsed);
    final isPlayable = parsed?.isPlayable ?? false;
    final hasInlinePreview = parsed?.hasInlinePreview ?? false;

    return Tooltip(
      message: isPlayable
          ? 'Klik atau tekan Putar Video untuk memutar tautan video'
          : (hasInlinePreview
              ? 'Klik atau tekan Lihat Preview untuk melihat dokumen'
              : 'Klik untuk membuka pratinjau tautan bukti'),
      child: Material(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => showEvidenceLinkPreviewDialog(context, trimmed),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderHairline, width: 1.1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parsed != null && isPlayable)
                  _PlayableLinkBanner(parsed: parsed, style: style),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(style.icon, size: 18, color: style.iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parsed?.modalTitle ?? 'Tautan Bukti',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkNavy,
                              ),
                            ),
                            Text(
                              trimmed,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.inter(
                                fontSize: 11.5,
                                color: style.iconColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () =>
                            showEvidenceLinkPreviewDialog(context, trimmed),
                        icon: Icon(
                          isPlayable
                              ? Icons.play_circle_outline_rounded
                              : (hasInlinePreview
                                  ? Icons.visibility_outlined
                                  : Icons.open_in_new_rounded),
                          size: 16,
                        ),
                        label: Text(
                          isPlayable
                              ? 'Putar Video'
                              : (hasInlinePreview ? 'Lihat Preview' : 'Buka Link'),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.biruTinta,
                          backgroundColor: AppColors.indigoSoft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: AppTextStyles.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}

class _PlayableLinkBanner extends StatelessWidget {
  const _PlayableLinkBanner({
    required this.parsed,
    required this.style,
  });

  final ParsedEvidenceLink parsed;
  final _LinkVisualStyle style;

  @override
  Widget build(BuildContext context) {
    final isYouTube = parsed.kind == EvidenceLinkKind.youtube;
    final thumbUrl = parsed.thumbnailUrl;
    final pillLabel = switch (parsed.kind) {
      EvidenceLinkKind.youtube => 'YOUTUBE',
      EvidenceLinkKind.googleDrive => 'GOOGLE DRIVE',
      EvidenceLinkKind.directVideo => 'VIDEO LINK',
      _ => parsed.badgeLabel.toUpperCase(),
    };

    return Container(
      height: 118,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF161B33), Color(0xFF242B4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isYouTube && thumbUrl != null)
            Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round()
                  .clamp(320, 1440),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Container(color: Colors.black.withValues(alpha: 0.36)),
          Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isYouTube
                    ? const Color(0xFFE53935).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.3,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                pillLabel,
                style: AppTextStyles.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePreviewDialog extends StatefulWidget {
  const _EvidencePreviewDialog({required this.attachment});

  final EvidenceAttachment attachment;

  @override
  State<_EvidencePreviewDialog> createState() => _EvidencePreviewDialogState();
}

class _EvidencePreviewDialogState extends State<_EvidencePreviewDialog> {
  Future<Uint8List?>? _localBytesFuture;

  @override
  void initState() {
    super.initState();
    final att = widget.attachment;
    if (att.isImage &&
        (att.bytes == null || att.bytes!.isEmpty) &&
        (att.previewUrl == null || att.previewUrl!.isEmpty) &&
        att.localPath != null &&
        att.localPath!.isNotEmpty) {
      _localBytesFuture = readFileBytes(att.localPath);
    }
  }

  String _formatSize(int byteCount) {
    if (byteCount < 1024) return '$byteCount B';
    if (byteCount < 1024 * 1024) {
      return '${(byteCount / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteCount / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Widget _buildContent() {
    final att = widget.attachment;
    if (att.isVideo) {
      return EvidenceVideoPlayer(
        fileName: att.fileName,
        bytes: att.bytes,
        localPath: att.localPath,
        networkUrl: att.previewUrl,
        mimeType: att.mimeType,
      );
    }

    if (att.isPdf) {
      return EvidencePdfViewer(
        fileName: att.fileName,
        bytes: att.bytes,
        localPath: att.localPath,
        networkUrl: att.previewUrl,
        onOpenExternal: att.previewUrl != null && att.previewUrl!.isNotEmpty
            ? () => unawaited(_launchExternalUrl(context, att.previewUrl!))
            : null,
      );
    }

    if (att.isDocx) {
      return EvidenceDocxViewer(
        fileName: att.fileName,
        bytes: att.bytes,
        localPath: att.localPath,
        networkUrl: att.previewUrl,
        onOpenExternal: att.previewUrl != null && att.previewUrl!.isNotEmpty
            ? () => unawaited(_launchExternalUrl(context, att.previewUrl!))
            : null,
      );
    }

    if (att.isImage) {
      if (att.bytes != null && att.bytes!.isNotEmpty) {
        return InteractiveViewer(
          minScale: 0.7,
          maxScale: 4,
          child: Image.memory(
            att.bytes!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallbackCard(
              'Gambar tidak dapat ditampilkan.',
            ),
          ),
        );
      }

      if (att.previewUrl != null && att.previewUrl!.isNotEmpty) {
        return InteractiveViewer(
          minScale: 0.7,
          maxScale: 4,
          child: Image.network(
            att.previewUrl!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => _fallbackCard(
              'Gagal memuat preview gambar dari server.',
            ),
          ),
        );
      }

      if (_localBytesFuture != null) {
        return FutureBuilder<Uint8List?>(
          future: _localBytesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            final data = snapshot.data;
            if (data != null && data.isNotEmpty) {
              return InteractiveViewer(
                minScale: 0.7,
                maxScale: 4,
                child: Image.memory(
                  data,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              );
            }
            return _fallbackCard(
              'File gambar tidak tersedia di perangkat ini.',
            );
          },
        );
      }

      return _fallbackCard(
        'Preview gambar belum tersedia. Pastikan gambar diunggah dari perangkat atau terhubung ke server.',
      );
    }

    final effectiveBytes = att.sizeBytes ?? att.bytes?.length;
    final sizeInfo =
        effectiveBytes != null && effectiveBytes > 0
            ? ' · ${_formatSize(effectiveBytes)}'
            : '';
    return _fallbackCard(
      'Lampiran bertipe ${att.kind.toUpperCase()}$sizeInfo siap disertakan dalam laporan.',
    );
  }

  Widget _fallbackCard(String message) {
    final IconData icon;
    if (widget.attachment.isPdf) {
      icon = Icons.picture_as_pdf_rounded;
    } else if (widget.attachment.isDocx) {
      icon = Icons.description_rounded;
    } else {
      icon = switch (widget.attachment.kind) {
        'foto' => Icons.image_not_supported_outlined,
        'video' => Icons.videocam_rounded,
        'suara' => Icons.audiotrack_rounded,
        _ => Icons.insert_drive_file_outlined,
      };
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            widget.attachment.fileName,
            textAlign: TextAlign.center,
            style: AppTextStyles.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.45,
              ),
            ),
            if (!widget.attachment.isImage &&
                !widget.attachment.isVideo &&
                widget.attachment.previewUrl != null &&
                widget.attachment.previewUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => unawaited(
                    _launchExternalUrl(context, widget.attachment.previewUrl!)),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Buka / Unduh Dokumen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.inkNavy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ],
          ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachment;
    final isVideo = att.isVideo;
    final isDocument = att.isPdf || att.isDocx;
    final effectiveBytes = att.sizeBytes ?? att.bytes?.length;
    final sizeInfo = effectiveBytes != null && effectiveBytes > 0
        ? ' · ${_formatSize(effectiveBytes)}'
        : '';

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (isVideo)
                          Text(
                            'Pemutar video bukti$sizeInfo',
                            style: AppTextStyles.inter(
                              fontSize: 11.5,
                              color: const Color(0xFFB7C5FF),
                            ),
                          )
                        else if (att.isPdf)
                          Text(
                            'Preview dokumen PDF$sizeInfo',
                            style: AppTextStyles.inter(
                              fontSize: 11.5,
                              color: const Color(0xFFFFB4AB),
                            ),
                          )
                        else if (att.isDocx)
                          Text(
                            'Preview dokumen DOCX$sizeInfo',
                            style: AppTextStyles.inter(
                              fontSize: 11.5,
                              color: const Color(0xFFB7C5FF),
                            ),
                          )
                        else if (att.exifStripped && att.isImage)
                          Text(
                            'Preview bukti · Metadata EXIF telah dihapus',
                            style: AppTextStyles.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF8BE2B6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildContent(),
                ),
              ),
            ),
            if (isVideo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Gunakan kontrol pemutar untuk memutar atau memperbesar · Tekan × untuk menutup',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.inter(
                          fontSize: 11.5,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    if (att.previewUrl != null &&
                        att.previewUrl!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () => unawaited(
                            _launchExternalUrl(context, att.previewUrl!)),
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Buka di tab baru',
                          style: AppTextStyles.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (isDocument)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Tekan ESC / × untuk menutup pratinjau dokumen',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.inter(
                          fontSize: 11.5,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    if (att.previewUrl != null &&
                        att.previewUrl!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () => unawaited(
                            _launchExternalUrl(context, att.previewUrl!)),
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Buka / Unduh',
                          style: AppTextStyles.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else if (att.isImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Scroll atau cubit untuk memperbesar · Tekan ESC / × untuk menutup',
                  style: AppTextStyles.inter(
                    fontSize: 11.5,
                    color: Colors.white60,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceLinkPreviewDialog extends StatelessWidget {
  const _EvidenceLinkPreviewDialog({required this.rawUrl});

  final String rawUrl;

  @override
  Widget build(BuildContext context) {
    final parsed = parseEvidenceLink(rawUrl);
    final style = _styleForLink(parsed);
    final targetUrl = parsed?.normalizedUrl ?? rawUrl.trim();

    final footerCaption = switch (parsed?.kind) {
      EvidenceLinkKind.youtube =>
        'Video YouTube diputar langsung · Tekan × untuk menutup',
      EvidenceLinkKind.googleDrive =>
        'Pastikan akses file Google Drive diatur ke "Siapa saja yang memiliki link" agar video bisa diputar.',
      EvidenceLinkKind.directVideo =>
        'Gunakan kontrol pemutar untuk memutar video · Tekan × untuk menutup',
      _ => 'Tautan bukti eksternal · Tekan × untuk menutup',
    };

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(style.icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed?.modalTitle ?? 'Tautan Bukti',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          targetUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.inter(
                            fontSize: 11.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup preview',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildPlayerBody(context, parsed, style, targetUrl),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      footerCaption,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.inter(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        unawaited(_launchExternalUrl(context, targetUrl)),
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Buka di tab baru',
                      style: AppTextStyles.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBody(
    BuildContext context,
    ParsedEvidenceLink? parsed,
    _LinkVisualStyle style,
    String targetUrl,
  ) {
    if (parsed != null && parsed.kind == EvidenceLinkKind.directVideo) {
      final pathName =
          Uri.tryParse(parsed.normalizedUrl)?.pathSegments.lastOrNull;
      return EvidenceVideoPlayer(
        fileName: (pathName != null && pathName.isNotEmpty)
            ? pathName
            : 'video_tautan.mp4',
        networkUrl: parsed.normalizedUrl,
        mimeType: parsed.mimeType,
      );
    }

    if (parsed != null && parsed.isPlayable && parsed.embedUrl != null) {
      return EvidenceEmbedPlayer(
        parsed: parsed,
        onOpenExternal: () => unawaited(_launchExternalUrl(context, targetUrl)),
      );
    }

    if (parsed != null && parsed.kind == EvidenceLinkKind.directPdf) {
      final pathName =
          Uri.tryParse(parsed.normalizedUrl)?.pathSegments.lastOrNull;
      return EvidencePdfViewer(
        fileName: (pathName != null && pathName.isNotEmpty)
            ? pathName
            : 'dokumen.pdf',
        networkUrl: parsed.normalizedUrl,
        onOpenExternal: () => unawaited(_launchExternalUrl(context, targetUrl)),
      );
    }

    if (parsed != null && parsed.kind == EvidenceLinkKind.directDocx) {
      final pathName =
          Uri.tryParse(parsed.normalizedUrl)?.pathSegments.lastOrNull;
      return EvidenceDocxViewer(
        fileName: (pathName != null && pathName.isNotEmpty)
            ? pathName
            : 'dokumen.docx',
        networkUrl: parsed.normalizedUrl,
        onOpenExternal: () => unawaited(_launchExternalUrl(context, targetUrl)),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 46, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            parsed?.modalTitle ?? 'Tautan Bukti',
            textAlign: TextAlign.center,
            style: AppTextStyles.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            targetUrl,
            textAlign: TextAlign.center,
            style: AppTextStyles.inter(
              fontSize: 12.5,
              color: const Color(0xFFB7C5FF),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            parsed?.kind == EvidenceLinkKind.googleDriveFolder
                ? 'Tautan ini adalah folder Google Drive. Buka langsung untuk melihat seluruh isi folder bukti.'
                : 'Buka tautan ini di tab atau aplikasi browser untuk memeriksa isi bukti secara lengkap.',
            textAlign: TextAlign.center,
            style: AppTextStyles.inter(
              fontSize: 12,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => unawaited(_launchExternalUrl(context, targetUrl)),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Buka Tautan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.inkNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
