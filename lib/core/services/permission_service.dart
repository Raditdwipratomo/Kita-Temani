import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kitatemani/core/services/web_permission_bridge.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum AppPermission {
  camera(
    'Kamera & Bukti',
    'Membuka kamera langsung untuk merekam foto atau video bukti kejadian.',
  ),
  location(
    'Lokasi GPS Presisi',
    'Menyertakan koordinat lokasi hanya saat kamu menahan Tombol Darurat.',
  ),
  microphone(
    'Mikrofon Darurat',
    'Merekam suara sekitar saat Tombol Darurat aktif atau merekam video bukti.',
  ),
  sms(
    'Kirim SMS Darurat',
    'Mengirim pesan darurat otomatis ke kontak keluarga & Guru BK saat SOS aktif.',
  ),
  phone(
    'Panggilan Cepat',
    'Memudahkan menghubungi kontak utama atau Guru BK saat situasi darurat.',
  );

  const AppPermission(this.label, this.description);
  final String label;
  final String description;
}

enum AppPermissionState {
  granted,
  denied,
  permanentlyDenied,
  mobileOnly,
}

abstract interface class PermissionService {
  Future<Map<AppPermission, bool>> checkAll();
  Future<Map<AppPermission, AppPermissionState>> checkDetailed();
  Stream<Map<AppPermission, AppPermissionState>> watchDetailed();
  Future<bool> request(AppPermission permission);
  Future<AppPermissionState> requestDetailed(AppPermission permission);
  Future<Map<AppPermission, bool>> requestEmergencyBundle();
  Future<bool> openSettings();
}

class DevicePermissionService implements PermissionService {
  final Map<AppPermission, AppPermissionState> _cached = {
    for (final perm in AppPermission.values) perm: AppPermissionState.denied,
  };

  ph.Permission _mapPermission(AppPermission p) {
    return switch (p) {
      AppPermission.sms => ph.Permission.sms,
      AppPermission.location => ph.Permission.locationWhenInUse,
      AppPermission.microphone => ph.Permission.microphone,
      AppPermission.phone => ph.Permission.phone,
      AppPermission.camera => ph.Permission.camera,
    };
  }

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  AppPermissionState? _fromWebQueryState(WebPermissionQueryState state) {
    return switch (state) {
      WebPermissionQueryState.granted => AppPermissionState.granted,
      WebPermissionQueryState.denied => AppPermissionState.permanentlyDenied,
      WebPermissionQueryState.prompt => AppPermissionState.denied,
      WebPermissionQueryState.unsupported => null,
    };
  }

