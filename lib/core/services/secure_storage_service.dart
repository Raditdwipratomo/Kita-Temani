import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clearAll();
}

/// Device keystore storage backed by [FlutterSecureStorage] with automatic
/// in-memory fallback for headless unit/widget test environments.
class DeviceSecureStorageService implements SecureStorageService {
  DeviceSecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};

  @override
  Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);
      return value ?? _memoryFallback[key];
    } on MissingPluginException {
      return _memoryFallback[key];
    } on PlatformException {
      return _memoryFallback[key];
    } on UnimplementedError {
      return _memoryFallback[key];
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // Fallback map already updated.
    } on PlatformException {
      // Fallback map already updated.
    } on UnimplementedError {
      // Fallback map already updated.
    }
  }

  @override
  Future<void> delete(String key) async {
    _memoryFallback.remove(key);
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // Fallback map already updated.
    } on PlatformException {
      // Fallback map already updated.
    } on UnimplementedError {
      // Fallback map already updated.
    }
  }

  @override
  Future<void> clearAll() async {
    _memoryFallback.clear();
    try {
      await _storage.deleteAll();
    } on Object {
      // Ignore in test environments.
    }
  }
}

class InMemorySecureStorageService implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return DeviceSecureStorageService();
});
