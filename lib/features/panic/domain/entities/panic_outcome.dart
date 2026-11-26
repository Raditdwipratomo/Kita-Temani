import 'package:kitatemani/core/services/location_service.dart';
import 'package:kitatemani/core/services/sms_sender.dart';
import 'package:kitatemani/core/utils/date_formatter.dart';

class StepResult {
  const StepResult({
    required this.step,
    required this.succeeded,
    this.error,
  });

  factory StepResult.ok(String step) => StepResult(step: step, succeeded: true);

  factory StepResult.failed(String step, Object error) =>
      StepResult(step: step, succeeded: false, error: error);

  final String step;
  final bool succeeded;
  final Object? error;
}

class ContactSmsState {
  const ContactSmsState({
    required this.contactId,
    required this.contactName,
    required this.phone,
    required this.status,
  });

  final String contactId;
  final String contactName;
  final String phone;
  final ContactSmsDeliveryStatus status;

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'contact_name': contactName,
        'phone': phone,
        'status': status.name,
      };

  ContactSmsState copyWith({ContactSmsDeliveryStatus? status}) {
    return ContactSmsState(
      contactId: contactId,
      contactName: contactName,
      phone: phone,
      status: status ?? this.status,
    );
  }
}

class PanicAlertContext {
  const PanicAlertContext({
    required this.studentName,
    required this.triggeredAt,
    this.className = '',
    this.schoolName = '',
    this.position,
    this.situationTag,
    this.areaHint,
  });

  final String studentName;
  final DateTime triggeredAt;
  final String className;
  final String schoolName;
  final GeoLocationData? position;
  final String? situationTag;
  final String? areaHint;

  String get resolvedName =>
      studentName.trim().isNotEmpty ? studentName.trim() : 'Siswa';
}

class PanicOutcome {
  const PanicOutcome({
    required this.steps,
    required this.position,
    required this.messageText,
    required this.contactDeliveries,
    this.whatsappMessage = '',
    this.triggeredAt,
    this.situationTag,
    this.areaHint,
    this.eventId,
  });

  final List<StepResult> steps;
  final GeoLocationData? position;
  final String messageText;
  final String whatsappMessage;
  final DateTime? triggeredAt;
  final String? situationTag;
  final String? areaHint;
  final List<ContactSmsState> contactDeliveries;
  final String? eventId;

  bool get anySmsFailed => contactDeliveries.any(
        (c) => c.status == ContactSmsDeliveryStatus.failed,
      );
}

abstract final class PanicMessage {
  static String _zoneLabel(DateTime dt) {
    return switch (dt.timeZoneOffset.inHours) {
      8 => 'WITA',
      9 => 'WIT',
      _ => 'WIB',
    };
  }

  static String _formatTimestamp(DateTime dt) {
    return '${DateFormatter.shortDateYear(dt)}, ${DateFormatter.timeHHmm(dt)} ${_zoneLabel(dt)}';
  }

  /// Pesan WhatsApp terstruktur & mudah dipindai dalam hitungan detik.
  static String buildWhatsApp(PanicAlertContext ctx) {
    final lines = <String>[
      '*[DARURAT SOS] PERINGATAN DARURAT — KitaTemani*',
      '',
      '*Nama:* ${ctx.resolvedName}',
    ];

    if (ctx.className.trim().isNotEmpty) {
      lines.add('*Kelas:* ${ctx.className.trim()}');
    }
    if (ctx.schoolName.trim().isNotEmpty) {
      lines.add('*Sekolah:* ${ctx.schoolName.trim()}');
    }
    lines.add('*Waktu:* ${_formatTimestamp(ctx.triggeredAt)}');

    final situation = ctx.situationTag?.trim() ?? '';
    lines.add(
      '*Situasi:* ${situation.isNotEmpty ? situation : 'Butuh pertolongan segera'}',
    );

    final area = ctx.areaHint?.trim() ?? '';
    if (area.isNotEmpty) {
      lines.add('*Area:* $area');
    }

    final pos = ctx.position;
    if (pos != null && pos.shortLink.isNotEmpty) {
      lines.add('*Lokasi GPS:* ${pos.shortLink}');
    } else {
      lines.add(
        '*Lokasi GPS:* Belum tersedia (mohon hubungi siswa langsung untuk konfirmasi posisi)',
      );
    }

    lines.addAll(const [
      '',
      'Siswa sedang membutuhkan bantuan segera. Mohon segera hubungi atau datangi lokasi di atas.',
      '_Dikirim lewat Tombol Darurat KitaTemani_',
    ]);

    return lines.join('\n');
  }

  /// Pesan SMS ringkas untuk keandalan pengiriman saat sinyal seluler lemah.
  static String buildSms(PanicAlertContext ctx) {
    final identityParts = <String>[
      if (ctx.className.trim().isNotEmpty) ctx.className.trim(),
      if (ctx.schoolName.trim().isNotEmpty) ctx.schoolName.trim(),
    ];
    final identity = identityParts.isEmpty
        ? ctx.resolvedName
        : '${ctx.resolvedName} (${identityParts.join(', ')})';

    final details = <String>[];
    final situation = ctx.situationTag?.trim() ?? '';
    if (situation.isNotEmpty) {
      details.add('Situasi: $situation');
    }
    final area = ctx.areaHint?.trim() ?? '';
    if (area.isNotEmpty) {
      details.add('Area: $area');
    }
    details.add(
      '${DateFormatter.timeHHmm(ctx.triggeredAt)} ${_zoneLabel(ctx.triggeredAt)}',
    );

    final pos = ctx.position;
    final locationPart = pos != null && pos.shortLink.isNotEmpty
        ? 'GPS: ${pos.shortLink}'
        : 'Lokasi GPS belum tersedia';

    return '[SOS KitaTemani] $identity butuh bantuan sekarang! '
        '${details.join('. ')}. $locationPart';
  }

  /// Pesan tindak lanjut konfirmasi bahwa siswa sudah berada di tempat aman.
  static String buildSafeUpdate(PanicAlertContext ctx) {
    final identityParts = <String>[
      if (ctx.className.trim().isNotEmpty) ctx.className.trim(),
      if (ctx.schoolName.trim().isNotEmpty) ctx.schoolName.trim(),
    ];
    final nameLine = identityParts.isEmpty
        ? ctx.resolvedName
        : '${ctx.resolvedName} (${identityParts.join(' · ')})';

    return [
      '*[AMAN] KONFIRMASI SUDAH AMAN — KitaTemani*',
      '',
      '*Nama:* $nameLine',
      '*Waktu:* ${_formatTimestamp(ctx.triggeredAt)}',
      '',
      'Saya sudah berada di tempat aman dan mode darurat telah dihentikan. Terima kasih atas perhatian dan bantuannya.',
    ].join('\n');
  }

  /// Helper ringkas untuk kompatibilitas pemanggil lama.
  static String build({
    required String studentName,
    required GeoLocationData? position,
    String className = '',
    String schoolName = '',
    DateTime? triggeredAt,
    String? situationTag,
    String? areaHint,
  }) {
    return buildSms(
      PanicAlertContext(
        studentName: studentName,
        className: className,
        schoolName: schoolName,
        triggeredAt: triggeredAt ?? DateTime.now(),
        position: position,
        situationTag: situationTag,
        areaHint: areaHint,
      ),
    );
  }
}
