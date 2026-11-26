import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:kitatemani/core/services/web_permission_state.dart';
import 'package:web/web.dart' as web;

@JS()
extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({required String name});
}

WebPermissionQueryState _mapState(String rawState) {
  return switch (rawState.trim().toLowerCase()) {
    'granted' => WebPermissionQueryState.granted,
    'denied' => WebPermissionQueryState.denied,
    'prompt' => WebPermissionQueryState.prompt,
    _ => WebPermissionQueryState.unsupported,
  };
}

/// Passively queries a browser permission state (`camera`, `microphone`,
/// `geolocation`) without triggering a permission prompt dialog.
Future<WebPermissionQueryState> queryWebPermission(String name) async {
  final nav = web.window.navigator;
  if (nav.hasProperty('permissions'.toJS).toDart) {
    try {
      final status = await nav.permissions
          .query(_PermissionDescriptor(name: name))
          .toDart
          .timeout(const Duration(seconds: 3));
      final mapped = _mapState(status.state);
      if (mapped != WebPermissionQueryState.unsupported) {
        return mapped;
      }
    } on Object {
      // Safari / older Firefox throw TypeError for camera/microphone names;
      // fall back to mediaDevices label inspection below.
    }
  }

  if ((name == 'camera' || name == 'microphone') &&
      nav.hasProperty('mediaDevices'.toJS).toDart) {
    try {
      final targetKind = name == 'camera' ? 'videoinput' : 'audioinput';
      final devices = (await nav.mediaDevices
              .enumerateDevices()
              .toDart
              .timeout(const Duration(seconds: 3)))
          .toDart;
      final hasMatching = devices.any((d) => d.kind == targetKind);
      if (!hasMatching) return WebPermissionQueryState.unsupported;
      final hasLabel = devices.any(
        (d) => d.kind == targetKind && d.label.trim().isNotEmpty,
      );
      return hasLabel
          ? WebPermissionQueryState.granted
          : WebPermissionQueryState.prompt;
    } on Object {
      return WebPermissionQueryState.unsupported;
    }
  }

  return WebPermissionQueryState.unsupported;
}

/// Requests browser camera and/or microphone permission directly via
/// `navigator.mediaDevices.getUserMedia` and immediately releases tracks.
Future<WebPermissionQueryState> requestWebMediaPermission({
  required bool video,
  required bool audio,
}) async {
  final nav = web.window.navigator;
  if (!nav.hasProperty('mediaDevices'.toJS).toDart) {
    return WebPermissionQueryState.unsupported;
  }

  try {
    final stream = await nav.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(
            video: video.toJS,
            audio: audio.toJS,
          ),
        )
        .toDart
        .timeout(const Duration(seconds: 15));
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    return WebPermissionQueryState.granted;
  } on Object catch (e) {
    final targetName = video && !audio
        ? 'camera'
        : (!video && audio ? 'microphone' : 'camera');
    final queried = await queryWebPermission(targetName);
    if (queried != WebPermissionQueryState.unsupported) {
      return queried;
    }
    final raw = e.toString().toLowerCase();
    if (raw.contains('notallowed') ||
        raw.contains('permission') ||
        raw.contains('denied')) {
      return WebPermissionQueryState.denied;
    }
    return WebPermissionQueryState.prompt;
  }
}

/// Emits whenever browser permission state or tab focus/visibility changes,
/// allowing real-time synchronization with Chrome Site Settings toggles.
Stream<void> watchWebPermissionChanges(List<String> names) {
  final trackedStatuses = <web.PermissionStatus>[];
  var isCancelled = false;

  late final StreamController<void> controller;
  late final web.EventListener onPermissionChange;
  late final web.EventListener onFocus;
  late final web.EventListener onVisibilityChange;
  late final web.EventListener onDeviceChange;

  void emitChange() {
    if (!isCancelled && !controller.isClosed) {
      controller.add(null);
    }
  }

  Future<void> attachPermissionObserver(String name) async {
    final nav = web.window.navigator;
    if (!nav.hasProperty('permissions'.toJS).toDart) return;
    try {
      final status = await nav.permissions
          .query(_PermissionDescriptor(name: name))
          .toDart
          .timeout(const Duration(seconds: 3));
      if (isCancelled || controller.isClosed) return;
      // Keep a strong reference so Chrome doesn't GC the PermissionStatus object.
      trackedStatuses.add(status);
      status.addEventListener('change', onPermissionChange);
    } on Object {
      // Unsupported permission descriptor on this browser; window/focus listeners
      // still refresh permissions cleanly.
    }
  }

  controller = StreamController<void>(
    onListen: () {
      onPermissionChange = ((web.Event _) => emitChange()).toJS;
      onFocus = ((web.Event _) => emitChange()).toJS;
      onDeviceChange = ((web.Event _) => emitChange()).toJS;
      onVisibilityChange = ((web.Event _) {
        if (!web.document.hidden) emitChange();
      }).toJS;

      web.window.addEventListener('focus', onFocus);
      web.document.addEventListener('visibilitychange', onVisibilityChange);
      final nav = web.window.navigator;
      if (nav.hasProperty('mediaDevices'.toJS).toDart) {
        try {
          nav.mediaDevices.addEventListener('devicechange', onDeviceChange);
        } on Object {
          // Ignore browsers without EventTarget support on mediaDevices.
        }
      }
      for (final name in names) {
        unawaited(attachPermissionObserver(name));
      }
    },
    onCancel: () {
      isCancelled = true;
      web.window.removeEventListener('focus', onFocus);
      web.document.removeEventListener('visibilitychange', onVisibilityChange);
      final nav = web.window.navigator;
      if (nav.hasProperty('mediaDevices'.toJS).toDart) {
        try {
          nav.mediaDevices.removeEventListener('devicechange', onDeviceChange);
        } on Object {
          // Ignore cleanup errors.
        }
      }
      for (final status in trackedStatuses) {
        try {
          status.removeEventListener('change', onPermissionChange);
        } on Object {
          // Ignore cleanup errors.
        }
      }
      trackedStatuses.clear();
    },
  );

  return controller.stream;
}
