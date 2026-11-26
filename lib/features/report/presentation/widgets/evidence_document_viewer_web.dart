import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:web/web.dart' as web;

int _nextWebPdfViewId = 0;

/// Interactive inline PDF viewer for Flutter Web rendering Blob or remote PDF
/// streams directly inside an `iframe`.
class EvidencePdfViewer extends StatefulWidget {
  const EvidencePdfViewer({
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
  State<EvidencePdfViewer> createState() => _EvidencePdfViewerState();
}

class _EvidencePdfViewerState extends State<EvidencePdfViewer> {
  late final String _viewType;
  bool _isLoading = true;
  String? _blobUrl;
  String? _sourceUrl;
  String? _errorMessage;
  web.HTMLIFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'kt-evidence-pdf-${_nextWebPdfViewId++}';
    unawaited(_initPdfSource());
  }

  Future<void> _initPdfSource() async {
    String? resolvedSource;
    try {
      final bytes = widget.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        resolvedSource = _createPdfBlobUrl(bytes);
      } else {
        final remote = widget.networkUrl?.trim() ?? '';
        if (remote.isNotEmpty) {
          final uri = Uri.tryParse(remote);
          if (uri != null &&
              (uri.scheme == 'http' || uri.scheme == 'https')) {
            try {
              final res =
                  await http.get(uri).timeout(const Duration(seconds: 15));
              if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
                resolvedSource = _createPdfBlobUrl(res.bodyBytes);
              } else {
                resolvedSource = remote;
              }
            } on Object {
              resolvedSource = remote;
            }
          }
        }

        if (resolvedSource == null) {
          final local = widget.localPath?.trim() ?? '';
          if (local.startsWith('http://') ||
              local.startsWith('https://') ||
              local.startsWith('blob:')) {
            resolvedSource = local;
          }
        }
      }
    } on Object {
      resolvedSource = null;
    }

    if (!mounted) {
      _revokeBlobIfAny();
      return;
    }

    if (resolvedSource == null || resolvedSource.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Sumber PDF belum tersedia di browser. Pastikan file sudah terunggah atau buka via tautan eksternal.';
      });
      return;
    }

    final embedSrc = resolvedSource;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = web.HTMLIFrameElement()
        ..src = embedSrc
        ..title = widget.fileName
        ..allowFullscreen = true;
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none'
        ..borderRadius = '14px'
        ..backgroundColor = '#1E2235';
      _iframeElement = iframe;
      return iframe;
    });

    setState(() {
      _sourceUrl = embedSrc;
      _isLoading = false;
    });
  }

  String _createPdfBlobUrl(Uint8List bytes) {
    final blob = web.Blob(
      <web.BlobPart>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final url = web.URL.createObjectURL(blob);
    _blobUrl = url;
    return url;
  }

  void _revokeBlobIfAny() {
    final blobUrl = _blobUrl;
    if (blobUrl != null) {
      web.URL.revokeObjectURL(blobUrl);
      _blobUrl = null;
    }
  }

  @override
  void dispose() {
    final iframe = _iframeElement;
    if (iframe != null) {
      iframe.src = 'about:blank';
      _iframeElement = null;
    }
    _revokeBlobIfAny();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('evidence_pdf_viewer'),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              'Memuat pratinjau dokumen PDF…',
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_sourceUrl == null) {
      return Container(
        key: const Key('evidence_pdf_fallback_view'),
        constraints: const BoxConstraints(maxWidth: 380),
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
              Icons.picture_as_pdf_rounded,
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
              _errorMessage ?? 'Preview PDF belum tersedia.',
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
