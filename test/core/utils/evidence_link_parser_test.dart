import 'package:flutter_test/flutter_test.dart';
import 'package:kitatemani/core/utils/evidence_link_parser.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';

void main() {
  group('parseEvidenceLink', () {
    test('parses YouTube watch, youtu.be, shorts, embed, and live links', () {
      const watchUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final watch = parseEvidenceLink(watchUrl);
      expect(watch, isNotNull);
      expect(watch!.kind, EvidenceLinkKind.youtube);
      expect(watch.isPlayable, isTrue);
      expect(watch.mediaId, 'dQw4w9WgXcQ');
      expect(
        watch.embedUrl,
        'https://www.youtube.com/embed/dQw4w9WgXcQ?rel=0&playsinline=1',
      );
      expect(
        watch.thumbnailUrl,
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );

      final short = parseEvidenceLink('https://youtu.be/dQw4w9WgXcQ?t=1m15s');
      expect(short?.kind, EvidenceLinkKind.youtube);
      expect(short?.embedUrl, contains('&start=75'));

      final shorts =
          parseEvidenceLink('https://youtube.com/shorts/abcDEF12345');
      expect(shorts?.kind, EvidenceLinkKind.youtube);
      expect(shorts?.mediaId, 'abcDEF12345');

      final mobile =
          parseEvidenceLink('https://m.youtube.com/watch?v=xyz_123-ABC');
      expect(mobile?.kind, EvidenceLinkKind.youtube);
      expect(mobile?.mediaId, 'xyz_123-ABC');

      final live =
          parseEvidenceLink('https://www.youtube.com/live/LiveId12345');
      expect(live?.kind, EvidenceLinkKind.youtube);
      expect(live?.mediaId, 'LiveId12345');

      final embed = parseEvidenceLink(
        'https://www.youtube-nocookie.com/embed/EmbedId1234',
      );
      expect(embed?.kind, EvidenceLinkKind.youtube);
      expect(embed?.mediaId, 'EmbedId1234');

      final schemeless = parseEvidenceLink('youtu.be/dQw4w9WgXcQ');
      expect(schemeless?.normalizedUrl, 'https://youtu.be/dQw4w9WgXcQ');
      expect(schemeless?.kind, EvidenceLinkKind.youtube);
    });

    test('parses Google Drive file links & distinguishes folders', () {
      const driveId = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms';

      final viewLink = parseEvidenceLink(
        'https://drive.google.com/file/d/$driveId/view?usp=sharing',
      );
      expect(viewLink?.kind, EvidenceLinkKind.googleDrive);
      expect(viewLink?.isPlayable, isTrue);
      expect(viewLink?.mediaId, driveId);
      expect(
        viewLink?.embedUrl,
        'https://drive.google.com/file/d/$driveId/preview',
      );

      final previewLink = parseEvidenceLink(
        'https://drive.google.com/file/u/0/d/$driveId/preview',
      );
      expect(previewLink?.kind, EvidenceLinkKind.googleDrive);
      expect(previewLink?.mediaId, driveId);

      final openLink =
          parseEvidenceLink('https://drive.google.com/open?id=$driveId');
      expect(openLink?.kind, EvidenceLinkKind.googleDrive);
      expect(
        openLink?.embedUrl,
        'https://drive.google.com/file/d/$driveId/preview',
      );

      final ucLink = parseEvidenceLink(
        'https://drive.google.com/uc?id=$driveId&export=download',
      );
      expect(ucLink?.kind, EvidenceLinkKind.googleDrive);
      expect(ucLink?.mediaId, driveId);

      final schemelessDrive =
          parseEvidenceLink('drive.google.com/file/d/$driveId/view');
      expect(schemelessDrive?.kind, EvidenceLinkKind.googleDrive);
      expect(schemelessDrive?.normalizedUrl, startsWith('https://'));

      final folderLink = parseEvidenceLink(
        'https://drive.google.com/drive/folders/$driveId?usp=sharing',
      );
      expect(folderLink?.kind, EvidenceLinkKind.googleDriveFolder);
      expect(folderLink?.isPlayable, isFalse);
      expect(folderLink?.embedUrl, isNull);
    });

    test('parses direct video URLs and generic links cleanly', () {
      final mp4 = parseEvidenceLink(
        'https://cdn.sekolah.id/bukti/rekaman.mp4?token=abc',
      );
      expect(mp4?.kind, EvidenceLinkKind.directVideo);
      expect(mp4?.isPlayable, isTrue);
      expect(mp4?.mimeType, 'video/mp4');

      final webm = parseEvidenceLink('https://cdn.sekolah.id/clip.webm');
      expect(webm?.kind, EvidenceLinkKind.directVideo);
      expect(webm?.mimeType, 'video/webm');

      const genericUrl = 'https://drive.example.com/bukti-01';
      final generic = parseEvidenceLink(genericUrl);
      expect(generic?.kind, EvidenceLinkKind.externalLink);
      expect(generic?.normalizedUrl, genericUrl);
      expect(generic?.isPlayable, isFalse);
      expect(generic?.hasInlinePreview, isFalse);

      final pdf = parseEvidenceLink(
        'https://cdn.sekolah.id/bukti/surat_keterangan.pdf?token=xyz',
      );
      expect(pdf?.kind, EvidenceLinkKind.directPdf);
      expect(pdf?.isPlayable, isFalse);
      expect(pdf?.hasInlinePreview, isTrue);
      expect(pdf?.badgeLabel, 'PDF');

      final docx = parseEvidenceLink(
        'https://cdn.sekolah.id/bukti/kronologi.docx',
      );
      expect(docx?.kind, EvidenceLinkKind.directDocx);
      expect(docx?.isPlayable, isFalse);
      expect(docx?.hasInlinePreview, isTrue);
      expect(docx?.badgeLabel, 'DOCX');
    });

    test('rejects empty or invalid URLs', () {
      expect(parseEvidenceLink(''), isNull);
      expect(parseEvidenceLink('   '), isNull);
      expect(parseEvidenceLink('bukan link'), isNull);
      expect(parseEvidenceLink('ftp://example.com/file.mp4'), isNull);
      expect(parseEvidenceLink('javascript:alert(1)'), isNull);
    });
  });

  group('EvidenceAttachment video classification', () {
    test('detects video extensions even without explicit video kind', () {
      const att = EvidenceAttachment(fileName: 'rekaman_kejadian.mp4');
      expect(att.isVideo, isTrue);
      expect(att.isImage, isFalse);
      expect(att.mimeType, 'video/mp4');
    });

    test('distinguishes webm and quicktime mov mime types', () {
      const mov = EvidenceAttachment(
        fileName: 'screen_recording.mov',
        kind: 'video',
      );
      expect(mov.isVideo, isTrue);
      expect(mov.mimeType, 'video/quicktime');

      const webm = EvidenceAttachment(
        fileName: 'clip.webm',
        kind: 'video',
      );
      expect(webm.mimeType, 'video/webm');
    });
  });
}
