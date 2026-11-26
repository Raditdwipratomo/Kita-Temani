import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Uint8List?> readFileBytes(String? path) async {
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}

Future<String?> writeTempBytes(String fileName, Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final cleanPath = '${tempDir.path}/$fileName';
  await File(cleanPath).writeAsBytes(bytes, flush: true);
  return cleanPath;
}
