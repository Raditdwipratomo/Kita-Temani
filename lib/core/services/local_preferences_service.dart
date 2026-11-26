import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

class LocalPreferencesService {
  LocalPreferencesService(this._prefs);

  final SharedPreferences? _prefs;
  final Map<String, Object> _fallback = {};

  bool getBool(String key, {bool defaultValue = false}) {
    final p = _prefs;
    if (p != null) return p.getBool(key) ?? defaultValue;
    return (_fallback[key] as bool?) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    _fallback[key] = value;
    await _prefs?.setBool(key, value);
  }

  String? getString(String key) {
    final p = _prefs;
    if (p != null) return p.getString(key);
    return _fallback[key] as String?;
  }

  Future<void> setString(String key, String value) async {
    _fallback[key] = value;
    await _prefs?.setString(key, value);
  }

  Future<void> remove(String key) async {
    _fallback.remove(key);
    await _prefs?.remove(key);
  }

  Future<void> removeByPrefix(String prefix) async {
    _fallback.removeWhere((k, _) => k.startsWith(prefix));
    final p = _prefs;
    if (p != null) {
      final matching =
          p.getKeys().where((k) => k.startsWith(prefix)).toList(growable: false);
      for (final key in matching) {
        await p.remove(key);
      }
    }
  }

  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } on Object {
      // Corrupted JSON falls back cleanly to empty list.
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> items) async {
    await setString(key, jsonEncode(items));
  }
}

final localPreferencesServiceProvider =
    Provider<LocalPreferencesService>((ref) {
  return LocalPreferencesService(ref.watch(sharedPreferencesProvider));
});
