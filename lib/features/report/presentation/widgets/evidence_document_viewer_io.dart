import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:kitatemani/app/theme/app_colors.dart';
import 'package:kitatemani/app/theme/app_text_styles.dart';
import 'package:path_provider/path_provider.dart';

/// Native Android `PdfRenderer` PDF viewer with lazy page rasterization,
/// zoomable pages, and a rich metadata fallback on platforms without `PdfRenderer`.
class EvidencePdfViewer extends StatefulWidget {
  const EvidencePdfViewer({
    required this.fileName,
    this.bytes,
    this.localPath,
    this.networkUrl,
    this.onOpenExternal,
    super.key,
  });

  final String fileName;
  final Uint8List? bytes;
  final String? localPath;
  final String? networkUrl;
  final VoidCallback? onOpenExternal;

  @override
  State<EvidencePdfViewer> createState() => _EvidencePdfViewerState();
}

class _EvidencePdfViewerState extends State<EvidencePdfViewer> {
  static const MethodChannel _channel = MethodChannel('id.kitatemani/pdf_preview');
  static final RegExp _pdfHeaderRegex = RegExp(r'%PDF-(\d\.\d)');
  static final RegExp _pdfPageRegex = RegExp(r'/Type\s*/Page(?!s)\b');

  bool _isLoading = true;
  int _pageCount = 0;
  String? _resolvedFilePath;
  String? _tempFilePath;
  String? _fallbackMessage;
  _PdfFallbackMeta? _fallbackMeta;

  final Map<int, Uint8List> _renderedPages = {};
  final Map<int, Future<Uint8List?>> _pendingPageFutures = {};

  @override
  void initState() {
    super.initState();
    unawaited(_initPdf());
  }

