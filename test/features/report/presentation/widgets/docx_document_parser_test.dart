import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/features/report/presentation/widgets/docx_document_parser.dart';

final Uint8List _sample1x1Png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Uint8List _buildSampleDocxBytes() {
  const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/><w:jc w:val="center"/></w:pPr>
      <w:r><w:t>Kronologi Kejadian</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:rPr><w:b/></w:rPr><w:t>Tebal</w:t></w:r>
      <w:r><w:t xml:space="preserve"> dan </w:t></w:r>
      <w:r><w:rPr><w:i/><w:u w:val="single"/></w:rPr><w:t>miring</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>
      <w:r><w:t>Poin bukti pertama</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Tanggal</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Keterangan</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>24 Nov</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Terjadi di kantin</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:p>
      <w:r>
        <w:drawing>
          <wp:inline>
            <wp:docPr id="1" name="Lampiran 1" descr="Foto bukti"/>
            <a:graphic>
              <a:graphicData>
                <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:blipFill>
                    <a:blip r:embed="rIdImg1"/>
                  </pic:blipFill>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>
  </w:body>
</w:document>''';

  const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdImg1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>
</Relationships>''';

  final archive = Archive();
  final docBytes = utf8.encode(documentXml);
  final relsBytes = utf8.encode(relsXml);
  archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));
  archive.addFile(
    ArchiveFile('word/_rels/document.xml.rels', relsBytes.length, relsBytes),
  );
  archive.addFile(
    ArchiveFile('word/media/image1.png', _sample1x1Png.length, _sample1x1Png),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('parseDocxBytes', () {
    test('parses headings, inline styles, list items, tables, and embedded images',
        () {
      final docxBytes = _buildSampleDocxBytes();
      final doc = parseDocxBytes(docxBytes);
      expect(doc, isNotNull);
      expect(doc!.paragraphCount, 3);
      expect(doc.tableCount, 1);
      expect(doc.imageCount, 1);
      expect(doc.wordCount, greaterThan(10));

      final heading = doc.blocks[0] as DocxParagraphBlock;
      expect(heading.headingLevel, 1);
      expect(heading.alignment, TextAlign.center);
      expect(heading.plainText, 'Kronologi Kejadian');

      final styled = doc.blocks[1] as DocxParagraphBlock;
      expect(styled.runs.length, 3);
      expect(styled.runs[0].bold, isTrue);
      expect(styled.runs[0].text, 'Tebal');
      expect(styled.runs[2].italic, isTrue);
      expect(styled.runs[2].underline, isTrue);

      final bullet = doc.blocks[2] as DocxParagraphBlock;
      expect(bullet.isListItem, isTrue);
      expect(bullet.plainText, 'Poin bukti pertama');

      final table = doc.blocks[3] as DocxTableBlock;
      expect(table.rows, [
        ['Tanggal', 'Keterangan'],
        ['24 Nov', 'Terjadi di kantin'],
      ]);

      final image = doc.blocks[4] as DocxImageBlock;
      expect(image.bytes, _sample1x1Png);
      expect(image.description, 'Foto bukti');
    });

    test('returns null cleanly on empty or invalid bytes', () {
      expect(parseDocxBytes(Uint8List(0)), isNull);
      expect(parseDocxBytes(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}
