import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/features/emergency_contacts/domain/entities/emergency_contact.dart';
import 'package:kitatemani/features/emergency_contacts/domain/repositories/emergency_contact_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const List<EmergencyContact> defaultSeedContacts = [];

class FullstackEmergencyContactRepository
    implements EmergencyContactRepository {
  FullstackEmergencyContactRepository({
    required SupabaseClient? client,
    required LocalPreferencesService prefs,
  })  : _client = client,
        _prefs = prefs;

  static const String _cacheKey = 'kt_emergency_contacts_json';
  static const _uuid = Uuid();

  final SupabaseClient? _client;
  final LocalPreferencesService _prefs;
  List<EmergencyContact>? _inMemory;

  Future<List<EmergencyContact>> _loadLocal() async {
    if (_inMemory != null) return List<EmergencyContact>.from(_inMemory!);
    final raw = _prefs.getJsonList(_cacheKey);
    if (raw.isNotEmpty) {
      final list = raw
          .map(EmergencyContact.fromJson)
          // Ignore legacy hardcoded non-UUID demo contacts if cached locally.
          .where((c) => _isUuid(c.id))
          .toList();
      _inMemory = list;
      return List<EmergencyContact>.from(list);
    }
    _inMemory = <EmergencyContact>[];
    return <EmergencyContact>[];
  }

  Future<void> _saveLocal(List<EmergencyContact> items) async {
    _inMemory = List<EmergencyContact>.from(items);
    await _prefs.setJsonList(_cacheKey, items.map((e) => e.toJson()).toList());
  }

  String? get _activeUid => _client?.auth.currentUser?.id;

  bool _isUuid(String id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id.trim());

  @override
  Future<List<EmergencyContact>> getAll() async {
    final client = _client;
    final uid = _activeUid;
    if (client != null && uid != null) {
      try {
        final rows = await client
            .from('emergency_contacts')
            .select('id, name, role_label, phone, is_active, is_primary')
            .eq('user_id', uid)
            .order('is_primary', ascending: false)
            .order('created_at', ascending: true);

        final remote = (rows as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(EmergencyContact.fromJson)
            .toList();
        await _saveLocal(remote);
        return remote;
      } on Object {
        // Fallback to cached local list if offline.
      }
    }
    return _loadLocal();
  }

  @override
  Future<List<EmergencyContact>> activeContacts() async {
    final all = await getAll();
    return all.where((c) => c.isActive).toList(growable: false);
  }

  @override
  Future<EmergencyContact?> primaryContact() async {
    final all = await getAll();
    for (final c in all) {
      if (c.isPrimary && c.isActive) return c;
    }
    for (final c in all) {
      if (c.isPrimary) return c;
    }
    for (final c in all) {
      if (c.isActive) return c;
    }
    return all.isNotEmpty ? all.first : null;
  }

  @override
  Future<Result<List<EmergencyContact>>> saveContact(
    EmergencyContact contact,
  ) async {
    final list = await _loadLocal();
    final existingIdx = list.indexWhere((c) => c.id == contact.id);
    if (existingIdx == -1 && list.length >= 5) {
      return const Err(
        ValidationFailure('Maksimal 5 kontak darurat yang dapat disimpan.'),
      );
    }

    final resolvedId = _isUuid(contact.id) ? contact.id : _uuid.v4();
    final normalized =
        existingIdx >= 0 ? contact : contact.copyWith(id: resolvedId);

    if (normalized.isPrimary) {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isPrimary: false);
      }
    }

    if (existingIdx >= 0) {
      list[existingIdx] = normalized;
    } else {
      list.add(normalized);
    }
    _ensureOnePrimary(list);
    await _saveLocal(list);

    final client = _client;
    final uid = _activeUid;
    if (client != null && uid != null && _isUuid(normalized.id)) {
      try {
        if (normalized.isPrimary) {
          await client
              .from('emergency_contacts')
              .update({'is_primary': false})
              .eq('user_id', uid)
              .neq('id', normalized.id);
        }
        await client.from('emergency_contacts').upsert({
          'id': normalized.id,
          'user_id': uid,
          'name': normalized.name,
          'role_label': normalized.roleLabel,
          'phone': normalized.phone,
          'is_active': normalized.isActive,
          'is_primary': normalized.isPrimary,
        });
      } on Object {
        // Already cached locally cleanly.
      }
    }

    return Ok(List<EmergencyContact>.unmodifiable(list));
  }

  @override
  Future<Result<List<EmergencyContact>>> toggleActive(
    String id,
    bool isActive,
  ) async {
    final list = await _loadLocal();
    final idx = list.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(isActive: isActive);
    }
    _ensureOnePrimary(list);
    await _saveLocal(list);

    final client = _client;
    final uid = _activeUid;
    if (client != null && uid != null && _isUuid(id)) {
      try {
        await client
            .from('emergency_contacts')
            .update({'is_active': isActive})
            .eq('id', id)
            .eq('user_id', uid);
      } on Object {
        // Cached locally.
      }
    }

    return Ok(List<EmergencyContact>.unmodifiable(list));
  }

  @override
  Future<Result<List<EmergencyContact>>> setPrimary(String id) async {
    final list = await _loadLocal();
    for (var i = 0; i < list.length; i++) {
      final isTarget = list[i].id == id;
      list[i] = list[i].copyWith(
        isPrimary: isTarget,
        isActive: isTarget ? true : list[i].isActive,
      );
    }
    await _saveLocal(list);

    final client = _client;
    final uid = _activeUid;
    if (client != null && uid != null && _isUuid(id)) {
      try {
        await client
            .from('emergency_contacts')
            .update({'is_primary': false})
            .eq('user_id', uid)
            .neq('id', id);
        await client
            .from('emergency_contacts')
            .update({'is_primary': true, 'is_active': true})
            .eq('id', id)
            .eq('user_id', uid);
      } on Object {
        // Cached locally.
      }
    }

    return Ok(List<EmergencyContact>.unmodifiable(list));
  }

  @override
  Future<Result<List<EmergencyContact>>> deleteContact(String id) async {
    final list = await _loadLocal();
    list.removeWhere((c) => c.id == id);
    _ensureOnePrimary(list);
    await _saveLocal(list);

    final client = _client;
    final uid = _activeUid;
    if (client != null && uid != null && _isUuid(id)) {
      try {
        await client
            .from('emergency_contacts')
            .delete()
            .eq('id', id)
            .eq('user_id', uid);
      } on Object {
        // Cached locally.
      }
    }

    return Ok(List<EmergencyContact>.unmodifiable(list));
  }

  void _ensureOnePrimary(List<EmergencyContact> list) {
    if (list.isEmpty) return;
    if (list.any((c) => c.isPrimary)) return;
    final firstActiveIdx = list.indexWhere((c) => c.isActive);
    final targetIdx = firstActiveIdx >= 0 ? firstActiveIdx : 0;
    list[targetIdx] = list[targetIdx].copyWith(isPrimary: true);
  }
}

/// Backward-compatible alias used in unit tests.
class DummyEmergencyContactRepository
    extends FullstackEmergencyContactRepository {
  DummyEmergencyContactRepository()
      : super(client: null, prefs: LocalPreferencesService(null));
}
