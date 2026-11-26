import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:xml/xml.dart';

class DocxInlineRun {
  const DocxInlineRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  bool hasSameStyle(DocxInlineRun other) =>
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline;
}

sealed class DocxBlock {
  const DocxBlock();
}

class DocxParagraphBlock extends DocxBlock {
  const DocxParagraphBlock({
    required this.runs,
    this.headingLevel = 0,
    this.isListItem = false,
    this.alignment = TextAlign.start,
  });

  final List<DocxInlineRun> runs;
  final int headingLevel;
  final bool isListItem;
  final TextAlign alignment;

  String get plainText => runs.map((r) => r.text).join();
}

class DocxTableBlock extends DocxBlock {
  const DocxTableBlock({required this.rows});

  final List<List<String>> rows;
}

class DocxImageBlock extends DocxBlock {
  const DocxImageBlock({
    required this.bytes,
    this.description,
  });

  final Uint8List bytes;
  final String? description;
}

class DocxDocumentModel {
  const DocxDocumentModel({
    required this.blocks,
    required this.wordCount,
    required this.paragraphCount,
    required this.tableCount,
    required this.imageCount,
  });

  final List<DocxBlock> blocks;
  final int wordCount;
  final int paragraphCount;
  final int tableCount;
  final int imageCount;

  bool get isEmpty => blocks.isEmpty;
}

/// Top-level entry point suitable for [compute] to decode an OOXML `.docx`
/// archive into structured paragraphs, tables, and embedded images.
DocxDocumentModel? parseDocxBytes(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entriesByPath = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = _normalizeZipPath(file.name).toLowerCase();
      entriesByPath[normalized] = file;
    }

    final docEntry = entriesByPath['word/document.xml'];
    if (docEntry == null) return null;

    final docBytes = docEntry.readBytes();
    if (docBytes == null || docBytes.isEmpty) return null;

    final imagesByRelId = _loadImagesByRelId(entriesByPath);
    final xmlDoc = XmlDocument.parse(utf8.decode(docBytes, allowMalformed: true));
    final body = _findFirstDescendantNamed(xmlDoc.rootElement, 'body');
    if (body == null) return null;

    final blocks = <DocxBlock>[];
    var paragraphCount = 0;
    var tableCount = 0;
    var imageCount = 0;
    var wordCount = 0;

    for (final child in body.childElements) {
      final local = child.name.local;
      if (local == 'p') {
        final parsed = _parseParagraph(child, imagesByRelId);
        for (final block in parsed) {
          blocks.add(block);
          if (block is DocxParagraphBlock) {
            paragraphCount++;
            wordCount += _countWords(block.plainText);
          } else if (block is DocxImageBlock) {
            imageCount++;
          }
        }
      } else if (local == 'tbl') {
        final table = _parseTable(child);
        if (table != null) {
          blocks.add(table);
          tableCount++;
          for (final row in table.rows) {
            for (final cell in row) {
              wordCount += _countWords(cell);
            }
          }
        }
      }
    }

    return DocxDocumentModel(
      blocks: blocks,
      wordCount: wordCount,
      paragraphCount: paragraphCount,
      tableCount: tableCount,
      imageCount: imageCount,
    );
  } on Object {
    return null;
  }
}

Map<String, Uint8List> _loadImagesByRelId(
  Map<String, ArchiveFile> entriesByPath,
) {
  final relEntry = entriesByPath['word/_rels/document.xml.rels'];
  if (relEntry == null) return const {};
  final relBytes = relEntry.readBytes();
  if (relBytes == null || relBytes.isEmpty) return const {};

  final result = <String, Uint8List>{};
  try {
    final relDoc = XmlDocument.parse(utf8.decode(relBytes, allowMalformed: true));
    for (final rel in relDoc.rootElement.childElements) {
      if (rel.name.local != 'Relationship') continue;
      final mode = _attrByLocalName(rel, 'TargetMode')?.toLowerCase();
      if (mode == 'external') continue;
      final id = _attrByLocalName(rel, 'Id');
      final target = _attrByLocalName(rel, 'Target');
      if (id == null || target == null || target.trim().isEmpty) continue;

      final resolvedPath = _resolveWordTargetPath(target).toLowerCase();
      if (!_isSupportedRasterImage(resolvedPath)) continue;
      final imgFile = entriesByPath[resolvedPath];
      final imgBytes = imgFile?.readBytes();
      if (imgBytes != null && imgBytes.isNotEmpty) {
        result[id] = imgBytes;
      }
    }
  } on Object {
    return result;
  }
  return result;
}

