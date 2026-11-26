enum EvidenceLinkKind {
  youtube,
  googleDrive,
  googleDriveFolder,
  directVideo,
  directPdf,
  directDocx,
  externalLink,
}

class ParsedEvidenceLink {
  const ParsedEvidenceLink({
    required this.rawUrl,
    required this.normalizedUrl,
    required this.kind,
    this.embedUrl,
    this.mediaId,
    this.thumbnailUrl,
    this.mimeType = 'text/html',
  });

  final String rawUrl;
  final String normalizedUrl;
  final EvidenceLinkKind kind;
  final String? embedUrl;
  final String? mediaId;
  final String? thumbnailUrl;
  final String mimeType;

  bool get isPlayable =>
      kind == EvidenceLinkKind.youtube ||
      kind == EvidenceLinkKind.googleDrive ||
      kind == EvidenceLinkKind.directVideo;

  bool get hasInlinePreview =>
      isPlayable ||
      kind == EvidenceLinkKind.directPdf ||
      kind == EvidenceLinkKind.directDocx;

  String get badgeLabel => switch (kind) {
        EvidenceLinkKind.youtube => 'YouTube',
        EvidenceLinkKind.googleDrive => 'Google Drive',
        EvidenceLinkKind.googleDriveFolder => 'Folder Drive',
        EvidenceLinkKind.directVideo => 'Video',
        EvidenceLinkKind.directPdf => 'PDF',
        EvidenceLinkKind.directDocx => 'DOCX',
        EvidenceLinkKind.externalLink => 'Tautan',
      };

  String get modalTitle => switch (kind) {
        EvidenceLinkKind.youtube => 'Video YouTube',
        EvidenceLinkKind.googleDrive => 'Preview Google Drive',
        EvidenceLinkKind.googleDriveFolder => 'Folder Google Drive',
        EvidenceLinkKind.directVideo => 'Pemutar Video',
        EvidenceLinkKind.directPdf => 'Preview Dokumen PDF',
        EvidenceLinkKind.directDocx => 'Preview Dokumen DOCX',
        EvidenceLinkKind.externalLink => 'Tautan Bukti',
      };

  String get detectionHint => switch (kind) {
        EvidenceLinkKind.youtube =>
          'Video YouTube terdeteksi — bisa langsung diputar',
        EvidenceLinkKind.googleDrive =>
          'File Google Drive terdeteksi — bisa diputar di preview',
        EvidenceLinkKind.googleDriveFolder =>
          'Folder Google Drive terdeteksi — buka langsung di Drive',
        EvidenceLinkKind.directVideo =>
          'Link video langsung terdeteksi — bisa langsung diputar',
        EvidenceLinkKind.directPdf =>
          'Dokumen PDF terdeteksi — bisa langsung dipreview',
        EvidenceLinkKind.directDocx =>
          'Dokumen DOCX terdeteksi — bisa langsung dipreview',
        EvidenceLinkKind.externalLink => 'Tautan bukti valid',
      };
}

final RegExp _youtubeIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
final RegExp _driveIdPattern = RegExp(r'^[A-Za-z0-9_-]{10,}$');
final RegExp _explicitSchemePattern = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:');
final RegExp _youtubeDurationPattern = RegExp(
  r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s?)?$',
  caseSensitive: false,
);

const Set<String> _youtubeHosts = {
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'music.youtube.com',
  'youtu.be',
  'www.youtu.be',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
};

const Set<String> _driveHosts = {
  'drive.google.com',
  'docs.google.com',
};

