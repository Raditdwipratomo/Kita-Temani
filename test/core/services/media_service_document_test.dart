import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/services/media_service.dart';

void main() {
  group('MediaService.validateEvidenceDocument', () {
    test('menerima file PDF dan DOCX hingga tepat 2 MB', () {
      const exactMax = MediaService.maxEvidenceDocumentBytes;

      final pdfOk = MediaService.validateEvidenceDocument(
        fileName: 'bukti_kronologi.pdf',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        sizeBytes: 4,
      );
      expect(pdfOk.isSuccess, isTrue);
      expect(pdfOk.evidence?.fileName, 'bukti_kronologi.pdf');
      expect(pdfOk.evidence?.kind, EvidenceKind.file);
      expect(pdfOk.evidence?.sizeBytes, 4);

      final docxAtLimit = MediaService.validateEvidenceDocument(
        fileName: 'SURAT_PERNYATAAN.DOCX',
        sizeBytes: exactMax,
      );
      expect(docxAtLimit.isSuccess, isTrue);
      expect(docxAtLimit.evidence?.fileName, 'SURAT_PERNYATAAN.DOCX');
      expect(docxAtLimit.evidence?.sizeBytes, exactMax);

      final pdfUpper = MediaService.validateEvidenceDocument(
        fileName: 'Laporan.PDF',
        sizeBytes: 1,
      );
      expect(pdfUpper.isSuccess, isTrue);
    });

    test('menolak format selain PDF atau DOCX (.doc, gambar, video, tanpa ekstensi)', () {
      const rejectedNames = [
        'dokumen_lama.doc',
        'foto_bukti.jpg',
        'tangkapan.jpeg',
        'gambar.png',
        'rekaman.mp4',
        'catatan.txt',
        'tanpa_ekstensi',
      ];

      for (final name in rejectedNames) {
        final res = MediaService.validateEvidenceDocument(
          fileName: name,
          sizeBytes: 1024,
        );
        expect(res.isSuccess, isFalse, reason: 'Seharusnya menolak $name');
        expect(res.error, DocumentPickError.unsupportedFormat);
      }
    });

    test('menolak PDF atau DOCX yang melebihi 2 MB', () {
      const overLimit = MediaService.maxEvidenceDocumentBytes + 1;

      final pdfTooBig = MediaService.validateEvidenceDocument(
        fileName: 'lampiran_besar.pdf',
        sizeBytes: overLimit,
      );
      expect(pdfTooBig.isSuccess, isFalse);
      expect(pdfTooBig.error, DocumentPickError.fileTooLarge);

      final docxTooBig = MediaService.validateEvidenceDocument(
        fileName: 'lampiran_besar.docx',
        sizeBytes: overLimit,
      );
      expect(docxTooBig.isSuccess, isFalse);
      expect(docxTooBig.error, DocumentPickError.fileTooLarge);
    });

    test('menolak file PDF atau DOCX berukuran 0 byte', () {
      final emptyRes = MediaService.validateEvidenceDocument(
        fileName: 'kosong.pdf',
        sizeBytes: 0,
      );
      expect(emptyRes.isSuccess, isFalse);
      expect(emptyRes.error, DocumentPickError.emptyFile);
    });
  });
}
