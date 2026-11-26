import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/app/router/routes.dart';
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/media_service.dart';
import 'package:kitatemani/core/services/permission_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';
import 'package:kitatemani/core/widgets/app_button.dart';
import 'package:kitatemani/features/report/presentation/controllers/submit_report_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CameraMode { foto, video, liveAi }

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({
    this.returnPickedOnly = false,
    super.key,
  });

  final bool returnPickedOnly;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraMode _mode = CameraMode.foto;
  List<CameraDescription> _cameras = const [];
  int _selectedCameraIndex = 0;
  CameraController? _cameraController;
  FlashMode _flashMode = FlashMode.auto;

  bool _isInitializing = true;
  bool _permissionDenied = false;
  String? _cameraError;

  bool _isRecording = false;
  final ValueNotifier<int> _recordSeconds = ValueNotifier<int>(0);
  Timer? _recordTimer;
  PickedEvidence? _capturedEvidence;

  bool _isAnalyzingAi = false;
  List<String> _aiIndications = const [];
  String? _aiError;
  String _aiDisclaimer =
      'Disclaimer: Hasil analisis AI hanya informasi awal dan bukan keputusan akhir.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initDeviceCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_startCameraAtIndex(_selectedCameraIndex));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _recordSeconds.dispose();
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  Future<void> _initDeviceCamera() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _permissionDenied = false;
      _cameraError = null;
    });

    // On mobile, explicitly request OS Camera (+ Mic) permission first.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final permService = ref.read(permissionServiceProvider);
      final camGranted = await permService.request(AppPermission.camera);
      await permService.request(AppPermission.microphone);
      if (!camGranted) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _permissionDenied = true;
          _cameraError =
              'Izin akses kamera dibutuhkan agar kamera dapat terbuka langsung.';
        });
        return;
      }
    }

    try {
      // On Chrome Web (camera_web), availableCameras() + initialize() prompts the browser's native camera permission dialog.
      final cameras =
          await availableCameras().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _cameraError = 'Tidak ditemukan kamera aktif pada perangkat ini.';
        });
        return;
      }

      final backIdx = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _cameras = cameras;
      _selectedCameraIndex = backIdx >= 0 ? backIdx : 0;
      await _startCameraAtIndex(_selectedCameraIndex);
    } on CameraException catch (e) {
      if (!mounted) return;
      final lowerCode = e.code.toLowerCase();
      final lowerDesc = (e.description ?? '').toLowerCase();
      final denied = lowerCode.contains('denied') ||
          lowerCode.contains('permission') ||
          lowerCode.contains('notallowed') ||
          lowerDesc.contains('permission') ||
          lowerDesc.contains('notallowed') ||
          lowerDesc.contains('denied');
      setState(() {
        _isInitializing = false;
        _permissionDenied = denied;
        _cameraError = denied
            ? 'Akses kamera ditolak. Klik tombol di bawah untuk mengizinkan kamera di perangkat/browser.'
            : (e.description ?? 'Kamera tidak dapat dibuka (${e.code}).');
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraError =
            'Kamera perangkat tidak tersedia pada lingkungan ini. Kamu masih bisa memilih foto dari galeri.';
      });
    }
  }

  Future<void> _startCameraAtIndex(
    int index, {
    bool enableAudio = true,
  }) async {
    if (_cameras.isEmpty) return;
    final safeIdx = index.clamp(0, _cameras.length - 1);
    final prev = _cameraController;
    _cameraController = null;
    if (prev != null) {
      await prev.dispose();
    }

    final controller = CameraController(
      _cameras[safeIdx],
      ResolutionPreset.high,
      enableAudio: enableAudio,
    );

    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (!kIsWeb) {
        try {
          await controller.setFlashMode(_flashMode);
        } on Object {
          // Ignore unsupported flash hardware cleanly.
        }
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _selectedCameraIndex = safeIdx;
        _isInitializing = false;
        _permissionDenied = false;
        _cameraError = null;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      final lowerCode = e.code.toLowerCase();
      final lowerDesc = (e.description ?? '').toLowerCase();
      final denied = lowerCode.contains('denied') ||
          lowerCode.contains('permission') ||
          lowerCode.contains('notallowed') ||
          lowerDesc.contains('permission') ||
          lowerDesc.contains('notallowed') ||
          lowerDesc.contains('denied');
      // On desktop webcams without a microphone, retry with video-only so camera still opens.
      if (enableAudio && !denied && mounted) {
        await _startCameraAtIndex(safeIdx, enableAudio: false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _permissionDenied = denied;
        _cameraError = denied
            ? 'Izin kamera ditolak oleh perangkat/browser. Aktifkan izin kamera lalu coba lagi.'
            : (e.description ?? 'Gagal menginisialisasi kamera (${e.code}).');
      });
    } on Object catch (e) {
      await controller.dispose();
      if (enableAudio && mounted) {
        await _startCameraAtIndex(safeIdx, enableAudio: false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _cameraError = 'Gagal membuka kamera: $e';
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    setState(() => _isInitializing = true);
    final nextIdx = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCameraAtIndex(nextIdx);
  }

  Future<void> _cycleFlash() async {
    if (kIsWeb || _cameraController == null) return;
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.torch,
      FlashMode.torch => FlashMode.off,
      _ => FlashMode.auto,
    };
    try {
      await _cameraController!.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on Object {
      // Ignore if lens has no flash.
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ref.read(mediaServiceProvider).pickGalleryImage();
    if (picked == null || !mounted) return;
    setState(() {
      _capturedEvidence = picked;
      _aiIndications = const [];
      _aiError = null;
    });
    if (_mode == CameraMode.liveAi) {
      await _analyzeWithQwen(picked);
    }
  }

  Future<void> _captureOrToggleRecord() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      await _initDeviceCamera();
      return;
    }

    final media = ref.read(mediaServiceProvider);

    if (_mode == CameraMode.video) {
      if (_isRecording) {
        _recordTimer?.cancel();
        try {
          final recorded = await controller.stopVideoRecording();
          final rawBytes = await recorded.readAsBytes();
          if (!mounted) return;
          setState(() {
            _isRecording = false;
            _capturedEvidence = PickedEvidence(
              fileName:
                  'video_bukti_${DateTime.now().millisecondsSinceEpoch}.mp4',
              kind: EvidenceKind.video,
              localPath: kIsWeb ? null : recorded.path,
              bytes: rawBytes,
              exifStripped: false,
            );
          });
        } on Object catch (e) {
          if (!mounted) return;
          setState(() => _isRecording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghentikan rekaman: $e')),
          );
        }
      } else {
        try {
          await controller.startVideoRecording();
          if (!mounted) return;
          _recordSeconds.value = 0;
          setState(() {
            _isRecording = true;
            _capturedEvidence = null;
          });
          _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) _recordSeconds.value++;
          });
        } on Object catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mulai merekam video: $e')),
          );
        }
      }
      return;
    }

    // Foto or Live AI mode: real capture from live camera stream
    try {
      final shot = await controller.takePicture();
      final rawBytes = await shot.readAsBytes();
      final cleanBytes = await media.stripExifBytesAsync(rawBytes);
      if (!mounted) return;
      final name = 'foto_bukti_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final captured = PickedEvidence(
        fileName: name,
        kind: EvidenceKind.foto,
        localPath: kIsWeb ? null : shot.path,
        bytes: cleanBytes,
        exifStripped: true,
      );
      if (!mounted) return;
      setState(() {
        _capturedEvidence = captured;
        _aiIndications = const [];
        _aiError = null;
      });
      if (_mode == CameraMode.liveAi) {
        await _analyzeWithQwen(captured);
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  Future<void> _analyzeWithQwen(PickedEvidence evidence) async {
    if (evidence.bytes == null || evidence.bytes!.isEmpty) return;
    setState(() {
      _isAnalyzingAi = true;
      _aiIndications = const [];
      _aiError = null;
    });

    final client = ref.read(supabaseClientProvider);
    final connected = await ref.read(connectivityServiceProvider).isConnected;
    if (client == null || !connected) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _aiError =
            'Tidak terhubung ke server AI Qwen (OpenRouter). Periksa koneksi internetmu.';
      });
      return;
    }

    try {
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      if (!mounted) return;
      final base64Img =
          await ref.read(mediaServiceProvider).toBase64Async(evidence.bytes!);
      if (!mounted) return;
      final res = await client.functions.invoke(
        'analyze-image',
        body: {'image_base64': base64Img},
      );
      final data = res.data;
      if (data is Map && mounted) {
        final list = (data['indications'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
        setState(() {
          _isAnalyzingAi = false;
          _aiIndications = list.isNotEmpty
              ? list
              : const ['Tidak ditemukan indikasi visual bullying yang jelas.'];
          if (data['disclaimer'] != null) {
            _aiDisclaimer = 'Disclaimer: ${data['disclaimer']}';
          }
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _aiError = 'Respons analisis dari AI Qwen kosong.';
      });
    } on FunctionException catch (e) {
      if (!mounted) return;
      final details = e.details;
      final msg = details is Map && details['message'] is String
          ? details['message'] as String
          : 'Gagal menganalisis gambar (HTTP ${e.status}).';
      setState(() {
        _isAnalyzingAi = false;
        _aiError = msg;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzingAi = false;
        _aiError = 'Gagal menghubungi AI Qwen: $e';
      });
    }
  }

  Future<void> _attachToReport() async {
    final evidence = _capturedEvidence;
    if (evidence == null) return;

    if (widget.returnPickedOnly) {
      if (!mounted) return;
      Navigator.of(context).pop(evidence);
      return;
    }

    ref
        .read(submitReportControllerProvider.notifier)
        .addPickedEvidence(evidence);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bukti "${evidence.fileName}" dilampirkan ke draf laporan.',
        ),
      ),
    );
    await Navigator.of(context).pushReplacementNamed(AppRoutes.reportType);
  }

  Widget _buildFullScreenFeed() {
    final evidence = _capturedEvidence;
    if (evidence != null) {
      if (evidence.kind == EvidenceKind.foto && evidence.bytes != null) {
        final cacheW = (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
        return Positioned.fill(
          child: Image.memory(
            evidence.bytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: cacheW > 0 ? cacheW : null,
          ),
        );
      }
      return Positioned.fill(
        child: Container(
          color: const Color(0xFF101322),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_rounded,
                size: 56,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'Video berhasil direkam (${DateFormatter.durationMmSs(_recordSeconds.value)})',
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                evidence.fileName,
                style: AppTextStyles.inter(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      final previewSize = controller.value.previewSize;
      final previewWidth =
          kIsWeb ? (previewSize?.width ?? 1280) : (previewSize?.height ?? 720);
      final previewHeight =
          kIsWeb ? (previewSize?.height ?? 720) : (previewSize?.width ?? 1280);
      return Positioned.fill(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Positioned.fill(
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Membuka kamera perangkat...',
                style: AppTextStyles.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Izinkan akses kamera & mikrofon jika diminta.',
                style: AppTextStyles.inter(
                  fontSize: 12.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _permissionDenied
                  ? 'Izin Kamera Diperlukan'
                  : 'Kamera Tidak Dapat Dibuka',
              textAlign: TextAlign.center,
              style: AppTextStyles.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _cameraError ??
                  'Berikan izin kamera agar kamu dapat langsung mengambil foto atau video bukti.',
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(
                fontSize: 13,
                color: Colors.white70,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: _permissionDenied
                  ? 'Izinkan Akses Kamera'
                  : 'Coba Buka Kamera Lagi',
              icon: Icons.camera_alt_rounded,
              onPressed: () async {
                if (_permissionDenied && !kIsWeb) {
                  await ref.read(permissionServiceProvider).openSettings();
                }
                await _initDeviceCamera();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Pilih Foto dari Galeri'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                minimumSize: const Size(double.infinity, 48),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _capturedEvidence != null;
    final isLive = _cameraController != null &&
        _cameraController!.value.isInitialized &&
        !hasPreview;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildFullScreenFeed(),

          // Top gradient scrim + TikTok/IG style floating header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Tutup kamera',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? AppColors.danger
                              : Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isRecording
                                  ? Icons.fiber_manual_record
                                  : (_mode == CameraMode.liveAi
                                      ? Icons.auto_awesome_rounded
                                      : Icons.verified_user_outlined),
                              size: 13,
                              color: _mode == CameraMode.liveAi && !_isRecording
                                  ? const Color(0xFFF6BE4F)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            if (_isRecording)
                              RepaintBoundary(
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _recordSeconds,
                                  builder: (_, seconds, __) => Text(
                                    'REC ${DateFormatter.durationMmSs(seconds)}',
                                    style: AppTextStyles.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                _mode == CameraMode.liveAi
                                    ? 'Live AI · Qwen'
                                    : 'EXIF Dihapus Otomatis',
                                style: AppTextStyles.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isLive && !kIsWeb) ...[
                        _GlassIconButton(
                          icon: switch (_flashMode) {
                            FlashMode.torch => Icons.flash_on_rounded,
                            FlashMode.off => Icons.flash_off_rounded,
                            _ => Icons.flash_auto_rounded,
                          },
                          tooltip: 'Flash',
                          onTap: _cycleFlash,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isLive && _cameras.length > 1)
                        _GlassIconButton(
                          icon: Icons.cameraswitch_rounded,
                          tooltip: 'Balik kamera',
                          onTap: _flipCamera,
                        )
                      else
                        const SizedBox(width: 42),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom gradient scrim + AI panel + shutter / review controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_mode == CameraMode.liveAi &&
                          (hasPreview || _isAnalyzingAi)) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFF6BE4F),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Analisis Live AI (Qwen · OpenRouter)',
                                    style: AppTextStyles.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_isAnalyzingAi) ...[
                                    const Spacer(),
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (_isAnalyzingAi)
                                Text(
                                  'Menganalisis foto dengan model Qwen...',
                                  style: AppTextStyles.inter(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                )
                              else if (_aiError != null)
                                Text(
                                  _aiError!,
                                  style: AppTextStyles.inter(
                                    fontSize: 12,
                                    color: const Color(0xFFFFB4B4),
                                    height: 1.4,
                                  ),
                                )
                              else
                                for (final line in _aiIndications)
                                  Text(
                                    '• $line',
                                    style: AppTextStyles.inter(
                                      fontSize: 12,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                              const SizedBox(height: 4),
                              Text(
                                _aiDisclaimer,
                                style: AppTextStyles.inter(
                                  fontSize: 10.5,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (hasPreview)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  _capturedEvidence = null;
                                  _aiIndications = const [];
                                  _aiError = null;
                                }),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  minimumSize: const Size(0, 50),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text('Ulangi'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: AppButton(
                                label: 'Lampirkan ke Laporan',
                                icon: Icons.attach_file_rounded,
                                onPressed: _attachToReport,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        // TikTok/IG style Mode selector pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final entry in [
                              (CameraMode.foto, 'FOTO'),
                              (CameraMode.video, 'VIDEO'),
                              (CameraMode.liveAi, 'LIVE AI'),
                            ])
                              GestureDetector(
                                onTap: _isRecording
                                    ? null
                                    : () => setState(() => _mode = entry.$1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        entry.$2,
                                        style: AppTextStyles.poppins(
                                          fontSize: 12.5,
                                          fontWeight: _mode == entry.$1
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: _mode == entry.$1
                                              ? Colors.white
                                              : Colors.white60,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: _mode == entry.$1
                                              ? Colors.white
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Shutter bar: Gallery | Shutter | Flip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _GlassIconButton(
                              icon: Icons.photo_library_outlined,
                              tooltip: 'Pilih dari galeri',
                              size: 48,
                              onTap: _isRecording ? null : _pickFromGallery,
                            ),
                            GestureDetector(
                              onTap: isLive ? _captureOrToggleRecord : null,
                              child: Container(
                                width: 78,
                                height: 78,
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (_mode == CameraMode.liveAi
                                            ? AppColors.biruTinta
                                            : Colors.white)
                                        .withValues(alpha: isLive ? 1 : 0.45),
                                    width: 4,
                                  ),
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  margin: EdgeInsets.all(
                                    _isRecording ? 14 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (_mode == CameraMode.video
                                            ? AppColors.danger
                                            : (_mode == CameraMode.liveAi
                                                ? AppColors.biruTinta
                                                : Colors.white))
                                        .withValues(alpha: isLive ? 1 : 0.45),
                                    borderRadius: BorderRadius.circular(
                                      _isRecording ? 8 : 40,
                                    ),
                                  ),
                                  child: _mode == CameraMode.liveAi
                                      ? Icon(
                                          Icons.auto_awesome_rounded,
                                          color: Colors.white.withValues(
                                            alpha: isLive ? 1 : 0.45,
                                          ),
                                          size: 28,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            _GlassIconButton(
                              icon: Icons.cameraswitch_rounded,
                              tooltip: 'Balik kamera',
                              size: 48,
                              onTap: (isLive && _cameras.length > 1)
                                  ? _flipCamera
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ],
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 42,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: enabled ? 0.42 : 0.42 * 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}
