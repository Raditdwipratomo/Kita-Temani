import 'package:kitatemani/core/error/failure.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/curhai/domain/repositories/curhai_repository.dart';
import 'package:kitatemani/features/curhai/domain/validators/curhai_topic_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const List<String> _crisisKeywords = [
  'menyakiti diri',
  'bunuh diri',
  'ingin mati',
  'tidak kuat lagi',
  'putus asa',
  'mengakhiri hidup',
  'dipukuli sekarang',
  'tolong bahaya',
  'terancam sekarang',
];

const List<String> _elevatedKeywords = [
  'takut ke sekolah',
  'males masuk',
  'dikucilkan',
  'diancam',
  'ditampar',
  'diejek',
  'dirundung',
];

CrisisRiskLevel detectCrisisRiskLevel(String text) {
  final lower = text.toLowerCase();
  if (_crisisKeywords.any(lower.contains)) return CrisisRiskLevel.crisis;
  if (_elevatedKeywords.any(lower.contains)) return CrisisRiskLevel.elevated;
  return CrisisRiskLevel.normal;
}

/// Builds a clean LLM payload from [history] and the latest [userText].
///
/// Drops:
/// 1. Any message explicitly marked [ChatMessage.isOutOfScope].
/// 2. Any legacy user message whose immediate assistant reply was marked
///    [ChatMessage.isOutOfScope] (so older off-topic prompts never leak into
///    subsequent in-scope turns).
/// 3. Any dangling/unanswered consecutive user messages before the latest turn,
///    preserving only clean alternating `(user -> assistant)` pairs plus the
///    single latest `user` message.
List<Map<String, String>> buildSanitizedCurhaiPayloadMessages({
  required List<ChatMessage> history,
  required String userText,
}) {
  final trimmedLatest = userText.trim();
  final nonEmpty =
      history.where((m) => m.content.trim().isNotEmpty).toList(growable: false);

  final filtered = <ChatMessage>[];
  for (var i = 0; i < nonEmpty.length; i++) {
    final msg = nonEmpty[i];
    if (msg.isOutOfScope) continue;

    // Legacy safety: if this user turn was answered by an off-topic refusal,
    // exclude the user turn as well so it cannot contaminate future turns.
    if (msg.sender == ChatSender.user && i + 1 < nonEmpty.length) {
      final next = nonEmpty[i + 1];
      if (next.sender == ChatSender.assistant && next.isOutOfScope) {
        continue;
      }
    }
    filtered.add(msg);
  }

  final payload = <Map<String, String>>[];
  for (final msg in filtered) {
    final role = msg.sender == ChatSender.user ? 'user' : 'assistant';
    final content = msg.content.trim();
    if (role == 'assistant') {
      // Never start with an orphan assistant message or emit two assistants in a row.
      if (payload.isEmpty || payload.last['role'] != 'user') {
        continue;
      }
      payload.add({'role': 'assistant', 'content': content});
    } else {
      // Collapse consecutive unanswered user messages by keeping the latest one.
      if (payload.isNotEmpty && payload.last['role'] == 'user') {
        payload.removeLast();
      }
      payload.add({'role': 'user', 'content': content});
    }
  }

  if (trimmedLatest.isNotEmpty) {
    if (payload.isNotEmpty && payload.last['role'] == 'user') {
      payload[payload.length - 1] = {'role': 'user', 'content': trimmedLatest};
    } else {
      payload.add({'role': 'user', 'content': trimmedLatest});
    }
  }

  return payload;
}

class FullstackCurhaiRepository implements CurhaiRepository {
  FullstackCurhaiRepository({
    required SupabaseClient? client,
    required ConnectivityService connectivity,
  })  : _client = client,
        _connectivity = connectivity;

  final SupabaseClient? _client;
  final ConnectivityService _connectivity;

  String _extractFunctionError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['message'] is String) {
      final msg = (details['message'] as String).trim();
      final lower = msg.toLowerCase();
      if (msg.isNotEmpty &&
          !lower.contains('openrouter') &&
          !lower.contains('qwen')) {
        return msg;
      }
    }
    if (details is String) {
      final msg = details.trim();
      final lower = msg.toLowerCase();
      if (msg.isNotEmpty &&
          !lower.contains('openrouter') &&
          !lower.contains('qwen')) {
        return msg;
      }
    }
    return 'CurhAI sedang sibuk sebentar. Coba kirim pesanmu lagi ya.';
  }

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String userText,
    required List<ChatMessage> history,
  }) async {
    final validation = validateCurhaiTopic(userText);
    if (!validation.isAllowed) {
      return Ok(
        ChatMessage(
          id: 'curhai-guard-${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatSender.assistant,
          content: validation.refusalMessage!,
          timestamp: DateTime.now(),
          riskLevel: CrisisRiskLevel.normal,
          showQuickActions: false,
          isOutOfScope: true,
        ),
      );
    }

    final client = _client;
    if (client == null) {
      return const Err(
        ServerFailure(
          'Layanan CurhAI belum siap terhubung saat ini. Coba lagi beberapa saat lagi.',
        ),
      );
    }

    if (!await _connectivity.isConnected) {
      return const Err(
        NetworkFailure('Tidak ada koneksi internet untuk menghubungi CurhAI.'),
      );
    }

    try {
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }

      final payloadMessages = buildSanitizedCurhaiPayloadMessages(
        history: history,
        userText: userText,
      );

      final response = await client.functions.invoke(
        'curhai-chat',
        body: {'messages': payloadMessages},
      );
      final data = response.data;
      if (data is Map && data['reply'] is String) {
        final reply = (data['reply'] as String).trim();
        if (reply.isNotEmpty) {
          final isOutOfScope = data['off_topic'] == true;
          final riskRaw = (data['risk_level'] ?? 'normal').toString();
          final serverRisk = switch (riskRaw) {
            'crisis' => CrisisRiskLevel.crisis,
            'elevated' => CrisisRiskLevel.elevated,
            _ => CrisisRiskLevel.normal,
          };
          final localRisk = detectCrisisRiskLevel(userText);
          final resolvedRisk = isOutOfScope
              ? CrisisRiskLevel.normal
              : (localRisk == CrisisRiskLevel.crisis
                  ? CrisisRiskLevel.crisis
                  : serverRisk);

          return Ok(
            ChatMessage(
              id: 'curhai-${DateTime.now().millisecondsSinceEpoch}',
              sender: ChatSender.assistant,
              content: reply,
              timestamp: DateTime.now(),
              riskLevel: resolvedRisk,
              showQuickActions: !isOutOfScope,
              isOutOfScope: isOutOfScope,
            ),
          );
        }
      }
      return const Err(
        ServerFailure(
          'CurhAI belum bisa merangkai balasan saat ini. Coba kirim ulang pesanmu ya.',
        ),
      );
    } on FunctionException catch (e) {
      return Err(ServerFailure(_extractFunctionError(e)));
    } on AuthException {
      return const Err(
        ServerFailure(
          'Sesi amanmu perlu dimuat ulang. Coba tutup lalu buka aplikasi kembali.',
        ),
      );
    } on Object {
      return const Err(
        ServerFailure(
          'Koneksi ke CurhAI sedang terganggu. Pastikan internet aktif lalu coba lagi ya.',
        ),
      );
    }
  }
}
