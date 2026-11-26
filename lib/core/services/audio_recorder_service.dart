import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

abstract interface class AudioRecorderService {
  bool get isRecording;
  Future<void> start();
  Future<String?> stop();
}

class RecordAudioRecorderService implements AudioRecorderService {
  AudioRecorder? _recorder;
  bool _recording = false;
  String? _currentPath;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    if (!_isMobilePlatform) {
      _recording = true;
      _currentPath =
          'simulated_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      return;
    }
    try {
      _recorder ??= AudioRecorder();
      final hasPerm = await _recorder!.hasPermission();
      if (!hasPerm) {
        _recording = false;
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/panic_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: outPath,
      );
      _currentPath = outPath;
      _recording = true;
    } on Object {
      // Keep panic workflow non-blocking even if microphone cannot start.
      _recording = false;
    }
  }

  @override
  Future<String?> stop() async {
    if (!_recording) return _currentPath;
    _recording = false;
    if (_recorder != null) {
      try {
        final savedPath = await _recorder!.stop();
        return savedPath ?? _currentPath;
      } on Object {
        return _currentPath;
      }
    }
    return _currentPath;
  }
}

class DummyAudioRecorderService implements AudioRecorderService {
  bool _recording = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _recording = true;
  }

  @override
  Future<String?> stop() async {
    if (!_recording) return null;
    _recording = false;
    return 'local://emergency_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }
}

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return RecordAudioRecorderService();
});
