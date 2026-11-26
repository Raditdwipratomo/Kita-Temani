import 'dart:typed_data';

enum BullyingType {
  fisik('Fisik', 'Memukul,\nmendorong'),
  verbal('Verbal', 'Menghina,\nmengejek'),
  siber('Siber', 'Media sosial,\nchat');

  const BullyingType(this.label, this.subtitle);
  final String label;
  final String subtitle;

  String get fullTitle => 'Perundungan ${label.toLowerCase()}';

  static BullyingType? tryParse(String raw) {
    for (final t in BullyingType.values) {
      if (t.name == raw.trim().toLowerCase()) return t;
    }
    return null;
  }
}

enum ReportStatus {
  diterima('diterima', 'Dikirim'),
  ditinjau('ditinjau', 'Dibaca'),
  tindakLanjut('tindak_lanjut', 'Ditindak'),
  selesai('selesai', 'Selesai');

  const ReportStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;

  bool get isCompleted => this == ReportStatus.selesai;

  static ReportStatus fromWire(String? value) {
    return switch (value) {
      'ditinjau' || 'dibaca' => ReportStatus.ditinjau,
      'tindak_lanjut' ||
      'tindakLanjut' ||
      'ditindak' =>
        ReportStatus.tindakLanjut,
      'selesai' => ReportStatus.selesai,
      _ => ReportStatus.diterima,
    };
  }
}

class EvidenceAttachment {
  const EvidenceAttachment({
    required this.fileName,
    this.kind = 'foto',
    this.localPath,
    this.storagePath,
    this.previewUrl,
    this.bytes,
    this.sizeBytes,
    this.exifStripped = true,
  });

  final String fileName;
  final String kind;
  final String? localPath;
  final String? storagePath;
  final String? previewUrl;
  final Uint8List? bytes;
  final int? sizeBytes;
  final bool exifStripped;

  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');

  bool get isDocx => fileName.toLowerCase().endsWith('.docx');

  bool get isVideo {
    if (kind == 'video') return true;
    final lower = fileName.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.ogv') ||
        lower.endsWith('.3gp');
  }

  bool get isImage {
    if (isVideo || isPdf || isDocx) return false;
    if (kind == 'suara' || kind == 'file') return false;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return true;
    }
    if (kind == 'foto') {
      return !lower.endsWith('.doc') &&
          !lower.endsWith('.mp3') &&
          !lower.endsWith('.m4a') &&
          !lower.endsWith('.wav') &&
          !lower.endsWith('.txt') &&
          !lower.endsWith('.zip');
    }
    return false;
  }

  static String inferKindFromFileName(
    String fileName, {
    String fallback = 'foto',
  }) {
    final lower = fileName.trim().toLowerCase();
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.zip')) {
      return 'file';
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.ogv') ||
        lower.endsWith('.3gp')) {
      return 'video';
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.aac')) {
      return 'suara';
    }
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return 'foto';
    }
    return fallback;
  }

  String get mimeType {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.ogv') || lower.endsWith('.ogg')) return 'video/ogg';
    if (lower.endsWith('.3gp')) return 'video/3gpp';
    if (isVideo) return 'video/mp4';

    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (isImage) return 'image/jpeg';

    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    return 'application/octet-stream';
  }

  EvidenceAttachment copyWith({
    String? fileName,
    String? kind,
    String? localPath,
    String? storagePath,
    String? previewUrl,
    Uint8List? bytes,
    int? sizeBytes,
    bool? exifStripped,
  }) {
    return EvidenceAttachment(
      fileName: fileName ?? this.fileName,
      kind: kind ?? this.kind,
      localPath: localPath ?? this.localPath,
      storagePath: storagePath ?? this.storagePath,
      previewUrl: previewUrl ?? this.previewUrl,
      bytes: bytes ?? this.bytes,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      exifStripped: exifStripped ?? this.exifStripped,
    );
  }

  Map<String, dynamic> toJson() => {
        'file_name': fileName,
        'kind': kind,
        'local_path': localPath,
        'storage_path': storagePath ?? fileName,
        if (previewUrl != null) 'preview_url': previewUrl,
        if (sizeBytes != null) 'size_bytes': sizeBytes,
        'exif_stripped': exifStripped,
      };

  factory EvidenceAttachment.fromJson(dynamic raw) {
    if (raw is String) {
      return EvidenceAttachment(
        fileName: raw,
        kind: inferKindFromFileName(raw),
      );
    }
    final map = raw as Map<String, dynamic>;
    final fileName = (map['file_name'] ?? 'lampiran').toString();
    final rawKind = (map['kind'] ?? 'foto').toString();
    final resolvedKind = inferKindFromFileName(fileName, fallback: rawKind);
    return EvidenceAttachment(
      fileName: fileName,
      kind: resolvedKind,
      localPath: map['local_path']?.toString(),
      storagePath: map['storage_path']?.toString(),
      previewUrl: map['preview_url']?.toString(),
      sizeBytes: (map['size_bytes'] as num?)?.toInt(),
      exifStripped: map['exif_stripped'] as bool? ?? true,
    );
  }
}

