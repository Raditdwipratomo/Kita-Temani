import 'dart:convert';

import 'package:kitatemani/core/services/audio_recorder_service.dart';
import 'package:kitatemani/core/services/file_bytes_helper.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/services/location_service.dart';
import 'package:kitatemani/core/services/sms_sender.dart';
import 'package:kitatemani/features/emergency_contacts/domain/repositories/emergency_contact_repository.dart';
import 'package:kitatemani/features/panic/domain/entities/panic_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const String kLocalPanicEventsPrefsKey = 'kt_panic_events_json';

abstract interface class PanicNotifier {
  Future<String?> notifyCounselor(
    GeoLocationData? position, {
    String studentName = 'Siswa',
    String className = '',
    String schoolName = '',
    String schoolSlug = 'sman1-nusantara',
    String messageText = '',
    String areaHint = '',
    String situationNote = '',
    List<ContactSmsState> deliveries = const [],
  });

  Future<void> resolveEvent({
    required String? eventId,
    String? localAudioPath,
  });
}

class DummyPanicNotifier implements PanicNotifier {
  @override
  Future<String?> notifyCounselor(
    GeoLocationData? position, {
    String studentName = 'Siswa',
    String className = '',
    String schoolName = '',
    String schoolSlug = 'sman1-nusantara',
    String messageText = '',
    String areaHint = '',
    String situationNote = '',
    List<ContactSmsState> deliveries = const [],
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return 'local-panic-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> resolveEvent({
    required String? eventId,
    String? localAudioPath,
  }) async {}
}

class SupabasePanicNotifier implements PanicNotifier {
  SupabasePanicNotifier(this._client);

  final SupabaseClient? _client;
  static const _uuid = Uuid();

  @override
  Future<String?> notifyCounselor(
    GeoLocationData? position, {
    String studentName = 'Siswa',
    String className = '',
    String schoolName = '',
    String schoolSlug = 'sman1-nusantara',
    String messageText = '',
    String areaHint = '',
    String situationNote = '',
    List<ContactSmsState> deliveries = const [],
  }) async {
    final client = _client;
    if (client == null) {
      return DummyPanicNotifier().notifyCounselor(
        position,
        studentName: studentName,
        className: className,
        schoolName: schoolName,
        areaHint: areaHint,
        situationNote: situationNote,
      );
    }

    try {
      if (client.auth.currentSession == null) {
        return null;
      }
      final res = await client.functions.invoke(
        'panic-notify',
        body: {
          'lat': position?.latitude,
          'lng': position?.longitude,
          'accuracy': position?.accuracyMeters,
          'location_label': position?.label ?? 'Lokasi GPS belum tersedia',
          'student_name': studentName,
          'class_name': className,
          'school_name': schoolName,
          'school_slug': schoolSlug,
          'message_text': messageText,
          'area_hint': areaHint,
          'situation_note': situationNote,
          'contact_deliveries': deliveries.map((d) => d.toJson()).toList(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      ).timeout(const Duration(seconds: 4));
      if (res.data is Map && res.data['event_id'] != null) {
        return res.data['event_id'].toString();
      }
    } on Object {
      // Non-blocking: panic screen opens immediately regardless of network state.
    }
    return null;
  }

  @override
  Future<void> resolveEvent({
    required String? eventId,
    String? localAudioPath,
  }) async {
    final client = _client;
    if (client == null || eventId == null) return;
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(eventId)) return;

    String? uploadedAudioPath;
    final uid = client.auth.currentUser?.id;
    if (uid != null &&
        localAudioPath != null &&
        localAudioPath.isNotEmpty &&
        !localAudioPath.startsWith('local://') &&
        !localAudioPath.startsWith('simulated_')) {
      final audioBytes = await readFileBytes(localAudioPath);
      if (audioBytes != null && audioBytes.isNotEmpty) {
        try {
          final target = '$uid/panic/${_uuid.v4()}_audio.m4a';
          await client.storage.from('evidence').uploadBinary(
                target,
                audioBytes,
              );
          uploadedAudioPath = target;
        } on Object {
          uploadedAudioPath = null;
        }
      }
    }

    try {
      await client.rpc(
        'resolve_panic_event',
        params: {
          'p_event_id': eventId,
          'p_audio_storage_path': uploadedAudioPath,
        },
      );
    } on Object {
      // Ignore offline errors when resolving panic event.
    }
  }
}

/// Use case Panic Button sesuai PRD 9.6: setiap langkah berdiri sendiri.
class ActivatePanic {
  const ActivatePanic({
    required this.recorder,
    required this.location,
    required this.sms,
    required this.contacts,
    required this.notifier,
    this.prefs,
  });