  AppPermissionState _fromPhStatus(ph.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AppPermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionState.permanentlyDenied;
    }
    return AppPermissionState.denied;
  }

  Future<AppPermissionState> _checkWebLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      return switch (perm) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          AppPermissionState.granted,
        LocationPermission.deniedForever =>
          AppPermissionState.permanentlyDenied,
        _ => AppPermissionState.denied,
      };
    } on Object {
      return AppPermissionState.denied;
    }
  }

  Future<AppPermissionState> _requestWebLocation() async {
    try {
      final perm = await Geolocator.requestPermission();
      return switch (perm) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          AppPermissionState.granted,
        LocationPermission.deniedForever =>
          AppPermissionState.permanentlyDenied,
        _ => AppPermissionState.denied,
      };
    } on Object {
      return AppPermissionState.denied;
    }
  }

  Future<AppPermissionState> _requestWebCameraOrMic({
    required bool includeAudio,
  }) async {
    try {
      final cameras =
          await availableCameras().timeout(const Duration(seconds: 8));
      if (cameras.isEmpty) return AppPermissionState.denied;
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: includeAudio,
      );
      try {
        await controller.initialize().timeout(const Duration(seconds: 8));
        return AppPermissionState.granted;
      } finally {
        await controller.dispose();
      }
    } on CameraException catch (e) {
      final raw = '${e.code} ${e.description ?? ''}'.toLowerCase();
      if (raw.contains('denied') ||
          raw.contains('notallowed') ||
          raw.contains('permission')) {
        return AppPermissionState.permanentlyDenied;
      }
      return AppPermissionState.denied;
    } on Object {
      return AppPermissionState.denied;
    }
  }

  @override
  Future<Map<AppPermission, AppPermissionState>> checkDetailed() async {
    if (kIsWeb) {
      final results = await Future.wait<WebPermissionQueryState>([
        queryWebPermission('camera'),
        queryWebPermission('microphone'),
        queryWebPermission('geolocation'),
      ]);
      _cached[AppPermission.camera] =
          _fromWebQueryState(results[0]) ?? _cached[AppPermission.camera]!;
      _cached[AppPermission.microphone] =
          _fromWebQueryState(results[1]) ?? _cached[AppPermission.microphone]!;
      _cached[AppPermission.location] =
          _fromWebQueryState(results[2]) ?? await _checkWebLocation();
      _cached[AppPermission.sms] = AppPermissionState.mobileOnly;
      _cached[AppPermission.phone] = AppPermissionState.mobileOnly;
      return Map<AppPermission, AppPermissionState>.unmodifiable(_cached);
    }

    if (!_isMobilePlatform) {
      return {
        for (final p in AppPermission.values)
          p: (p == AppPermission.sms || p == AppPermission.phone)
              ? AppPermissionState.mobileOnly
              : AppPermissionState.granted,
      };
    }

    try {
      for (final perm in AppPermission.values) {
        final status = await _mapPermission(perm).status;
        _cached[perm] = _fromPhStatus(status);
      }
      return Map<AppPermission, AppPermissionState>.unmodifiable(_cached);
    } on MissingPluginException {
      for (final perm in AppPermission.values) {
        _cached[perm] = AppPermissionState.granted;
      }
      return Map<AppPermission, AppPermissionState>.unmodifiable(_cached);
    } on Object {
      return Map<AppPermission, AppPermissionState>.unmodifiable(_cached);
    }
  }

  @override
  Stream<Map<AppPermission, AppPermissionState>> watchDetailed() {
    if (!kIsWeb) {
      return const Stream<Map<AppPermission, AppPermissionState>>.empty();
    }
    return watchWebPermissionChanges(
      const ['camera', 'microphone', 'geolocation'],
    ).asyncMap((_) => checkDetailed());
  }

  @override
  Future<Map<AppPermission, bool>> checkAll() async {
    final detailed = await checkDetailed();
    return {
      for (final entry in detailed.entries)
        entry.key: entry.value == AppPermissionState.granted,
    };
  }

  @override
  Future<AppPermissionState> requestDetailed(AppPermission permission) async {
    if (kIsWeb) {
      if (permission == AppPermission.sms ||
          permission == AppPermission.phone) {
        _cached[permission] = AppPermissionState.mobileOnly;
        return AppPermissionState.mobileOnly;
      }
      if (permission == AppPermission.location) {
        final state = await _requestWebLocation();
        final queried = _fromWebQueryState(
          await queryWebPermission('geolocation'),
        );
        final resolved = queried ?? state;
        _cached[AppPermission.location] = resolved;
        return resolved;
      }
      if (permission == AppPermission.camera) {
        final webState = await requestWebMediaPermission(
          video: true,
          audio: false,
        );
        final resolved = _fromWebQueryState(webState) ??
            await _requestWebCameraOrMic(includeAudio: false);
        _cached[AppPermission.camera] = resolved;
        return resolved;
      }
      if (permission == AppPermission.microphone) {
        final webState = await requestWebMediaPermission(
          video: false,
          audio: true,
        );
        final resolved = _fromWebQueryState(webState) ??
            await _requestWebCameraOrMic(includeAudio: true);
        _cached[AppPermission.microphone] = resolved;
        return resolved;
      }
    }

    if (!_isMobilePlatform) {
      final state =
          (permission == AppPermission.sms || permission == AppPermission.phone)
              ? AppPermissionState.mobileOnly
              : AppPermissionState.granted;
      _cached[permission] = state;
      return state;
    }

    try {
      final status = await _mapPermission(permission).request();
      final state = _fromPhStatus(status);
      _cached[permission] = state;
      return state;
    } on MissingPluginException {
      _cached[permission] = AppPermissionState.granted;
      return AppPermissionState.granted;
    } on Object {
      _cached[permission] = AppPermissionState.denied;
      return AppPermissionState.denied;
    }
  }

  @override
  Future<bool> request(AppPermission permission) async {
    final state = await requestDetailed(permission);
    return state == AppPermissionState.granted;
  }

  @override
  Future<Map<AppPermission, bool>> requestEmergencyBundle() async {
    if (kIsWeb) {
      final current = await checkDetailed();
      for (final perm in const [
        AppPermission.camera,
        AppPermission.microphone,
        AppPermission.location,
      ]) {
        if (current[perm] != AppPermissionState.granted) {
          await requestDetailed(perm);
        }
      }
      return checkAll();
    }

    if (!_isMobilePlatform) {
      return {for (final p in AppPermission.values) p: true};
    }
    try {
      final results = await [
        ph.Permission.camera,
        ph.Permission.locationWhenInUse,
        ph.Permission.microphone,
        ph.Permission.sms,
        ph.Permission.phone,
      ].request();
      _cached[AppPermission.camera] = _fromPhStatus(
          results[ph.Permission.camera] ?? ph.PermissionStatus.denied);
      _cached[AppPermission.location] = _fromPhStatus(
        results[ph.Permission.locationWhenInUse] ?? ph.PermissionStatus.denied,
      );
      _cached[AppPermission.microphone] = _fromPhStatus(
        results[ph.Permission.microphone] ?? ph.PermissionStatus.denied,
      );
      _cached[AppPermission.sms] = _fromPhStatus(
          results[ph.Permission.sms] ?? ph.PermissionStatus.denied);
      _cached[AppPermission.phone] = _fromPhStatus(
        results[ph.Permission.phone] ?? ph.PermissionStatus.denied,
      );
      return {
        for (final entry in _cached.entries)
          entry.key: entry.value == AppPermissionState.granted,
      };
    } on MissingPluginException {
      return {for (final p in AppPermission.values) p: true};
    } on Object {
      return {
        for (final entry in _cached.entries)
          entry.key: entry.value == AppPermissionState.granted,
      };
    }
  }

  @override
  Future<bool> openSettings() async {
    if (kIsWeb) return false;
    try {
      return await ph.openAppSettings();
    } on Object {
      return false;
    }
  }
}