class ReportTimelineEntry {
  const ReportTimelineEntry({
    required this.status,
    required this.title,
    required this.description,
    required this.changedAt,
  });

  final ReportStatus status;
  final String title;
  final String description;
  final DateTime changedAt;

  Map<String, dynamic> toJson() => {
        'status': status.wireValue,
        'title': title,
        'description': description,
        'changed_at': changedAt.toIso8601String(),
      };

  factory ReportTimelineEntry.fromJson(Map<String, dynamic> json) {
    return ReportTimelineEntry(
      status: ReportStatus.fromWire(json['status']?.toString()),
      title: (json['title'] ?? 'Pembaruan').toString(),
      description: (json['description'] ?? '').toString(),
      changedAt: DateTime.tryParse((json['changed_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ReportChatMessage {
  const ReportChatMessage({
    required this.id,
    required this.senderRole,
    required this.senderLabel,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String senderRole;
  final String senderLabel;
  final String content;
  final DateTime createdAt;

  bool get isCounselor => senderRole == 'guru_bk';

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_role': senderRole,
        'sender_label': senderLabel,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory ReportChatMessage.fromJson(Map<String, dynamic> json) {
    return ReportChatMessage(
      id: (json['id'] ?? '').toString(),
      senderRole: (json['sender_role'] ?? 'guru_bk').toString(),
      senderLabel: (json['sender_label'] ?? 'Guru BK').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class ReportDetailData {
  const ReportDetailData({
    required this.item,
    required this.schoolName,
    required this.history,
    required this.messages,
  });

  final AnonymousReportItem item;
  final String schoolName;
  final List<ReportTimelineEntry> history;
  final List<ReportChatMessage> messages;
}

String formatReporterIdentity({
  required String name,
  String className = '',
  String phone = '',
  String email = '',
}) {
  final cleanName = name.trim().isEmpty ? 'Siswa' : name.trim();
  final cleanClass = className.trim();
  final cleanPhone = phone.trim();
  final cleanEmail = email.trim();
  final withClass = cleanClass.isNotEmpty ? '$cleanName ($cleanClass)' : cleanName;
  if (cleanPhone.isNotEmpty) return '$withClass · $cleanPhone';
  if (cleanEmail.isNotEmpty) return '$withClass · $cleanEmail';
  return withClass;
}

class NewReport {
  const NewReport({
    required this.idempotencyKey,
    required this.schoolId,
    required this.types,
    required this.occurredAt,
    required this.whenLabel,
    required this.location,
    required this.narrative,
    this.perpetratorNames = '',
    this.victimName = '',
    this.reporterName = '',
    this.reporterClass = '',
    this.reporterPhone = '',
    this.isVictim = true,
    this.isAnonymous = true,
    this.attachments = const [],
    this.evidenceFiles = const [],
    this.evidenceLink,
  });

  final String idempotencyKey;
  final String schoolId;
  final Set<BullyingType> types;
  final DateTime occurredAt;
  final String whenLabel;
  final String location;
  final String narrative;
  final String perpetratorNames;
  final String victimName;
  final String reporterName;
  final String reporterClass;
  final String reporterPhone;
  final bool isVictim;
  final bool isAnonymous;
  final List<String> attachments;
  final List<EvidenceAttachment> evidenceFiles;
  final String? evidenceLink;
}

class AnonymousReportItem {
  const AnonymousReportItem({
    required this.code,
    required this.types,
    required this.occurredAt,
    required this.location,
    required this.narrative,
    this.perpetratorNames = '',
    this.victimName = '',
    String reporterName = '',
    String reporterClass = '',
    String reporterPhone = '',
    String reporterEmail = '',
    required this.status,
    required this.createdAt,
    this.id,
    this.attachments = const [],
    this.evidenceFiles = const [],
    this.evidenceLink,
    this.isVictim = true,
    this.hasCounselorMessage = false,
    this.isPendingSync = false,
  })  : _reporterName = reporterName,
        _reporterClass = reporterClass,
        _reporterPhone = reporterPhone,
        _reporterEmail = reporterEmail;

  final String? id;
  final String code;
  final Set<BullyingType> types;
  final DateTime occurredAt;
  final String location;
  final String narrative;
  final String perpetratorNames;
  final String victimName;
  final String? _reporterName;
  final String? _reporterClass;
  final String? _reporterPhone;
  final String? _reporterEmail;
  final ReportStatus status;
  final DateTime createdAt;
  final List<String> attachments;
  final List<EvidenceAttachment> evidenceFiles;
  final String? evidenceLink;
  final bool isVictim;
  final bool hasCounselorMessage;
  final bool isPendingSync;

  String get reporterName => _reporterName ?? '';
  String get reporterClass => _reporterClass ?? '';
  String get reporterPhone => _reporterPhone ?? '';
  String get reporterEmail => _reporterEmail ?? '';

  String get formattedReporterIdentity => formatReporterIdentity(
        name: reporterName,
        className: reporterClass,
        phone: reporterPhone,
        email: reporterEmail,
      );

  List<EvidenceAttachment> get resolvedEvidenceFiles => evidenceFiles.isNotEmpty
      ? evidenceFiles
      : attachments.map(EvidenceAttachment.fromJson).toList();

  BullyingType get primaryType =>
      types.isNotEmpty ? types.first : BullyingType.fisik;

  AnonymousReportItem copyWith({
    ReportStatus? status,
    String? perpetratorNames,
    String? victimName,
    String? reporterName,
    String? reporterClass,
    String? reporterPhone,
    String? reporterEmail,
    List<EvidenceAttachment>? evidenceFiles,
    bool? hasCounselorMessage,
    bool? isPendingSync,
  }) {
    return AnonymousReportItem(
      id: id,
      code: code,
      types: types,
      occurredAt: occurredAt,
      location: location,
      narrative: narrative,
      perpetratorNames: perpetratorNames ?? this.perpetratorNames,
      victimName: victimName ?? this.victimName,
      reporterName: reporterName ?? this.reporterName,
      reporterClass: reporterClass ?? this.reporterClass,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      reporterEmail: reporterEmail ?? this.reporterEmail,
      status: status ?? this.status,
      createdAt: createdAt,
      attachments: attachments,
      evidenceFiles: evidenceFiles ?? this.evidenceFiles,
      evidenceLink: evidenceLink,
      isVictim: isVictim,
      hasCounselorMessage: hasCounselorMessage ?? this.hasCounselorMessage,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'types': types.map((e) => e.name).toList(),
        'occurred_at': occurredAt.toIso8601String(),
        'location': location,
        'narrative': narrative,
        'perpetrator_names': perpetratorNames,
        'victim_name': victimName,
        'reporter_name': reporterName,
        'reporter_class': reporterClass,
        'reporter_phone': reporterPhone,
        'reporter_email': reporterEmail,
        'status': status.wireValue,
        'created_at': createdAt.toIso8601String(),
        'attachments': evidenceFiles.isNotEmpty
            ? evidenceFiles.map((e) => e.toJson()).toList()
            : attachments,
        'evidence_link': evidenceLink,
        'is_victim': isVictim,
        'has_counselor_message': hasCounselorMessage,
        'is_pending_sync': isPendingSync,
      };

  factory AnonymousReportItem.fromJson(Map<String, dynamic> json) {
    final rawTypes = (json['types'] as List<dynamic>? ?? const []);
    final parsedTypes = rawTypes
        .map((e) => BullyingType.tryParse(e.toString()))
        .whereType<BullyingType>()
        .toSet();
    final rawAttachments = (json['attachments'] as List<dynamic>? ?? const []);
    final parsedEvidence = rawAttachments
        .map(
          (e) => e is Map
              ? EvidenceAttachment.fromJson(Map<String, dynamic>.from(e))
              : EvidenceAttachment.fromJson(e),
        )
        .toList();
    final parsedAttachments = parsedEvidence.map((e) => e.fileName).toList();

    return AnonymousReportItem(
      id: json['id']?.toString(),
      code: (json['code'] ?? '').toString(),
      types: parsedTypes.isEmpty ? const {BullyingType.verbal} : parsedTypes,
      occurredAt: DateTime.tryParse((json['occurred_at'] ?? '').toString()) ??
          DateTime.now(),
      location: (json['location'] ?? 'Sekolah').toString(),
      narrative: (json['narrative'] ?? '').toString(),
      perpetratorNames: (json['perpetrator_names'] ?? '').toString(),
      victimName: (json['victim_name'] ?? '').toString(),
      reporterName: (json['reporter_name'] ?? '').toString(),
      reporterClass: (json['reporter_class'] ?? '').toString(),
      reporterPhone: (json['reporter_phone'] ?? '').toString(),
      reporterEmail: (json['reporter_email'] ?? '').toString(),
      status: ReportStatus.fromWire(json['status']?.toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      attachments: parsedAttachments,
      evidenceFiles: parsedEvidence,
      evidenceLink: json['evidence_link']?.toString(),
      isVictim: json['is_victim'] as bool? ?? true,
      hasCounselorMessage: json['has_counselor_message'] as bool? ?? false,
      isPendingSync: json['is_pending_sync'] as bool? ?? false,
    );
  }
}