/// Parses and classifies an external evidence URL (YouTube, Google Drive,
/// direct video file, or generic web link). Returns null for invalid URLs.
ParsedEvidenceLink? parseEvidenceLink(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) {
    return null;
  }

  final hasExplicitScheme = _explicitSchemePattern.hasMatch(trimmed);
  final candidate = hasExplicitScheme ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasScheme) return null;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;

  final host = uri.host.toLowerCase();
  if (!_isValidHost(host)) return null;

  // Preserve explicitly provided http/https URLs byte-for-byte.
  final normalizedUrl = hasExplicitScheme ? trimmed : uri.toString();

  if (_youtubeHosts.contains(host)) {
    final videoId = _extractYouTubeId(uri, host);
    if (videoId != null) {
      final startSeconds = _parseYouTubeTimestamp(
        uri.queryParameters['start'] ?? uri.queryParameters['t'],
      );
      final startParam = startSeconds != null && startSeconds > 0
          ? '&start=$startSeconds'
          : '';
      return ParsedEvidenceLink(
        rawUrl: trimmed,
        normalizedUrl: normalizedUrl,
        kind: EvidenceLinkKind.youtube,
        embedUrl:
            'https://www.youtube.com/embed/$videoId?rel=0&playsinline=1$startParam',
        mediaId: videoId,
        thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      );
    }
  }

  if (_driveHosts.contains(host)) {
    final folderId = _extractGoogleDriveFolderId(uri);
    if (folderId != null) {
      return ParsedEvidenceLink(
        rawUrl: trimmed,
        normalizedUrl: normalizedUrl,
        kind: EvidenceLinkKind.googleDriveFolder,
        mediaId: folderId,
      );
    }

    final fileId = _extractGoogleDriveFileId(uri);
    if (fileId != null) {
      return ParsedEvidenceLink(
        rawUrl: trimmed,
        normalizedUrl: normalizedUrl,
        kind: EvidenceLinkKind.googleDrive,
        embedUrl: 'https://drive.google.com/file/d/$fileId/preview',
        mediaId: fileId,
      );
    }
  }

  final videoMime = _directVideoMimeType(uri.path);
  if (videoMime != null) {
    return ParsedEvidenceLink(
      rawUrl: trimmed,
      normalizedUrl: normalizedUrl,
      kind: EvidenceLinkKind.directVideo,
      embedUrl: normalizedUrl,
      mimeType: videoMime,
    );
  }

  final lowerPath = uri.path.toLowerCase();
  if (lowerPath.endsWith('.pdf')) {
    return ParsedEvidenceLink(
      rawUrl: trimmed,
      normalizedUrl: normalizedUrl,
      kind: EvidenceLinkKind.directPdf,
      embedUrl: normalizedUrl,
      mimeType: 'application/pdf',
    );
  }
  if (lowerPath.endsWith('.docx')) {
    return ParsedEvidenceLink(
      rawUrl: trimmed,
      normalizedUrl: normalizedUrl,
      kind: EvidenceLinkKind.directDocx,
      embedUrl: normalizedUrl,
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  return ParsedEvidenceLink(
    rawUrl: trimmed,
    normalizedUrl: normalizedUrl,
    kind: EvidenceLinkKind.externalLink,
  );
}

bool _isValidHost(String host) {
  if (host.isEmpty) return false;
  if (host == 'localhost') return true;
  if (!host.contains('.')) return false;
  final labels = host.split('.');
  return labels.length >= 2 && labels.every((label) => label.isNotEmpty);
}

String? _extractYouTubeId(Uri uri, String host) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (segments.isEmpty) return null;
    final id = segments.first;
    return _youtubeIdPattern.hasMatch(id) ? id : null;
  }

  if (segments.isNotEmpty && segments.first == 'watch') {
    final id = uri.queryParameters['v']?.trim() ?? '';
    return _youtubeIdPattern.hasMatch(id) ? id : null;
  }

  if (segments.length >= 2 &&
      const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
    final id = segments[1];
    return _youtubeIdPattern.hasMatch(id) ? id : null;
  }

  final fallbackV = uri.queryParameters['v']?.trim() ?? '';
  if (fallbackV.isNotEmpty && _youtubeIdPattern.hasMatch(fallbackV)) {
    return fallbackV;
  }
  return null;
}

int? _parseYouTubeTimestamp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final trimmed = raw.trim();
  final numeric = int.tryParse(trimmed);
  if (numeric != null && numeric > 0) return numeric;

  final match = _youtubeDurationPattern.firstMatch(trimmed);
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
  final total = hours * 3600 + minutes * 60 + seconds;
  return total > 0 ? total : null;
}

String? _extractGoogleDriveFolderId(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'folders' && _driveIdPattern.hasMatch(segments[i + 1])) {
      return segments[i + 1];
    }
  }
  return null;
}

String? _extractGoogleDriveFileId(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final fileIndex = segments.indexOf('file');
  if (fileIndex >= 0) {
    for (var i = fileIndex + 1; i < segments.length - 1; i++) {
      if (segments[i] == 'd' && _driveIdPattern.hasMatch(segments[i + 1])) {
        return segments[i + 1];
      }
    }
  }

  final pathLower = uri.path.toLowerCase();
  if (pathLower == '/open' || pathLower == '/uc' || pathLower == '/thumbnail') {
    final id = uri.queryParameters['id']?.trim() ?? '';
    if (_driveIdPattern.hasMatch(id)) return id;
  }
  return null;
}

String? _directVideoMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.ogv') || lower.endsWith('.ogg')) return 'video/ogg';
  if (lower.endsWith('.3gp')) return 'video/3gpp';
  return null;
}
