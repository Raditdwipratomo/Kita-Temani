import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/file_bytes_helper.dart';
import 'package:kitatemani/core/utils/evidence_link_parser.dart';
import 'package:video_player/video_player.dart';

/// Native video player for Android, desktop, and VM tests using `video_player`.
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
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isMuted = false;
  String? _errorMessage;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    unawaited(_initController());
  }

  Future<void> _initController() async {
    try {
      VideoPlayerController? controller;
      final localPath = widget.localPath?.trim() ?? '';
      if (localPath.isNotEmpty) {
        final file = File(localPath);
        if (file.existsSync()) {
          controller = VideoPlayerController.file(file);
        }
      }

      final bytes = widget.bytes;
      if (controller == null && bytes != null && bytes.isNotEmpty) {
        final safeName = widget.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final writtenPath = await writeTempBytes(
          'play_${DateTime.now().microsecondsSinceEpoch}_$safeName',
          bytes,
        ).timeout(const Duration(seconds: 3));
        if (writtenPath != null && writtenPath.isNotEmpty) {
          _tempFilePath = writtenPath;
          controller = VideoPlayerController.file(File(writtenPath));
        }
      }

      final networkUrl = widget.networkUrl?.trim() ?? '';
      if (controller == null && networkUrl.isNotEmpty) {
        final uri = Uri.tryParse(networkUrl);
        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
          controller = VideoPlayerController.networkUrl(uri);
        }
      }

      if (controller == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'File video tidak ditemukan atau belum diunggah ke perangkat ini.';
        });
        return;
      }

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_onPlayerUpdated);
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Pemutar video tidak dapat memuat file ini di perangkat ini.';
      });
    }
  }

  void _onPlayerUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration &&
          controller.value.duration > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    if (mounted) {
      setState(() => _isMuted = nextMuted);
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerUpdated);
      unawaited(controller.dispose());
    }
    final tempPath = _tempFilePath;
    if (tempPath != null) {
      try {
        final file = File(tempPath);
        if (file.existsSync()) file.deleteSync();
      } on Object {
        // Ignore cleanup errors on temporary cache files.
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('evidence_video_player'),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101322),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
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
            const Icon(Icons.videocam_rounded, size: 46, color: Colors.white70),
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
              _errorMessage ?? 'Video siap diputar.',
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

    final value = controller.value;
    final ratio = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 520),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: () => unawaited(_togglePlayPause()),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      if (!value.isPlaying)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              color: const Color(0xFF141829),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: value.isPlaying ? 'Jeda' : 'Putar',
                    onPressed: () => unawaited(_togglePlayPause()),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: AppTextStyles.inter(
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      colors: const VideoProgressColors(
                        playedColor: AppColors.biruMuda,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: _isMuted ? 'Bunyikan' : 'Bisukan',
                    onPressed: () => unawaited(_toggleMute()),
                    icon: Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
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
}

/// Interactive preview card on native/IO platforms for YouTube & Google Drive
/// video links with one-tap playback via external app/browser.
class EvidenceEmbedPlayer extends StatelessWidget {
  const EvidenceEmbedPlayer({
    required this.parsed,
    required this.onOpenExternal,
    super.key,
  });

  final ParsedEvidenceLink parsed;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final isYouTube = parsed.kind == EvidenceLinkKind.youtube;
    final thumbUrl = parsed.thumbnailUrl;
    final buttonLabel =
        isYouTube ? 'Putar di YouTube' : 'Putar di Google Drive';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          key: const Key('evidence_embed_player'),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF151A30), Color(0xFF232B4D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpenExternal,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isYouTube && thumbUrl != null)
                  Image.network(
                    thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isYouTube
                              ? const Color(0xFFE53935)
                              : AppColors.biruTinta,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: onOpenExternal,
                        icon: const Icon(Icons.play_circle_filled_rounded),
                        label: Text(buttonLabel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.inkNavy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
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
