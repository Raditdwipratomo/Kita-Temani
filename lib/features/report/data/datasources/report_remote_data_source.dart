import 'dart:math';

import 'package:kitatemani/core/services/file_bytes_helper.dart';
import 'package:kitatemani/features/report/data/models/report_dto.dart';
import 'package:kitatemani/features/report/domain/entities/report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ReportRemoteDataSource {
  const ReportRemoteDataSource([this._client]);

  final SupabaseClient? _client;
  static const _uuid = Uuid();

  bool get isRemoteEnabled => _client != null;

  bool get hasAuthenticatedSession => _client?.auth.currentSession != null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<List<EvidenceAttachment>> uploadAttachments({
    required String reportKey,
    required List<EvidenceAttachment> items,
  }) async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null) return items;

    final uploaded = <EvidenceAttachment>[];
    for (final item in items) {
      final payload = item.bytes ?? await readFileBytes(item.localPath);
      if (payload == null || payload.isEmpty) {
        uploaded.add(item);
        continue;
      }
      try {
        final safeName = item.fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
        final storagePath = '$uid/$reportKey/${_uuid.v4()}_$safeName';
        await client.storage.from('evidence').uploadBinary(
              storagePath,
              payload,
              fileOptions: FileOptions(
                upsert: false,
                contentType: item.mimeType,
              ),
            );
        uploaded.add(
          EvidenceAttachment(
            fileName: item.fileName,
            kind: item.kind,
            localPath: item.localPath,
            storagePath: storagePath,
            bytes: item.bytes,
            sizeBytes: item.sizeBytes ?? payload.length,
            exifStripped: item.exifStripped,
          ),
        );
      } on Object {
        uploaded.add(item);
      }
    }
    return uploaded;
  }

  Future<String> submit(NewReportDto dto) async {
    final client = _client;
    if (client != null && client.auth.currentSession != null) {
      try {
        final data =
            await client.rpc('submit_report', params: dto.toRpcParams());
        if (data is Map && data['code'] != null) {
          return data['code'].toString();
        }
      } on Object {
        try {
          final legacyData = await client.rpc(
            'submit_report',
            params: dto.toLegacyRpcParams(),
          );
          if (legacyData is Map && legacyData['code'] != null) {
            return legacyData['code'].toString();
          }
        } on Object {
          // Fall through to local code generation when RPC is unavailable.
        }
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final rand = (1000 + Random().nextInt(9000)).toString();
    return 'KT-$mm$dd-$rand';
  }

  Future<List<AnonymousReportItem>> fetchMyReports(List<String> codes) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return const [];
    final data = await client.rpc(
      'get_my_reports',
      params: {'p_codes': codes},
    );
    if (data is List) {
      return data
          .whereType<Map<dynamic, dynamic>>()
          .map(
              (e) => AnonymousReportItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<List<AnonymousReportItem>> fetchSchoolReports() async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return const [];
    final data = await client.rpc('get_school_reports');
    if (data is List) {
      return data
          .whereType<Map<dynamic, dynamic>>()
          .map(
              (e) => AnonymousReportItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<ReportDetailData?> fetchReportDetail(String code) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return null;
    final data = await client.rpc(
      'get_report_detail',
      params: {'p_code': code},
    );
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final rawItem = AnonymousReportItem.fromJson(map);
    final hydratedEvidence = <EvidenceAttachment>[];
    for (final att in rawItem.resolvedEvidenceFiles) {
      final path = att.storagePath;
      if (path != null && path.contains('/')) {
        var next = att;
        if (att.isImage || att.isPdf || att.isDocx) {
          try {
            final downloaded =
                await client.storage.from('evidence').download(path);
            if (downloaded.isNotEmpty) {
              next = next.copyWith(
                bytes: downloaded,
                sizeBytes: next.sizeBytes ?? downloaded.length,
              );
            }
          } on Object {
            // Fall through to signed URL fallback below.
          }
        }
        if (next.bytes == null ||
            next.bytes!.isEmpty ||
            att.isPdf ||
            att.isDocx ||
            att.isVideo) {
          try {
            final signedUrl = await client.storage
                .from('evidence')
                .createSignedUrl(path, 3600);
            next = next.copyWith(previewUrl: signedUrl);
          } on Object {
            // Keep attachment metadata even if storage fetch fails.
          }
        }
        hydratedEvidence.add(next);
        continue;
      }
      hydratedEvidence.add(att);
    }
    final item = rawItem.copyWith(evidenceFiles: hydratedEvidence);
    final history = (map['history'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ReportTimelineEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final messages = (map['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ReportChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ReportDetailData(
      item: item,
      schoolName: (map['school_name'] ?? 'SMAN 1 Nusantara').toString(),
      history: history,
      messages: messages,
    );
  }

  Future<ReportChatMessage> sendMessage({
    required String code,
    required String content,
  }) async {
    final client = _client!;
    final data = await client.rpc(
      'send_report_message',
      params: {'p_code': code, 'p_content': content},
    );
    return ReportChatMessage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ReportStatus> advanceStatus({
    required String code,
    String? nextStatus,
    String? note,
  }) async {
    final client = _client!;
    final data = await client.rpc(
      'advance_report_status',
      params: {
        'p_code': code,
        'p_next_status': nextStatus,
        'p_note': note,
      },
    );
    if (data is Map && data['status'] != null) {
      return ReportStatus.fromWire(data['status'].toString());
    }
    return ReportStatus.ditinjau;
  }
}
