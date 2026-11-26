import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/utils/evidence_link_parser.dart';
import 'package:web/web.dart' as web;

int _nextWebMediaViewId = 0;

/// Interactive HTML5 video player for Flutter Web supporting uploaded bytes,
/// local blob/object URLs, and signed/public remote URLs.
class EvidenceVideoPlayer extends StatefulWidget {
  const EvidenceVideoPlayer({
    required this.fileName,
    this.bytes,
    this.localPath,
    this.networkUrl,
    this.mimeType = 'video/mp4',
    super.key,
  });

  final String fileName;
  final Uint8List? bytes;
  final String? localPath;
  final String? networkUrl;
  final String mimeType;

  @override
  State<EvidenceVideoPlayer> createState() => _EvidenceVideoPlayerState();
}

class _EvidenceVideoPlayerState extends State<EvidenceVideoPlayer> {
  late final String _viewType;
  String? _blobUrl;
  String? _sourceUrl;
  web.HTMLVideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'kt-evidence-video-${_nextWebMediaViewId++}';
    _sourceUrl = _resolveSourceUrl();
    final source = _sourceUrl;
    if (source != null) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final element = web.HTMLVideoElement()
          ..src = source
          ..controls = true
          ..playsInline = true
          ..preload = 'metadata';
        element.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = 'contain'
          ..backgroundColor = '#000000'
          ..borderRadius = '14px';
        _videoElement = element;
        return element;
      });
    }
  }

  String? _resolveSourceUrl() {
    final bytes = widget.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final blob = web.Blob(
        <web.BlobPart>[bytes.toJS].toJS,
        web.BlobPropertyBag(type: widget.mimeType),
      );
      _blobUrl = web.URL.createObjectURL(blob);
      return _blobUrl;
    }

    final remote = widget.networkUrl?.trim() ?? '';
    if (remote.isNotEmpty) {
      return remote;
    }

    final local = widget.localPath?.trim() ?? '';
    if (local.startsWith('http://') ||
        local.startsWith('https://') ||
        local.startsWith('blob:')) {
      return local;
    }
    return null;
  }

  @override
  void dispose() {
    final video = _videoElement;
    if (video != null) {
      video.pause();
      video.removeAttribute('src');
      video.load();
      _videoElement = null;
    }
    final blobUrl = _blobUrl;
    if (blobUrl != null) {
      web.URL.revokeObjectURL(blobUrl);
      _blobUrl = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sourceUrl == null) {
      return Container(
        key: const Key('evidence_video_player'),
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
            const Icon(
              Icons.videocam_off_outlined,
              size: 46,
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
              'Sumber video belum tersedia di perangkat atau browser ini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(
                fontSize: 12.5,
                color: Colors.white70,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 520),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          key: const Key('evidence_video_player'),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          clipBehavior: Clip.antiAlias,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}

/// Embedded iframe player on Flutter Web for YouTube and Google Drive previews.
class EvidenceEmbedPlayer extends StatefulWidget {
  const EvidenceEmbedPlayer({
    required this.parsed,
    required this.onOpenExternal,
    super.key,
  });

  final ParsedEvidenceLink parsed;
  final VoidCallback onOpenExternal;

  @override
  State<EvidenceEmbedPlayer> createState() => _EvidenceEmbedPlayerState();
}

class _EvidenceEmbedPlayerState extends State<EvidenceEmbedPlayer> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _viewType = 'kt-evidence-embed-${_nextWebMediaViewId++}';
    final embedUrl = widget.parsed.embedUrl;
    if (embedUrl != null && embedUrl.isNotEmpty) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final iframe = web.HTMLIFrameElement()
          ..src = embedUrl
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen'
          ..allowFullscreen = true
          ..referrerPolicy = 'strict-origin-when-cross-origin';
        iframe.style
          ..width = '100%'
          ..height = '100%'
          ..border = 'none'
          ..borderRadius = '14px'
          ..backgroundColor = '#0B0E1A';
        _iframeElement = iframe;
        return iframe;
      });
    }
  }

  @override
  void dispose() {
    final iframe = _iframeElement;
    if (iframe != null) {
      iframe.src = 'about:blank';
      _iframeElement = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final embedUrl = widget.parsed.embedUrl;
    if (embedUrl == null || embedUrl.isEmpty) {
      return Container(
        key: const Key('evidence_embed_player'),
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
            const Icon(
              Icons.open_in_new_rounded,
              size: 42,
              color: Colors.white70,
            ),
            const SizedBox(height: 12),
            Text(
              'Pratinjau tersemat tidak tersedia untuk tautan ini.',
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: widget.onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Buka di tab baru'),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 540),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          key: const Key('evidence_embed_player'),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0E1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          clipBehavior: Clip.antiAlias,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
