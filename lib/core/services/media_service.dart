import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:kitatemani/core/services/file_bytes_helper.dart';
import 'package:kitatemani/core/services/web_document_picker.dart';

enum EvidenceKind {
  foto('foto'),
  video('video'),
  suara('suara'),
  file('file');

  const EvidenceKind(this.wireValue);
  final String wireValue;
}

enum DocumentPickError {
  unsupportedFormat,
  fileTooLarge,
  emptyFile,
  readFailed,
}

class DocumentPickResult {
  const DocumentPickResult._({this.evidence, this.error, this.errorMessage});
  const DocumentPickResult.cancelled() : this._();
  const DocumentPickResult.success(PickedEvidence evidence)
      : this._(evidence: evidence);
  const DocumentPickResult.failure(
    DocumentPickError error,
    String message,
  ) : this._(error: error, errorMessage: message);

  final PickedEvidence? evidence;
  final DocumentPickError? error;
  final String? errorMessage;

  bool get isSuccess => evidence != null;
  bool get isCancelled => evidence == null && error == null;
}

class PickedEvidence {
  const PickedEvidence({
    required this.fileName,
    required this.kind,
    this.localPath,
    this.bytes,
    this.sizeBytes,
    this.exifStripped = true,
  });

  final String fileName;
  final EvidenceKind kind;
  final String? localPath;
  final Uint8List? bytes;
  final int? sizeBytes;
  final bool exifStripped;
}

class MediaService {
  MediaService({
    ImagePicker? picker,
    MethodChannel? filePickerChannel,
  })  : _picker = picker ?? ImagePicker(),
        _filePickerChannel = filePickerChannel ??
            const MethodChannel('id.kitatemani/file_picker');

  static const int maxEvidenceDocumentBytes = 2 * 1024 * 1024;
  static const Set<String> allowedEvidenceDocumentExtensions = {'pdf', 'docx'};
  static const List<String> allowedEvidenceDocumentMimeTypes = [
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ];

  final ImagePicker _picker;
  final MethodChannel _filePickerChannel;

  static DocumentPickResult validateEvidenceDocument({
    required String fileName,
    Uint8List? bytes,
    int? sizeBytes,
    String? localPath,
  }) {
    final trimmedName = fileName.trim();
    final dotIdx = trimmedName.lastIndexOf('.');
    final ext =
        dotIdx >= 0 ? trimmedName.substring(dotIdx + 1).toLowerCase() : '';
    if (!allowedEvidenceDocumentExtensions.contains(ext)) {
      return const DocumentPickResult.failure(
        DocumentPickError.unsupportedFormat,
        'Format file tidak didukung. Hanya file PDF atau DOCX yang diperbolehkan.',
      );
    }

    final effectiveSize = sizeBytes ?? bytes?.length ?? 0;
    if (effectiveSize > maxEvidenceDocumentBytes) {
      final sizeMb = (effectiveSize / (1024 * 1024)).toStringAsFixed(2);
      return DocumentPickResult.failure(
        DocumentPickError.fileTooLarge,
        'Ukuran file $sizeMb MB melebihi batas maksimal 2 MB.',
      );
    }

    if (effectiveSize <= 0) {
      return const DocumentPickResult.failure(
        DocumentPickError.emptyFile,
        'File lampiran kosong dan tidak dapat diunggah.',
      );
    }

    return DocumentPickResult.success(
      PickedEvidence(
        fileName: trimmedName,
        kind: EvidenceKind.file,
        localPath: localPath,
        bytes: bytes,
        sizeBytes: effectiveSize,
        exifStripped: false,
      ),
    );
  }

