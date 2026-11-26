import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/file_bytes_helper.dart';
import 'package:kitatemani/features/report/presentation/widgets/docx_document_parser.dart';

/// Cross-platform interactive DOCX viewer rendered natively in Flutter from parsed
/// OOXML content (`word/document.xml`), supporting paragraphs, headings, lists,
/// tables, and embedded images.
class EvidenceDocxViewer extends StatefulWidget {
  const EvidenceDocxViewer({
    required this.fileName,
    this.bytes,
    this.localPath,
    this.networkUrl,
    this.onOpenExternal,
    super.key,
  });

  final String fileName;
  final Uint8List? bytes;
  final String? localPath;
  final String? networkUrl;
  final VoidCallback? onOpenExternal;

  @override
  State<EvidenceDocxViewer> createState() => _EvidenceDocxViewerState();
}

class _EvidenceDocxViewerState extends State<EvidenceDocxViewer> {
  final ValueNotifier<double> _fontScale = ValueNotifier<double>(1.0);
  bool _isLoading = true;
  DocxDocumentModel? _document;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAndParse());
  }

  @override
  void dispose() {
    _fontScale.dispose();
    super.dispose();
  }

  Future<void> _loadAndParse() async {
    try {
      Uint8List? resolvedBytes = widget.bytes;
      if (resolvedBytes == null || resolvedBytes.isEmpty) {
        final localPath = widget.localPath?.trim();
        if (localPath != null && localPath.isNotEmpty) {
          resolvedBytes = await readFileBytes(localPath);
        }
      }
      if (resolvedBytes == null || resolvedBytes.isEmpty) {
        final remoteUrl = widget.networkUrl?.trim();
        if (remoteUrl != null && remoteUrl.isNotEmpty) {
          final uri = Uri.tryParse(remoteUrl);
          if (uri != null &&
              (uri.scheme == 'http' || uri.scheme == 'https')) {
            final res = await http.get(uri).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              resolvedBytes = res.bodyBytes;
            }
          }
        }
      }

      if (!mounted) return;
      if (resolvedBytes == null || resolvedBytes.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Isi dokumen DOCX belum tersedia secara lokal atau gagal diunduh.';
        });
        return;
      }

      final parsed = resolvedBytes.lengthInBytes < 32 * 1024
          ? parseDocxBytes(resolvedBytes)
          : await compute(parseDocxBytes, resolvedBytes);
      if (!mounted) return;

      if (parsed == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Format file DOCX tidak dapat dibaca. Gunakan tombol Buka / Unduh untuk membukanya di aplikasi dokumen.';
        });
        return;
      }

      setState(() {
        _document = parsed;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat pratinjau dokumen DOCX.';
      });
    }
  }

  void _adjustScale(double delta) {
    final next = (_fontScale.value + delta).clamp(0.85, 1.45);
    _fontScale.value = double.parse(next.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('evidence_docx_viewer'),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Memuat pratinjau dokumen DOCX…',
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    final doc = _document;
    if (doc == null) {
      return _buildFallbackCard(
        _errorMessage ?? 'Preview DOCX tidak tersedia.',
      );
    }

    if (doc.isEmpty) {
      return _buildFallbackCard(
        'Dokumen DOCX tidak memiliki teks, tabel, atau gambar yang dapat ditampilkan.',
      );
    }

    final statParts = <String>[
      '${doc.paragraphCount} paragraf',
      '${doc.wordCount} kata',
      if (doc.tableCount > 0) '${doc.tableCount} tabel',
      if (doc.imageCount > 0) '${doc.imageCount} gambar',
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.biruTinta.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFB7C5FF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'DOCX',
                    style: AppTextStyles.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB7C5FF),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.inter(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Perkecil teks',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _adjustScale(-0.1),
                  icon: Text(
                    'A-',
                    style: AppTextStyles.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: _fontScale,
                  builder: (_, scale, __) => Text(
                    '${(scale * 100).round()}%',
                    style: AppTextStyles.code(
                      fontSize: 11,
                      color: Colors.white70,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Perbesar teks',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _adjustScale(0.1),
                  icon: Text(
                    'A+',
                    style: AppTextStyles.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _fontScale,
                  builder: (context, scale, _) => ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 20,
                    ),
                    itemCount: doc.blocks.length,
                    itemBuilder: (context, index) => _DocxBlockView(
                      block: doc.blocks[index],
                      scale: scale,
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

  Widget _buildFallbackCard(String message) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_rounded,
            size: 48,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          Text(
            widget.fileName,
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
          if (widget.onOpenExternal != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onOpenExternal,
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
}

class _DocxBlockView extends StatelessWidget {
  const _DocxBlockView({
    required this.block,
    required this.scale,
  });

  final DocxBlock block;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final current = block;
    if (current is DocxParagraphBlock) {
      return _buildParagraph(current);
    }
    if (current is DocxTableBlock) {
      return _buildTable(current);
    }
    if (current is DocxImageBlock) {
      return _buildImage(context, current);
    }
    return const SizedBox.shrink();
  }

  Widget _buildParagraph(DocxParagraphBlock paragraph) {
    final isHeading = paragraph.headingLevel > 0;
    final double baseSize = switch (paragraph.headingLevel) {
      1 => 19.5,
      2 => 16.5,
      3 => 14.5,
      _ => 13.5,
    };
    final effectiveSize = baseSize * scale;

    final baseStyle = isHeading
        ? AppTextStyles.poppins(
            fontSize: effectiveSize,
            fontWeight: FontWeight.w700,
            color: AppColors.inkNavy,
            height: 1.35,
          )
        : AppTextStyles.inter(
            fontSize: effectiveSize,
            color: AppColors.inkNavy,
            height: 1.58,
          );

    final spans = paragraph.runs.map((run) {
      return TextSpan(
        text: run.text,
        style: TextStyle(
          fontWeight:
              run.bold || isHeading ? FontWeight.w700 : baseStyle.fontWeight,
          fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
          decoration: run.underline ? TextDecoration.underline : null,
        ),
      );
    }).toList();

    final textWidget = SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: paragraph.alignment,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: isHeading ? 8 : 0,
        bottom: isHeading ? 8 : 10,
      ),
      child: paragraph.isListItem
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 1),
                  child: Text('•', style: baseStyle),
                ),
                Expanded(child: textWidget),
              ],
            )
          : textWidget,
    );
  }

  Widget _buildTable(DocxTableBlock table) {
    final cellStyle = AppTextStyles.inter(
      fontSize: 12.5 * scale,
      color: AppColors.inkNavy,
      height: 1.4,
    );
    final headerStyle = AppTextStyles.poppins(
      fontSize: 12.5 * scale,
      fontWeight: FontWeight.w600,
      color: AppColors.inkNavy,
      height: 1.4,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: AppColors.borderHairline,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            for (var r = 0; r < table.rows.length; r++)
              TableRow(
                decoration: r == 0
                    ? const BoxDecoration(color: AppColors.tintIndigo)
                    : null,
                children: [
                  for (final cell in table.rows[r])
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: SelectableText(
                          cell,
                          style: r == 0 ? headerStyle : cellStyle,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, DocxImageBlock image) {
    final rawCacheW = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();
    final safeCacheW = rawCacheW > 0 ? rawCacheW.clamp(320, 1440) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          image.bytes,
          fit: BoxFit.contain,
          cacheWidth: safeCacheW,
          gaplessPlayback: true,
          semanticLabel: image.description,
        ),
      ),
    );
  }
}
