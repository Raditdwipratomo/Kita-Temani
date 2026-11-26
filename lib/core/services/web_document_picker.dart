import 'dart:typed_data';

import 'web_document_picker_stub.dart'
    if (dart.library.js_interop) 'web_document_picker_web.dart' as impl;

class PickedRawDocument {
  const PickedRawDocument({
    required this.fileName,
    this.bytes,
    required this.sizeBytes,
  });

  final String fileName;
  final Uint8List? bytes;
  final int sizeBytes;
}

Future<PickedRawDocument?> pickWebDocument({
  required int maxBytes,
  required String accept,
}) =>
    impl.pickWebDocument(maxBytes: maxBytes, accept: accept);