class DummyPermissionService implements PermissionService {
  final Map<AppPermission, AppPermissionState> _status = {
    for (final perm in AppPermission.values) perm: AppPermissionState.granted,
  };

  @override
  Future<Map<AppPermission, AppPermissionState>> checkDetailed() async {
    return Map<AppPermission, AppPermissionState>.unmodifiable(_status);
  }

  @override
  Stream<Map<AppPermission, AppPermissionState>> watchDetailed() {
    return const Stream<Map<AppPermission, AppPermissionState>>.empty();
  }

  @override
  Future<Map<AppPermission, bool>> checkAll() async {
    return {
      for (final entry in _status.entries)
        entry.key: entry.value == AppPermissionState.granted,
    };
  }

  @override
  Future<AppPermissionState> requestDetailed(AppPermission permission) async {
    _status[permission] = AppPermissionState.granted;
    return AppPermissionState.granted;
  }

  @override
  Future<bool> request(AppPermission permission) async {
    await requestDetailed(permission);
    return true;
  }

  @override
  Future<Map<AppPermission, bool>> requestEmergencyBundle() async {
    for (final perm in AppPermission.values) {
      _status[perm] = AppPermissionState.granted;
    }
    return checkAll();
  }

  @override
  Future<bool> openSettings() async => true;
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return DevicePermissionService();
});

class PermissionsController
    extends Notifier<Map<AppPermission, AppPermissionState>> {
  @override
  Map<AppPermission, AppPermissionState> build() {
    final service = ref.read(permissionServiceProvider);
    final sub = service.watchDetailed().listen(
      (next) {
        if (!mapEquals(state, next)) {
          state = next;
        }
      },
      onError: (Object _) {},
    );
    ref.onDispose(() => unawaited(sub.cancel()));
    Future.microtask(refresh);
    return {
      for (final perm in AppPermission.values)
        perm: (kIsWeb &&
                (perm == AppPermission.sms || perm == AppPermission.phone))
            ? AppPermissionState.mobileOnly
            : AppPermissionState.denied,
    };
  }

  Future<void> refresh() async {
    final next = await ref.read(permissionServiceProvider).checkDetailed();
    if (!mapEquals(state, next)) {
      state = next;
    }
  }

  Future<AppPermissionState> requestOne(AppPermission permission) async {
    final result =
        await ref.read(permissionServiceProvider).requestDetailed(permission);
    state = {...state, permission: result};
    await refresh();
    return state[permission] ?? result;
  }

  Future<void> requestAllNeeded() async {
    await ref.read(permissionServiceProvider).requestEmergencyBundle();
    await refresh();
  }

  Future<bool> openSystemSettings() {
    return ref.read(permissionServiceProvider).openSettings();
  }
}

final permissionsControllerProvider = NotifierProvider<PermissionsController,
    Map<AppPermission, AppPermissionState>>(
  PermissionsController.new,
);
