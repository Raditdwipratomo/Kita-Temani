import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:kitatemani/core/services/web_document_picker.dart';
import 'package:web/web.dart' as web;

Future<PickedRawDocument?> pickWebDocument({
  required int maxBytes,
  required String accept,
}) {
  final completer = Completer<PickedRawDocument?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = false;

  late final web.EventListener onChange;
  late final web.EventListener onCancel;
  late final web.EventListener onWindowFocus;
  Timer? fallbackTimer;

  void cleanup() {
    fallbackTimer?.cancel();
    input.removeEventListener('change', onChange);
    input.removeEventListener('cancel', onCancel);
    web.window.removeEventListener('focus', onWindowFocus);
  }

  void finish(PickedRawDocument? result) {
    if (completer.isCompleted) return;
    cleanup();
    completer.complete(result);
  }

  Future<void> handleChange() async {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }

    final size = file.size;
    if (size > maxBytes || size <= 0) {
      finish(
        PickedRawDocument(
          fileName: file.name,
          bytes: null,
          sizeBytes: size,
        ),
      );
      return;
    }

    try {
      final buffer = await file.arrayBuffer().toDart;
      final bytes = Uint8List.view(buffer.toDart);
      finish(
        PickedRawDocument(
          fileName: file.name,
          bytes: bytes,
          sizeBytes: bytes.length,
        ),
      );
    } on Object {
      finish(
        PickedRawDocument(
          fileName: file.name,
          bytes: null,
          sizeBytes: size,
        ),
      );
    }
  }

  onChange = ((web.Event _) {
    unawaited(handleChange());
  }).toJS;

  onCancel = ((web.Event _) {
    finish(null);
  }).toJS;

  onWindowFocus = ((web.Event _) {
    fallbackTimer?.cancel();
    fallbackTimer = Timer(const Duration(milliseconds: 400), () {
      if (!completer.isCompleted) {
        final file = input.files?.item(0);
        if (file == null) {
          finish(null);
        }
      }
    });
  }).toJS;

  input.addEventListener('change', onChange);
  input.addEventListener('cancel', onCancel);
  web.window.addEventListener('focus', onWindowFocus);

  input.click();
  return completer.future;
}