  final AudioRecorderService recorder;
  final LocationService location;
  final SmsSender sms;
  final EmergencyContactRepository contacts;
  final PanicNotifier notifier;
  final LocalPreferencesService? prefs;

  Future<PanicOutcome> call({
    String studentName = 'Siswa',
    String className = '',
    String schoolName = '',
    String schoolSlug = 'sman1-nusantara',
    String? counselorPhone,
    String? situationTag,
    String? areaHint,
  }) async {
    final activeFuture = contacts
        .activeContacts()
        .timeout(const Duration(seconds: 1), onTimeout: () => const []);
    final audioFuture = _guard(
      'audio',
      () => recorder.start().timeout(const Duration(seconds: 1)),
    );
    final locationFuture = location
        .currentOrLastKnown(timeout: const Duration(milliseconds: 1500))
        .timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => null,
        );

    final active = await activeFuture;
    final position = await locationFuture;
    final audioStep = await audioFuture;

    final smsRecipients = <String>[
      ...active.map((c) => c.phone),
      if (counselorPhone != null &&
          counselorPhone.trim().isNotEmpty &&
          !active.any((c) => c.phone.trim() == counselorPhone.trim()))
        counselorPhone.trim(),
    ];
    final triggeredAt = DateTime.now();

    final alertContext = PanicAlertContext(
      studentName: studentName,
      className: className,
      schoolName: schoolName,
      triggeredAt: triggeredAt,
      position: position,
      situationTag: situationTag,
      areaHint: areaHint,
    );
    final smsMessage = PanicMessage.buildSms(alertContext);
    final whatsappMessage = PanicMessage.buildWhatsApp(alertContext);

    String? createdEventId;
    final trailingSteps = await Future.wait([
      _guard(
        'sms',
        () => sms
            .sendToAll(smsRecipients, smsMessage)
            .timeout(const Duration(seconds: 1)),
      ),
      _guard('notify', () async {
        createdEventId = await notifier
            .notifyCounselor(
              position,
              studentName: alertContext.resolvedName,
              className: className,
              schoolName: schoolName,
              schoolSlug: schoolSlug,
              messageText: whatsappMessage,
              areaHint: areaHint ?? '',
              situationNote: situationTag ?? '',
            )
            .timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => null,
            );
      }),
    ]);
    final steps = [audioStep, ...trailingSteps];

    final smsFailed = steps.any((s) => s.step == 'sms' && !s.succeeded);
    final deliveries = active
        .map(
          (c) => ContactSmsState(
            contactId: c.id,
            contactName: c.name,
            phone: c.phone,
            status: smsFailed
                ? ContactSmsDeliveryStatus.failed
                : ContactSmsDeliveryStatus.sent,
          ),
        )
        .toList();

    final resolvedEventId =
        createdEventId ?? 'local-panic-${triggeredAt.millisecondsSinceEpoch}';
    await _persistLocalPanicEvent(
      id: resolvedEventId,
      studentName: alertContext.resolvedName,
      className: className,
      schoolName: schoolName,
      locationLabel: position?.label ?? 'Lokasi GPS belum tersedia',
      areaHint: areaHint ?? '',
      situationNote: situationTag ?? '',
      startedAt: triggeredAt,
    );

    return PanicOutcome(
      steps: steps,
      position: position,
      messageText: smsMessage,
      whatsappMessage: whatsappMessage,
      triggeredAt: triggeredAt,
      situationTag: situationTag,
      areaHint: areaHint,
      contactDeliveries: deliveries,
      eventId: resolvedEventId,
    );
  }

  Future<void> _persistLocalPanicEvent({
    required String id,
    required String studentName,
    required String className,
    required String schoolName,
    required String locationLabel,
    required String areaHint,
    required String situationNote,
    required DateTime startedAt,
  }) async {
    final p = prefs;
    if (p == null) return;
    try {
      final raw = p.getString(kLocalPanicEventsPrefsKey);
      final existing = <Map<String, dynamic>>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              existing.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      existing.removeWhere((e) => e['id'] == id);
      existing.insert(0, {
        'id': id,
        'student_name': studentName,
        'class_name': className,
        'school_name': schoolName,
        'location_label': locationLabel,
        'area_hint': areaHint,
        'situation_note': situationNote,
        'status': 'active',
        'started_at': startedAt.toIso8601String(),
      });
      await p.setString(
        kLocalPanicEventsPrefsKey,
        jsonEncode(existing.take(20).toList()),
      );
    } on Object {
      // Non-blocking fallback.
    }
  }

  Future<StepResult> _guard(String step, Future<void> Function() action) async {
    try {
      await action();
      return StepResult.ok(step);
    } on Object catch (error) {
      return StepResult.failed(step, error);
    }
  }
}