  Future<void> _initPdf() async {
    try {
      String? filePath;
      Uint8List? resolvedBytes = widget.bytes;

      final candidateLocal = widget.localPath?.trim() ?? '';
      if (candidateLocal.isNotEmpty) {
        final localFile = File(candidateLocal);
        if (localFile.existsSync()) {
          filePath = candidateLocal;
        }
      }

      if ((resolvedBytes == null || resolvedBytes.isEmpty) && filePath == null) {
        final remote = widget.networkUrl?.trim() ?? '';
        if (remote.isNotEmpty) {
          final uri = Uri.tryParse(remote);
          if (uri != null &&
              (uri.scheme == 'http' || uri.scheme == 'https')) {
            final res = await http.get(uri).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              resolvedBytes = res.bodyBytes;
            }
          }
        }
      }

      if (filePath == null &&
          resolvedBytes != null &&
          resolvedBytes.isNotEmpty) {
        filePath = await _writePdfTempFile(resolvedBytes);
        _tempFilePath = filePath;
      }

      if (!mounted) {
        _cleanupTempFile();
        return;
      }

      if (filePath == null) {
        await _showFallback(
          resolvedBytes,
          null,
          'File PDF belum tersedia secara lokal atau gagal diunduh untuk pratinjau langsung.',
        );
        return;
      }

      _resolvedFilePath = filePath;

      const unavailableMessage =
          'Pratinjau render PDF native aktif pada Android & Web. Gunakan tombol Buka / Unduh untuk membuka file PDF ini.';

      if (!Platform.isAndroid &&
          !Platform.environment.containsKey('FLUTTER_TEST')) {
        await _showFallback(resolvedBytes, filePath, unavailableMessage);
        return;
      }

      try {
        final count = await _channel
            .invokeMethod<int>('getPageCount', {'filePath': filePath})
            .timeout(const Duration(seconds: 2));
        if (!mounted) return;

        if (count != null && count > 0) {
          setState(() {
            _pageCount = count;
            _isLoading = false;
          });
          return;
        }

        await _showFallback(
          resolvedBytes,
          filePath,
          'Dokumen PDF tidak memiliki halaman yang dapat dirender.',
        );
      } on MissingPluginException {
        await _showFallback(resolvedBytes, filePath, unavailableMessage);
      } on TimeoutException {
        await _showFallback(resolvedBytes, filePath, unavailableMessage);
      } on PlatformException catch (e) {
        await _showFallback(
          resolvedBytes,
          filePath,
          e.message ?? 'Gagal merender dokumen PDF di perangkat ini.',
        );
      }
    } on Object {
      await _showFallback(
        widget.bytes,
        _resolvedFilePath,
        'Gagal memuat pratinjau dokumen PDF.',
      );
    }
  }

  Future<void> _showFallback(
    Uint8List? preloadedBytes,
    String? filePath,
    String message,
  ) async {
    final metaBytes = preloadedBytes ??
        (filePath != null ? await _readFileSilently(filePath) : null);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _fallbackMeta = _inspectFallbackMeta(metaBytes, filePath);
      _fallbackMessage = message;
    });
  }

  Future<String?> _writePdfTempFile(Uint8List bytes) async {
    final safeName = widget.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final uniqueName =
        'pdf_${DateTime.now().microsecondsSinceEpoch}_$safeName';
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final testFile = File('${Directory.systemTemp.path}/kt_$uniqueName');
        testFile.writeAsBytesSync(bytes);
        return testFile.path;
      } on Object {
        return null;
      }
    }

    Directory targetDir;
    try {
      targetDir =
          await getTemporaryDirectory().timeout(const Duration(seconds: 2));
    } on Object {
      targetDir = Directory.systemTemp;
    }
    final targetPath = '${targetDir.path}/kt_$uniqueName';
    final written = await compute(
      _writeFileBytesIsolate,
      (path: targetPath, bytes: bytes),
    );
    if (written != null) return written;

    if (targetDir.path != Directory.systemTemp.path) {
      final fallbackPath = '${Directory.systemTemp.path}/kt_$uniqueName';
      return compute(
        _writeFileBytesIsolate,
        (path: fallbackPath, bytes: bytes),
      );
    }
    return null;
  }

  Future<Uint8List?> _readFileSilently(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    } on Object {
      return null;
    }
    return null;
  }

  _PdfFallbackMeta _inspectFallbackMeta(Uint8List? bytes, String? filePath) {
    var byteLength = bytes?.length ?? 0;
    if (byteLength == 0 && filePath != null) {
      try {
        final f = File(filePath);
        if (f.existsSync()) byteLength = f.lengthSync();
      } on Object {
        // Ignore stat error.
      }
    }
    String? pdfVersion;
    int? estimatedPages;
    if (bytes != null && bytes.isNotEmpty) {
      final sampleLen = bytes.length > 256 * 1024 ? 256 * 1024 : bytes.length;
      final text = latin1.decode(bytes.sublist(0, sampleLen));
      pdfVersion = _pdfHeaderRegex.firstMatch(text)?.group(1);
      final matches = _pdfPageRegex.allMatches(text).length;
      if (matches > 0) estimatedPages = matches;
    }
    return _PdfFallbackMeta(
      byteLength: byteLength,
      pdfVersion: pdfVersion,
      estimatedPages: estimatedPages,
    );
  }

  Future<Uint8List?> _loadPageBytes(int pageIndex, int targetWidth) {
    final cached = _renderedPages[pageIndex];
    if (cached != null) return Future<Uint8List?>.value(cached);

    return _pendingPageFutures.putIfAbsent(pageIndex, () async {
      final filePath = _resolvedFilePath;
      if (filePath == null) return null;
      try {
        final result = await _channel.invokeMethod<dynamic>(
          'renderPage',
          {
            'filePath': filePath,
            'pageIndex': pageIndex,
            'targetWidth': targetWidth,
          },
        );
        if (result is Uint8List && result.isNotEmpty) {
          _renderedPages[pageIndex] = result;
          return result;
        }
        if (result is List<int> && result.isNotEmpty) {
          final converted = Uint8List.fromList(result);
          _renderedPages[pageIndex] = converted;
          return converted;
        }
      } on Object {
        return null;
      } finally {
        unawaited(_pendingPageFutures.remove(pageIndex));
      }
      return null;
    });
  }

  void _cleanupTempFile() {
    final temp = _tempFilePath;
    _tempFilePath = null;
    if (temp == null) return;
    try {
      final f = File(temp);
      if (f.existsSync()) f.deleteSync();
    } on Object {
      // Ignore cleanup errors.
    }
  }

  @override
  void dispose() {
    _renderedPages.clear();
    _pendingPageFutures.clear();
    _cleanupTempFile();
    super.dispose();
  }

  String _formatSize(int byteCount) {
    if (byteCount < 1024) return '$byteCount B';
    if (byteCount < 1024 * 1024) {
      return '${(byteCount / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteCount / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('evidence_pdf_viewer'),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Menyiapkan pratinjau dokumen PDF…',
              textAlign: TextAlign.center,
              style: AppTextStyles.inter(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_pageCount > 0 && _resolvedFilePath != null) {
      final targetWidth = (MediaQuery.sizeOf(context).width *
              MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(720, 1440);

      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darurat.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.darurat.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'PDF',
                      style: AppTextStyles.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFB4AB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_pageCount halaman · Cubit untuk perbesar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RepaintBoundary(
                child: ListView.separated(
                  itemCount: _pageCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _PdfPageCard(
                    pageNumber: index + 1,
                    totalPages: _pageCount,
                    pageFuture: _loadPageBytes(index, targetWidth),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final meta = _fallbackMeta;
    final details = <String>[
      if (meta?.pdfVersion != null) 'PDF v${meta!.pdfVersion}',
      if (meta != null && meta.byteLength > 0) _formatSize(meta.byteLength),
      if (meta?.estimatedPages != null)
        '~${meta!.estimatedPages} halaman terdeteksi',
    ];

    return Container(
      key: const Key('evidence_pdf_fallback_view'),
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            size: 48,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          Text(
            widget.fileName,
            textAlign: TextAlign.center,
            style: AppTextStyles.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              details.join(' · '),
              textAlign: TextAlign.center,
              style: AppTextStyles.code(
                fontSize: 11,
                color: const Color(0xFFB7C5FF),
                letterSpacing: 0.3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _fallbackMessage ?? 'Preview PDF tidak tersedia.',
            textAlign: TextAlign.center,
            style: AppTextStyles.inter(
              fontSize: 12.5,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          if (widget.onOpenExternal != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onOpenExternal,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Buka / Unduh Dokumen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.inkNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PdfPageCard extends StatelessWidget {
  const _PdfPageCard({
    required this.pageNumber,
    required this.totalPages,
    required this.pageFuture,
  });

  final int pageNumber;
  final int totalPages;
  final Future<Uint8List?> pageFuture;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F6FC),
              border: Border(
                bottom: BorderSide(color: AppColors.borderHairline),
              ),
            ),
            child: Text(
              'Halaman $pageNumber / $totalPages',
              style: AppTextStyles.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSlate,
              ),
            ),
          ),
          FutureBuilder<Uint8List?>(
            future: pageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 360,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data;
              if (data == null || data.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Gagal merender halaman $pageNumber.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                );
              }
              return InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.5,
                child: Image.memory(
                  data,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PdfFallbackMeta {
  const _PdfFallbackMeta({
    required this.byteLength,
    this.pdfVersion,
    this.estimatedPages,
  });

  final int byteLength;
  final String? pdfVersion;
  final int? estimatedPages;
}

String? _writeFileBytesIsolate(({String path, Uint8List bytes}) args) {
  try {
    File(args.path).writeAsBytesSync(args.bytes, flush: true);
    return args.path;
  } on Object {
    return null;
  }
}