  Future<DocumentPickResult> pickEvidenceDocument() async {
    if (kIsWeb) {
      try {
        final raw = await pickWebDocument(
          maxBytes: maxEvidenceDocumentBytes,
          accept:
              '.pdf,.docx,application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
        if (raw == null) {
          return const DocumentPickResult.cancelled();
        }
        final result = validateEvidenceDocument(
          fileName: raw.fileName,
          bytes: raw.bytes,
          sizeBytes: raw.sizeBytes,
        );
        if (result.isSuccess && (raw.bytes == null || raw.bytes!.isEmpty)) {
          return const DocumentPickResult.failure(
            DocumentPickError.readFailed,
            'Gagal membaca isi file lampiran.',
          );
        }
        return result;
      } on Object {
        return const DocumentPickResult.failure(
          DocumentPickError.readFailed,
          'Gagal membuka pemilih file PDF/DOCX.',
        );
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final raw = await _filePickerChannel.invokeMapMethod<String, dynamic>(
          'pickDocument',
          {
            'mimeTypes': allowedEvidenceDocumentMimeTypes,
            'extensions': allowedEvidenceDocumentExtensions.toList(),
            'maxBytes': maxEvidenceDocumentBytes,
          },
        );
        if (raw == null) {
          return const DocumentPickResult.cancelled();
        }

        final errorCode = raw['error']?.toString();
        if (errorCode == 'UNSUPPORTED_FORMAT') {
          return const DocumentPickResult.failure(
            DocumentPickError.unsupportedFormat,
            'Format file tidak didukung. Hanya file PDF atau DOCX yang diperbolehkan.',
          );
        }
        if (errorCode == 'FILE_TOO_LARGE') {
          final size = (raw['size'] as num?)?.toInt();
          final message = size != null
              ? 'Ukuran file ${(size / (1024 * 1024)).toStringAsFixed(2)} MB melebihi batas maksimal 2 MB.'
              : 'Ukuran file melebihi batas maksimal 2 MB.';
          return DocumentPickResult.failure(
            DocumentPickError.fileTooLarge,
            message,
          );
        }
        if (errorCode == 'EMPTY_FILE') {
          return const DocumentPickResult.failure(
            DocumentPickError.emptyFile,
            'File lampiran kosong dan tidak dapat diunggah.',
          );
        }
        if (errorCode != null) {
          return const DocumentPickResult.failure(
            DocumentPickError.readFailed,
            'Gagal membaca berkas lampiran.',
          );
        }

        final name = (raw['name'] ?? '').toString();
        final localPath = raw['path']?.toString();
        final reportedSize = (raw['size'] as num?)?.toInt();
        final bytes = await readFileBytes(localPath);
        return validateEvidenceDocument(
          fileName: name,
          bytes: bytes,
          sizeBytes: bytes?.length ?? reportedSize,
          localPath: localPath,
        );
      } on MissingPluginException {
        return const DocumentPickResult.failure(
          DocumentPickError.readFailed,
          'Pemilih dokumen PDF/DOCX belum tersedia di perangkat ini.',
        );
      } on Object {
        return const DocumentPickResult.failure(
          DocumentPickError.readFailed,
          'Gagal memilih file PDF/DOCX dari perangkat.',
        );
      }
    }

    return const DocumentPickResult.failure(
      DocumentPickError.readFailed,
      'Pemilih dokumen PDF/DOCX belum tersedia di perangkat ini.',
    );
  }

  /// Re-encodes JPEG/PNG bytes via package:image to strip camera/GPS EXIF tags.
  Uint8List stripExifBytes(Uint8List rawBytes) => _stripExifIsolate(rawBytes);

  /// Offloads EXIF stripping to a background worker via [compute] so the UI
  /// isolate stays responsive on large camera photos.
  Future<Uint8List> stripExifBytesAsync(Uint8List rawBytes) =>
      compute(_stripExifIsolate, rawBytes);

  /// Resizes an image to fit inside [maxDimension] and strips EXIF metadata
  /// so avatar uploads stay lightweight and privacy-safe.
  Uint8List resizeAvatarBytes(Uint8List rawBytes, {int maxDimension = 320}) =>
      _resizeAvatarIsolate((bytes: rawBytes, maxDimension: maxDimension));

  /// Offloads avatar decode/resize/re-encode to a background worker.
  Future<Uint8List> resizeAvatarBytesAsync(
    Uint8List rawBytes, {
    int maxDimension = 320,
  }) =>
      compute(_resizeAvatarIsolate, (bytes: rawBytes, maxDimension: maxDimension));

  Future<PickedEvidence?> pickAvatarImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 85,
      );
      if (picked == null) return null;
      final rawBytes = await picked.readAsBytes();
      final compact = await resizeAvatarBytesAsync(rawBytes);
      final name = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final cleanPath = kIsWeb ? null : await writeTempBytes(name, compact);
      return PickedEvidence(
        fileName: name,
        kind: EvidenceKind.foto,
        localPath: cleanPath,
        bytes: compact,
        exifStripped: true,
      );
    } on Object {
      return null;
    }
  }

  Future<PickedEvidence?> _processPickedImage(
      XFile? file, String prefix) async {
    if (file == null) return null;
    try {
      final rawBytes = await file.readAsBytes();
      final strippedBytes = await stripExifBytesAsync(rawBytes);
      final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final cleanPath =
          kIsWeb ? null : await writeTempBytes(name, strippedBytes);
      return PickedEvidence(
        fileName: name,
        kind: EvidenceKind.foto,
        localPath: cleanPath,
        bytes: strippedBytes,
        exifStripped: true,
      );
    } on Object {
      return PickedEvidence(
        fileName: file.name,
        kind: EvidenceKind.foto,
        localPath: kIsWeb ? null : file.path,
        exifStripped: true,
      );
    }
  }

  Future<PickedEvidence?> capturePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 88,
      );
      return _processPickedImage(picked, 'foto_kamera');
    } on Object {
      return null;
    }
  }

  Future<PickedEvidence?> pickGalleryImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      return _processPickedImage(picked, 'galeri_bukti');
    } on Object {
      return null;
    }
  }

  Future<PickedEvidence?> pickAnyFile() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final raw = await _filePickerChannel.invokeMapMethod<String, dynamic>(
          'pickDocument',
        );
        if (raw == null) return null;
        final name = (raw['name'] ?? 'lampiran').toString();
        final localPath = raw['path']?.toString();
        final ext =
            name.contains('.') ? name.split('.').last.toLowerCase() : '';
        final kind = switch (ext) {
          'jpg' || 'jpeg' || 'png' => EvidenceKind.foto,
          'mp4' ||
          'mov' ||
          'webm' ||
          'm4v' ||
          'mkv' ||
          '3gp' =>
            EvidenceKind.video,
          'm4a' || 'mp3' || 'wav' => EvidenceKind.suara,
          _ => EvidenceKind.file,
        };

        Uint8List? bytes;
        if (kind == EvidenceKind.foto && localPath != null) {
          final rawBytes = await readFileBytes(localPath);
          if (rawBytes != null) {
            bytes = await stripExifBytesAsync(rawBytes);
            await writeTempBytes('clean_$name', bytes);
          }
        }

        return PickedEvidence(
          fileName: name,
          kind: kind,
          localPath: localPath,
          bytes: bytes,
          exifStripped: kind == EvidenceKind.foto,
        );
      } on MissingPluginException {
        // Fallback to ImagePicker media if running outside native Android host.
      } on Object {
        return null;
      }
    }

    try {
      final media = await _picker.pickMedia();
      if (media == null) return null;
      final name = media.name;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final isVideoMime =
          media.mimeType?.toLowerCase().startsWith('video/') ?? false;
      const videoExtensions = {
        'mp4',
        'mov',
        'webm',
        'm4v',
        'mkv',
        'ogv',
        '3gp',
      };
      if (isVideoMime || videoExtensions.contains(ext)) {
        final rawBytes = await media.readAsBytes();
        return PickedEvidence(
          fileName: name,
          kind: EvidenceKind.video,
          localPath: kIsWeb ? null : media.path,
          bytes: rawBytes,
          exifStripped: false,
        );
      }
      return _processPickedImage(media, 'lampiran');
    } on Object {
      return null;
    }
  }

  String toBase64(Uint8List bytes) => _encodeBase64Isolate(bytes);

  /// Offloads base64 encoding of large image payloads to [compute].
  Future<String> toBase64Async(Uint8List bytes) =>
      compute(_encodeBase64Isolate, bytes);
}

Uint8List _stripExifIsolate(Uint8List rawBytes) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
  } on Object {
    return rawBytes;
  }
}

Uint8List _resizeAvatarIsolate(({Uint8List bytes, int maxDimension}) args) {
  try {
    final decoded = img.decodeImage(args.bytes);
    if (decoded == null) return args.bytes;
    final resized =
        (decoded.width > args.maxDimension || decoded.height > args.maxDimension)
            ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height
                    ? args.maxDimension
                    : null,
                height: decoded.height > decoded.width
                    ? args.maxDimension
                    : null,
              )
            : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  } on Object {
    return args.bytes;
  }
}

String _encodeBase64Isolate(Uint8List bytes) => base64Encode(bytes);

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());
