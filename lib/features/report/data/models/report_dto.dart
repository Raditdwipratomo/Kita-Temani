import 'package:kitatemani/features/report/domain/entities/report.dart';

class NewReportDto {
  const NewReportDto({
    required this.idempotencyKey,
    required this.schoolId,
    required this.types,
    required this.occurredAtIso,
    required this.location,
    required this.narrative,
    this.perpetratorNames = '',
    this.victimName = '',
    this.reporterName = '',
    this.reporterClass = '',
    this.reporterPhone = '',
    this.evidenceLink,
    this.isVictim = true,
    this.isAnonymous = true,
    this.attachments = const [],
  });

  factory NewReportDto.fromDomain(
    NewReport domain, {
    List<EvidenceAttachment>? uploadedAttachments,
  }) {
    final effectiveAttachments = uploadedAttachments ??
        (domain.evidenceFiles.isNotEmpty
            ? domain.evidenceFiles
            : domain.attachments.map(EvidenceAttachment.fromJson).toList());

    return NewReportDto(
      idempotencyKey: domain.idempotencyKey,
      schoolId: domain.schoolId,
      types: domain.types.map((e) => e.name).toList(growable: false),
      occurredAtIso: domain.occurredAt.toUtc().toIso8601String(),
      location: domain.location,
      narrative: domain.narrative,
      perpetratorNames: domain.perpetratorNames,
      victimName: domain.victimName,
      reporterName: domain.reporterName,
      reporterClass: domain.reporterClass,
      reporterPhone: domain.reporterPhone,
      evidenceLink: domain.evidenceLink,
      isVictim: domain.isVictim,
      isAnonymous: domain.isAnonymous,
      attachments: effectiveAttachments,
    );
  }

  final String idempotencyKey;
  final String schoolId;
  final List<String> types;
  final String occurredAtIso;
  final String location;
  final String narrative;
  final String perpetratorNames;
  final String victimName;
  final String reporterName;
  final String reporterClass;
  final String reporterPhone;
  final String? evidenceLink;
  final bool isVictim;
  final bool isAnonymous;
  final List<EvidenceAttachment> attachments;

  Map<String, dynamic> toRpcParams() => {
        'p_idempotency_key': idempotencyKey,
        'p_school_ref': schoolId,
        'p_types': types,
        'p_occurred_at': occurredAtIso,
        'p_location': location,
        'p_narrative': narrative,
        'p_perpetrator_names': perpetratorNames,
        'p_victim_name': victimName,
        'p_reporter_name': reporterName,
        'p_reporter_class': reporterClass,
        'p_reporter_phone': reporterPhone,
        'p_evidence_link': evidenceLink,
        'p_is_victim': isVictim,
        'p_is_anonymous': isAnonymous,
        'p_attachments': attachments.map((a) => a.toJson()).toList(),
      };

  Map<String, dynamic> toLegacyRpcParams() {
    final details = <String>[];
    if (victimName.trim().isNotEmpty) {
      details.add('Nama korban: ${victimName.trim()}');
    }
    if (perpetratorNames.trim().isNotEmpty) {
      details.add('List nama pelaku: ${perpetratorNames.trim()}');
    }
    final enrichedNarrative = details.isEmpty
        ? narrative
        : '${narrative.trim()}\n\n${details.join('\n')}';

    return {
      'p_idempotency_key': idempotencyKey,
      'p_school_ref': schoolId,
      'p_types': types,
      'p_occurred_at': occurredAtIso,
      'p_location': location,
      'p_narrative': enrichedNarrative,
      'p_evidence_link': evidenceLink,
      'p_is_victim': isVictim,
      'p_is_anonymous': isAnonymous,
      'p_attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }

  Map<String, dynamic> toQueueJson() => {
        'idempotency_key': idempotencyKey,
        'school_id': schoolId,
        'types': types,
        'occurred_at': occurredAtIso,
        'location': location,
        'narrative': narrative,
        'perpetrator_names': perpetratorNames,
        'victim_name': victimName,
        'reporter_name': reporterName,
        'reporter_class': reporterClass,
        'reporter_phone': reporterPhone,
        'evidence_link': evidenceLink,
        'is_victim': isVictim,
        'is_anonymous': isAnonymous,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory NewReportDto.fromQueueJson(Map<String, dynamic> json) {
    return NewReportDto(
      idempotencyKey: (json['idempotency_key'] ?? '').toString(),
      schoolId: (json['school_id'] ?? 'sman1-nusantara').toString(),
      types: (json['types'] as List<dynamic>? ?? const ['verbal'])
          .map((e) => e.toString())
          .toList(),
      occurredAtIso:
          (json['occurred_at'] ?? DateTime.now().toUtc().toIso8601String())
              .toString(),
      location: (json['location'] ?? 'Kelas').toString(),
      narrative: (json['narrative'] ?? '').toString(),
      perpetratorNames: (json['perpetrator_names'] ?? '').toString(),
      victimName: (json['victim_name'] ?? '').toString(),
      reporterName: (json['reporter_name'] ?? '').toString(),
      reporterClass: (json['reporter_class'] ?? '').toString(),
      reporterPhone: (json['reporter_phone'] ?? '').toString(),
      evidenceLink: json['evidence_link']?.toString(),
      isVictim: json['is_victim'] as bool? ?? true,
      isAnonymous: json['is_anonymous'] as bool? ?? true,
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map(EvidenceAttachment.fromJson)
          .toList(),
    );
  }
}