String _resolveWordTargetPath(String rawTarget) {
  var normalized = _normalizeZipPath(rawTarget);
  if (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  while (normalized.startsWith('../')) {
    normalized = normalized.substring(3);
  }
  if (normalized.toLowerCase().startsWith('word/')) {
    return normalized;
  }
  if (normalized.toLowerCase().startsWith('media/')) {
    return 'word/$normalized';
  }
  return 'word/$normalized';
}

String _normalizeZipPath(String raw) =>
    raw.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');

bool _isSupportedRasterImage(String lowerPath) =>
    lowerPath.endsWith('.png') ||
    lowerPath.endsWith('.jpg') ||
    lowerPath.endsWith('.jpeg') ||
    lowerPath.endsWith('.gif') ||
    lowerPath.endsWith('.webp');

List<DocxBlock> _parseParagraph(
  XmlElement pElement,
  Map<String, Uint8List> imagesByRelId,
) {
  var headingLevel = 0;
  var isListItem = false;
  var alignment = TextAlign.start;

  final pPr = _firstChildNamed(pElement, 'pPr');
  if (pPr != null) {
    final pStyle = _firstChildNamed(pPr, 'pStyle');
    final styleVal = _attrByLocalName(pStyle, 'val');
    headingLevel = _headingLevelForStyle(styleVal);

    if (_firstChildNamed(pPr, 'numPr') != null) {
      isListItem = true;
    }

    final jc = _firstChildNamed(pPr, 'jc');
    alignment = _textAlignForJc(_attrByLocalName(jc, 'val'));
  }

  final outBlocks = <DocxBlock>[];
  var runs = <DocxInlineRun>[];

  void flushRuns() {
    final coalesced = _coalesceRuns(runs);
    if (coalesced.any((r) => r.text.trim().isNotEmpty)) {
      outBlocks.add(
        DocxParagraphBlock(
          runs: coalesced,
          headingLevel: headingLevel,
          isListItem: isListItem,
          alignment: alignment,
        ),
      );
    }
    runs = <DocxInlineRun>[];
  }

  void walkRunContainer(XmlElement container) {
    for (final child in container.childElements) {
      final local = child.name.local;
      if (local == 'r') {
        _extractRun(
          runElement: child,
          targetRuns: runs,
          imagesByRelId: imagesByRelId,
          onImageFound: (imageBlock) {
            flushRuns();
            outBlocks.add(imageBlock);
          },
        );
      } else if (local == 'hyperlink' ||
          local == 'ins' ||
          local == 'smartTag' ||
          local == 'sdtContent') {
        walkRunContainer(child);
      }
    }
  }

  walkRunContainer(pElement);
  flushRuns();
  return outBlocks;
}

void _extractRun({
  required XmlElement runElement,
  required List<DocxInlineRun> targetRuns,
  required Map<String, Uint8List> imagesByRelId,
  required void Function(DocxImageBlock image) onImageFound,
}) {
  var bold = false;
  var italic = false;
  var underline = false;

  final rPr = _firstChildNamed(runElement, 'rPr');
  if (rPr != null) {
    bold = _isToggleEnabled(rPr, 'b');
    italic = _isToggleEnabled(rPr, 'i');
    underline = _isUnderlineEnabled(rPr);
  }

  final buffer = StringBuffer();
  for (final child in runElement.childElements) {
    final local = child.name.local;
    if (local == 't' || local == 'delText') {
      buffer.write(child.innerText);
    } else if (local == 'tab') {
      buffer.write('    ');
    } else if (local == 'br' || local == 'cr') {
      buffer.write('\n');
    } else if (local == 'drawing' || local == 'pict') {
      if (buffer.isNotEmpty) {
        targetRuns.add(
          DocxInlineRun(
            text: buffer.toString(),
            bold: bold,
            italic: italic,
            underline: underline,
          ),
        );
        buffer.clear();
      }
      final imageBlock = _extractImageBlock(child, imagesByRelId);
      if (imageBlock != null) {
        onImageFound(imageBlock);
      }
    }
  }

  if (buffer.isNotEmpty) {
    targetRuns.add(
      DocxInlineRun(
        text: buffer.toString(),
        bold: bold,
        italic: italic,
        underline: underline,
      ),
    );
  }
}

DocxImageBlock? _extractImageBlock(
  XmlElement container,
  Map<String, Uint8List> imagesByRelId,
) {
  if (imagesByRelId.isEmpty) return null;
  String? relId;
  String? description;

  final blip = _findFirstDescendantNamed(container, 'blip');
  if (blip != null) {
    relId = _attrByLocalName(blip, 'embed') ?? _attrByLocalName(blip, 'link');
  }
  if (relId == null) {
    final imageData = _findFirstDescendantNamed(container, 'imagedata');
    if (imageData != null) {
      relId = _attrByLocalName(imageData, 'id') ??
          _attrByLocalName(imageData, 'relid');
    }
  }
  if (relId == null) return null;

  final imageBytes = imagesByRelId[relId];
  if (imageBytes == null || imageBytes.isEmpty) return null;

  final docPr = _findFirstDescendantNamed(container, 'docPr');
  if (docPr != null) {
    final descr = _attrByLocalName(docPr, 'descr')?.trim();
    final name = _attrByLocalName(docPr, 'name')?.trim();
    description = (descr != null && descr.isNotEmpty) ? descr : name;
  }

  return DocxImageBlock(bytes: imageBytes, description: description);
}

DocxTableBlock? _parseTable(XmlElement tblElement) {
  final rawRows = <List<String>>[];
  var maxCols = 0;

  for (final tr in tblElement.childElements) {
    if (tr.name.local != 'tr') continue;
    final rowCells = <String>[];
    for (final tc in tr.childElements) {
      if (tc.name.local != 'tc') continue;
      final paragraphTexts = <String>[];
      for (final p in tc.childElements) {
        if (p.name.local != 'p') continue;
        final blocks = _parseParagraph(p, const {});
        final text = blocks
            .whereType<DocxParagraphBlock>()
            .map((b) => b.plainText.trim())
            .where((t) => t.isNotEmpty)
            .join('\n');
        if (text.isNotEmpty) {
          paragraphTexts.add(text);
        }
      }
      rowCells.add(paragraphTexts.join('\n'));
    }
    if (rowCells.isNotEmpty) {
      if (rowCells.length > maxCols) {
        maxCols = rowCells.length;
      }
      rawRows.add(rowCells);
    }
  }

  if (rawRows.isEmpty || maxCols == 0) return null;
  final normalized = rawRows.map((row) {
    if (row.length == maxCols) return row;
    return [
      ...row,
      for (var i = row.length; i < maxCols; i++) '',
    ];
  }).toList();

  return DocxTableBlock(rows: normalized);
}

List<DocxInlineRun> _coalesceRuns(List<DocxInlineRun> runs) {
  if (runs.isEmpty) return const [];
  final merged = <DocxInlineRun>[];
  for (final run in runs) {
    if (run.text.isEmpty) continue;
    if (merged.isNotEmpty && merged.last.hasSameStyle(run)) {
      final prev = merged.removeLast();
      merged.add(
        DocxInlineRun(
          text: '${prev.text}${run.text}',
          bold: prev.bold,
          italic: prev.italic,
          underline: prev.underline,
        ),
      );
    } else {
      merged.add(run);
    }
  }
  return merged;
}

int _headingLevelForStyle(String? styleVal) {
  if (styleVal == null) return 0;
  final lower = styleVal.trim().toLowerCase();
  if (lower == 'title' ||
      lower == 'heading1' ||
      lower == 'heading 1' ||
      lower == 'h1' ||
      lower == 'judul1') {
    return 1;
  }
  if (lower == 'subtitle' ||
      lower == 'heading2' ||
      lower == 'heading 2' ||
      lower == 'h2' ||
      lower == 'judul2') {
    return 2;
  }
  if (lower.startsWith('heading') || lower.startsWith('h')) {
    return 3;
  }
  return 0;
}

TextAlign _textAlignForJc(String? val) {
  return switch (val?.trim().toLowerCase()) {
    'center' => TextAlign.center,
    'right' || 'end' => TextAlign.right,
    'both' || 'justify' => TextAlign.justify,
    _ => TextAlign.start,
  };
}

bool _isToggleEnabled(XmlElement rPr, String localName) {
  final el = _firstChildNamed(rPr, localName);
  if (el == null) return false;
  final val = _attrByLocalName(el, 'val')?.trim().toLowerCase();
  return val != '0' && val != 'false' && val != 'off';
}

bool _isUnderlineEnabled(XmlElement rPr) {
  final u = _firstChildNamed(rPr, 'u');
  if (u == null) return false;
  final val = _attrByLocalName(u, 'val')?.trim().toLowerCase();
  return val != 'none' && val != '0' && val != 'false' && val != 'off';
}

XmlElement? _firstChildNamed(XmlElement parent, String localName) {
  for (final child in parent.childElements) {
    if (child.name.local == localName) return child;
  }
  return null;
}

XmlElement? _findFirstDescendantNamed(XmlElement root, String localName) {
  for (final child in root.childElements) {
    if (child.name.local == localName) return child;
    final match = _findFirstDescendantNamed(child, localName);
    if (match != null) return match;
  }
  return null;
}

String? _attrByLocalName(XmlElement? element, String localName) {
  if (element == null) return null;
  for (final attr in element.attributes) {
    if (attr.name.local == localName) return attr.value;
  }
  return null;
}

int _countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}
