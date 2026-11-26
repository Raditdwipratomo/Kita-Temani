import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kitatemani/core/services/permission_service.dart';
import 'package:kitatemani/features/profile/presentation/screens/app_permissions_screen.dart';
import 'package:kitatemani/features/profile/presentation/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRealtimePermissionService implements PermissionService {
  _FakeRealtimePermissionService(
    Map<AppPermission, AppPermissionState> initial,
  ) : _current = Map<AppPermission, AppPermissionState>.from(initial);

  Map<AppPermission, AppPermissionState> _current;
  final StreamController<Map<AppPermission, AppPermissionState>> _controller =
      StreamController<Map<AppPermission, AppPermissionState>>.broadcast();

  void emitUpdate(Map<AppPermission, AppPermissionState> next) {
    _current = Map<AppPermission, AppPermissionState>.from(next);
    _controller
        .add(Map<AppPermission, AppPermissionState>.unmodifiable(_current));
  }

  void setSilentUpdate(Map<AppPermission, AppPermissionState> next) {
    _current = Map<AppPermission, AppPermissionState>.from(next);
  }

  Future<void> dispose() => _controller.close();

  @override
  Future<Map<AppPermission, AppPermissionState>> checkDetailed() async {
    return Map<AppPermission, AppPermissionState>.unmodifiable(_current);
  }

  @override
  Stream<Map<AppPermission, AppPermissionState>> watchDetailed() {
    return _controller.stream;
  }

  @override
  Future<Map<AppPermission, bool>> checkAll() async {
    return {
      for (final entry in _current.entries)
        entry.key: entry.value == AppPermissionState.granted,
    };
  }

  @override
  Future<AppPermissionState> requestDetailed(AppPermission permission) async {
    _current[permission] = AppPermissionState.granted;
    return AppPermissionState.granted;
  }

  @override
  Future<bool> request(AppPermission permission) async {
    await requestDetailed(permission);
    return true;
  }

  @override
  Future<Map<AppPermission, bool>> requestEmergencyBundle() async {
    for (final perm in const [
      AppPermission.camera,
      AppPermission.microphone,
      AppPermission.location,
    ]) {
      _current[perm] = AppPermissionState.granted;
    }
    return checkAll();
  }

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'AppPermissionsScreen sinkron otomatis secara real-time saat status izin berubah',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _FakeRealtimePermissionService(const {
      AppPermission.camera: AppPermissionState.denied,
      AppPermission.microphone: AppPermissionState.denied,
      AppPermission.location: AppPermissionState.denied,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: AppPermissionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 dari 3 izin aktif'), findsOneWidget);
    expect(find.text('Belum aktif'), findsNWidgets(3));
    expect(find.text('Aktifkan semua izin penting'), findsOneWidget);
    expect(
      find.text('Sinkron otomatis dengan izin perangkat'),
      findsOneWidget,
    );

    // Simulasi browser/device mengizinkan kamera & lokasi tanpa menekan refresh
    fake.emitUpdate(const {
      AppPermission.camera: AppPermissionState.granted,
      AppPermission.microphone: AppPermissionState.denied,
      AppPermission.location: AppPermissionState.granted,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    await tester.pumpAndSettle();

    expect(find.text('2 dari 3 izin aktif'), findsOneWidget);
    expect(find.text('Aktif'), findsNWidgets(2));
    expect(find.text('Belum aktif'), findsOneWidget);

    // Simulasi perubahan menjadi diblokir & mikrofon diizinkan
    fake.emitUpdate(const {
      AppPermission.camera: AppPermissionState.granted,
      AppPermission.microphone: AppPermissionState.granted,
      AppPermission.location: AppPermissionState.permanentlyDenied,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    await tester.pumpAndSettle();

    expect(find.text('2 dari 3 izin aktif'), findsOneWidget);
    expect(find.text('Diblokir'), findsOneWidget);

    // Simulasi ketiga izin aktif seluruhnya
    fake.emitUpdate(const {
      AppPermission.camera: AppPermissionState.granted,
      AppPermission.microphone: AppPermissionState.granted,
      AppPermission.location: AppPermissionState.granted,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    await tester.pumpAndSettle();

    expect(find.text('3 dari 3 izin aktif'), findsOneWidget);
    expect(find.text('Aktif'), findsNWidgets(3));
    expect(find.text('Aktifkan semua izin penting'), findsNothing);
  });

  testWidgets(
      'AppPermissionsScreen melakukan sinkronisasi ulang saat aplikasi kembali aktif (resumed)',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _FakeRealtimePermissionService(const {
      AppPermission.camera: AppPermissionState.denied,
      AppPermission.microphone: AppPermissionState.denied,
      AppPermission.location: AppPermissionState.denied,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: AppPermissionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 dari 3 izin aktif'), findsOneWidget);

    // Izin diubah di Pengaturan OS lalu user kembali ke aplikasi
    fake.setSilentUpdate(const {
      AppPermission.camera: AppPermissionState.granted,
      AppPermission.microphone: AppPermissionState.granted,
      AppPermission.location: AppPermissionState.granted,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('3 dari 3 izin aktif'), findsOneWidget);
    expect(find.text('Aktif'), findsNWidgets(3));
  });

  testWidgets('ProfileScreen memperbarui ringkasan izin secara real-time',
      (tester) async {
    final fake = _FakeRealtimePermissionService(const {
      AppPermission.camera: AppPermissionState.denied,
      AppPermission.microphone: AppPermissionState.denied,
      AppPermission.location: AppPermissionState.denied,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    addTearDown(fake.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Izin aplikasi: 0/3 aktif · ketuk untuk atur'),
      findsOneWidget,
    );

    fake.emitUpdate(const {
      AppPermission.camera: AppPermissionState.granted,
      AppPermission.microphone: AppPermissionState.granted,
      AppPermission.location: AppPermissionState.granted,
      AppPermission.sms: AppPermissionState.mobileOnly,
      AppPermission.phone: AppPermissionState.mobileOnly,
    });
    await tester.pumpAndSettle();

    expect(
      find.text('Izin kamera, lokasi & mikrofon aktif (3/3)'),
      findsOneWidget,
    );
  });
}
