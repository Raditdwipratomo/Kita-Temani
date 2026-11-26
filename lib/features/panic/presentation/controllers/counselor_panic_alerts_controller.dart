import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kitatemani/features/panic/domain/usecases/activate_panic.dart';

class CounselorPanicAlert {
  const CounselorPanicAlert({
    required this.id,
    required this.studentName,
    required this.className,
    required this.schoolName,
    required this.locationLabel,
    required this.areaHint,
    required this.situationNote,
    required this.status,
    this.startedAt,
    this.lat,
    this.lng,
  });

  factory CounselorPanicAlert.fromMap(Map<String, dynamic> r) {
    return CounselorPanicAlert(
      id: (r['id'] ?? '').toString(),
      studentName: (r['student_name'] ?? 'Siswa').toString(),
      className: (r['class_name'] ?? '').toString(),
      schoolName: (r['school_name'] ?? '').toString(),
      locationLabel: (r['location_label'] ?? 'GPS Sekolah').toString(),
      areaHint: (r['area_hint'] ?? '').toString(),
      situationNote: (r['situation_note'] ?? '').toString(),
      status: (r['status'] ?? 'active').toString(),
      startedAt: DateTime.tryParse((r['started_at'] ?? '').toString()),
      lat: (r['lat'] as num?)?.toDouble(),
      lng: (r['lng'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String studentName;
  final String className;
  final String schoolName;
  final String locationLabel;
  final String areaHint;
  final String situationNote;
  final String status;
  final DateTime? startedAt;
  final double? lat;
  final double? lng;

  bool get isActive => status != 'resolved';

  CounselorPanicAlert copyWith({String? status}) {
    return CounselorPanicAlert(
      id: id,
      studentName: studentName,
      className: className,
      schoolName: schoolName,
      locationLabel: locationLabel,
      areaHint: areaHint,
      situationNote: situationNote,
      status: status ?? this.status,
      startedAt: startedAt,
      lat: lat,
      lng: lng,
    );
  }
}

class CounselorPanicAlertsController
    extends Notifier<List<CounselorPanicAlert>> {
  bool _disposed = false;
  int _buildGen = 0;

  @override
  List<CounselorPanicAlert> build() {
    _disposed = false;
    final gen = ++_buildGen;
    ref.onDispose(() => _disposed = true);
    final identity = ref.watch(
      studentProfileProvider.select((p) => (id: p.id, isStaff: p.role.isStaff)),
    );
    if (!identity.isStaff) {
      return const [];
    }
    Future.microtask(() => refresh(expectedGen: gen));
    return _readLocalPanicEvents();
  }

  List<CounselorPanicAlert> _readLocalPanicEvents() {
    final prefs = ref.read(localPreferencesServiceProvider);
    final raw = prefs.getString(kLocalPanicEventsPrefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(CounselorPanicAlert.fromMap)
          .where((a) => a.id.isNotEmpty)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> refresh({int? expectedGen}) async {
    if (_disposed) return;
    if (expectedGen != null && expectedGen != _buildGen) return;
    final activeGen = expectedGen ?? _buildGen;

    final student = ref.read(studentProfileProvider);
    if (!student.role.isStaff) {
      state = const [];
      return;
    }

    final localAlerts = _readLocalPanicEvents();
    final mergedById = <String, CounselorPanicAlert>{
      for (final a in localAlerts) a.id: a,
    };

    final client = ref.read(supabaseClientProvider);
    if (client != null && client.auth.currentSession != null) {
      try {
        final rows = await client
            .from('panic_events')
            .select(
              'id, student_name, class_name, school_name, location_label, area_hint, situation_note, status, started_at, lat, lng',
            )
            .order('started_at', ascending: false)
            .limit(30);
        for (final r
            in (rows as List<dynamic>).whereType<Map<String, dynamic>>()) {
          final parsed = CounselorPanicAlert.fromMap(r);
          if (parsed.id.isEmpty) continue;
          final existing = mergedById[parsed.id];
          mergedById[parsed.id] = existing?.status == 'resolved'
              ? parsed.copyWith(status: 'resolved')
              : parsed;
        }
      } on Object {
        // Keep local alerts if offline or query failed.
      }
    }

    if (_disposed || activeGen != _buildGen) return;
    final list = mergedById.values.toList()
      ..sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        final aTime = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    state = list;
  }

  Future<void> resolveAlert(String alertId) async {
    state = [
      for (final alert in state)
        if (alert.id == alertId) alert.copyWith(status: 'resolved') else alert,
    ];

    final prefs = ref.read(localPreferencesServiceProvider);
    final raw = prefs.getString(kLocalPanicEventsPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final updated = decoded
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .map((item) {
            if (item['id']?.toString() == alertId) {
              return {...item, 'status': 'resolved'};
            }
            return item;
          }).toList();
          await prefs.setString(
            kLocalPanicEventsPrefsKey,
            jsonEncode(updated),
          );
        }
      } on Object {
        // Ignore decode issues.
      }
    }

    final client = ref.read(supabaseClientProvider);
    if (client != null && client.auth.currentSession != null) {
      try {
        await client.from('panic_events').update({
          'status': 'resolved',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', alertId);
      } on Object {
        // Best-effort remote update.
      }
    }
  }
}

final counselorPanicAlertsProvider =
    NotifierProvider<CounselorPanicAlertsController, List<CounselorPanicAlert>>(
  CounselorPanicAlertsController.new,
);
