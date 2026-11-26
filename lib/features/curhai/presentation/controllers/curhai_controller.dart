import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/core/services/connectivity_service.dart';
import 'package:kitatemani/core/services/local_preferences_service.dart';
import 'package:kitatemani/core/supabase/supabase_providers.dart';
import 'package:kitatemani/features/curhai/data/repositories/curhai_repository_impl.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_conversation.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';
import 'package:kitatemani/features/curhai/domain/repositories/curhai_repository.dart';
import 'package:kitatemani/features/curhai/domain/validators/curhai_topic_validator.dart';

final curhaiRepositoryProvider = Provider<CurhaiRepository>((ref) {
  return FullstackCurhaiRepository(
    client: ref.watch(supabaseClientProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

class CurhaiState {
  const CurhaiState({
    required this.conversations,
    this.activeConversationId,
    required this.isTyping,
    this.typingConversationId,
    this.errorMessage,
  });

  final List<ChatConversation> conversations;
  final String? activeConversationId;
  final bool isTyping;
  final String? typingConversationId;
  final String? errorMessage;

  ChatConversation? get activeConversation {
    final targetId = activeConversationId;
    if (targetId == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == targetId) return conversation;
    }
    return null;
  }

  List<ChatMessage> get messages =>
      activeConversation?.messages ?? const <ChatMessage>[];

  bool get isActiveTyping =>
      isTyping &&
      typingConversationId != null &&
      typingConversationId == activeConversationId;

  bool get hasCrisisAlert =>
      messages.any((m) => m.riskLevel == CrisisRiskLevel.crisis);

  List<ChatConversation> get sortedConversations {
    final sorted = List<ChatConversation>.from(conversations);
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return sorted;
  }

  CurhaiState copyWith({
    List<ChatConversation>? conversations,
    String? activeConversationId,
    bool clearActiveConversation = false,
    bool? isTyping,
    String? typingConversationId,
    bool clearTypingConversation = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CurhaiState(
      conversations: conversations ?? this.conversations,
      activeConversationId: clearActiveConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      isTyping: isTyping ?? this.isTyping,
      typingConversationId: clearTypingConversation
          ? null
          : (typingConversationId ?? this.typingConversationId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CurhaiController extends Notifier<CurhaiState> {
  static const String _legacyStorageKey = 'kt_curhai_local_history_json';
  static const String _conversationsStorageKey = 'kt_curhai_conversations_v2';
  static const String _activeConversationKey =
      'kt_curhai_active_conversation_id';

  int _idSequence = 0;

  String _nextId(String prefix, DateTime timestamp) {
    final seq = _idSequence++;
    return '$prefix-${timestamp.microsecondsSinceEpoch}-$seq';
  }

  @override
  CurhaiState build() {
    final prefs = ref.read(localPreferencesServiceProvider);
    final rawConversations = prefs.getJsonList(_conversationsStorageKey);

    if (rawConversations.isNotEmpty) {
      final conversations = rawConversations
          .map(ChatConversation.fromJson)
          .where((c) => c.id.isNotEmpty && c.messages.isNotEmpty)
          .toList();
      if (conversations.isNotEmpty) {
        final savedActiveId = prefs.getString(_activeConversationKey);
        final resolvedActiveId =
            savedActiveId != null && conversations.any((c) => c.id == savedActiveId)
                ? savedActiveId
                : null;
        return CurhaiState(
          conversations: conversations,
          activeConversationId: resolvedActiveId,
          isTyping: false,
        );
      }
    }

    // Migrate legacy single-thread history into a titled conversation.
    final rawLegacy = prefs.getJsonList(_legacyStorageKey);
    if (rawLegacy.isNotEmpty) {
      final restored = rawLegacy
          .where((e) => !(e['id'] ?? '').toString().startsWith('init-'))
          .map(ChatMessage.fromJson)
          .where((m) => m.content.trim().isNotEmpty)
          .toList();
      if (restored.isNotEmpty) {
        String title = 'Obrolan sebelumnya';
        for (final message in restored) {
          if (message.sender == ChatSender.user) {
            title = generateConversationTitle(message.content);
            break;
          }
        }
        final createdAt = restored.first.timestamp;
        final updatedAt = restored.last.timestamp;
        final migrated = ChatConversation(
          id: 'conv-migrated-${createdAt.microsecondsSinceEpoch}',
          title: title,
          messages: restored,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
        final migratedList = <ChatConversation>[migrated];
        unawaited(_persistConversations(migratedList));
        unawaited(_persistActiveConversationId(migrated.id));
        unawaited(prefs.remove(_legacyStorageKey));
        return CurhaiState(
          conversations: migratedList,
          activeConversationId: migrated.id,
          isTyping: false,
        );
      }
    }

    return const CurhaiState(
      conversations: <ChatConversation>[],
      isTyping: false,
    );
  }

  Future<void> _persistConversations(List<ChatConversation> list) async {
    final prefs = ref.read(localPreferencesServiceProvider);
    await prefs.setJsonList(
      _conversationsStorageKey,
      list.map((c) => c.toJson()).toList(),
    );
  }

  Future<void> _persistActiveConversationId(String? conversationId) async {
    final prefs = ref.read(localPreferencesServiceProvider);
    if (conversationId == null) {
      await prefs.remove(_activeConversationKey);
    } else {
      await prefs.setString(_activeConversationKey, conversationId);
    }
  }

  String extractDraftNarrative() {
    final userLines = state.messages
        .where((m) => m.sender == ChatSender.user && !m.isOutOfScope)
        .map((m) => m.content.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (userLines.isEmpty) return '';
    return 'Ringkasan cerita dari Curhai:\n${userLines.join('\n')}';
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> startNewChat() async {
    state = state.copyWith(
      clearActiveConversation: true,
      clearError: true,
    );
    await _persistActiveConversationId(null);
  }

  Future<void> clearChat() => startNewChat();

  Future<void> selectConversation(String conversationId) async {
    if (!state.conversations.any((c) => c.id == conversationId)) return;
    state = state.copyWith(
      activeConversationId: conversationId,
      clearError: true,
    );
    await _persistActiveConversationId(conversationId);
  }

  Future<void> renameConversation(String conversationId, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    final updated = state.conversations
        .map((c) => c.id == conversationId ? c.copyWith(title: trimmed) : c)
        .toList();
    state = state.copyWith(conversations: updated);
    await _persistConversations(updated);
  }

  Future<void> togglePinConversation(String conversationId) async {
    final updated = state.conversations
        .map(
          (c) => c.id == conversationId ? c.copyWith(isPinned: !c.isPinned) : c,
        )
        .toList();
    state = state.copyWith(conversations: updated);
    await _persistConversations(updated);
  }

  Future<void> deleteConversation(String conversationId) async {
    final remaining =
        state.conversations.where((c) => c.id != conversationId).toList();
    final bool wasActive = state.activeConversationId == conversationId;
    final bool wasTyping = state.typingConversationId == conversationId;

    state = state.copyWith(
      conversations: remaining,
      clearActiveConversation: wasActive,
      isTyping: wasTyping ? false : state.isTyping,
      clearTypingConversation: wasTyping,
      clearError: true,
    );
    await _persistConversations(remaining);
    if (wasActive) {
      await _persistActiveConversationId(null);
    }
  }

  Future<void> clearAllConversations() async {
    state = const CurhaiState(
      conversations: <ChatConversation>[],
      isTyping: false,
    );
    final prefs = ref.read(localPreferencesServiceProvider);
    await prefs.remove(_conversationsStorageKey);
    await prefs.remove(_activeConversationKey);
    await prefs.remove(_legacyStorageKey);
  }

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final userRisk = detectCrisisRiskLevel(trimmed);
    final validation = validateCurhaiTopic(trimmed);
    final userMsg = ChatMessage(
      id: _nextId('user', now),
      sender: ChatSender.user,
      content: trimmed,
      timestamp: now,
      riskLevel: userRisk,
      isOutOfScope: !validation.isAllowed,
    );

    final existing = state.activeConversation;
    final String targetId;
    final List<ChatMessage> targetHistory;
    final List<ChatConversation> updatedConversations;

    if (existing != null) {
      targetId = existing.id;
      targetHistory = <ChatMessage>[...existing.messages, userMsg];
      final updatedConv = existing.copyWith(
        messages: targetHistory,
        updatedAt: now,
      );
      updatedConversations = state.conversations
          .map((c) => c.id == targetId ? updatedConv : c)
          .toList();
    } else {
      targetId = _nextId('conv', now);
      targetHistory = <ChatMessage>[userMsg];
      final newConv = ChatConversation(
        id: targetId,
        title: generateConversationTitle(trimmed),
        messages: targetHistory,
        createdAt: now,
        updatedAt: now,
      );
      updatedConversations = <ChatConversation>[newConv, ...state.conversations];
    }

    if (!validation.isAllowed) {
      final replyAt = DateTime.now();
      final guardReply = ChatMessage(
        id: _nextId('curhai-guard', replyAt),
        sender: ChatSender.assistant,
        content: validation.refusalMessage!,
        timestamp: replyAt,
        riskLevel: CrisisRiskLevel.normal,
        showQuickActions: false,
        isOutOfScope: true,
      );
      final withGuardReply = updatedConversations
          .map(
            (c) => c.id == targetId
                ? c.copyWith(
                    messages: <ChatMessage>[...c.messages, guardReply],
                    updatedAt: replyAt,
                  )
                : c,
          )
          .toList();
      state = state.copyWith(
        conversations: withGuardReply,
        activeConversationId: targetId,
        isTyping: false,
        clearTypingConversation: true,
        clearError: true,
      );
      await _persistConversations(withGuardReply);
      await _persistActiveConversationId(targetId);
      return;
    }

    state = state.copyWith(
      conversations: updatedConversations,
      activeConversationId: targetId,
      isTyping: true,
      typingConversationId: targetId,
      clearError: true,
    );
    await _persistConversations(updatedConversations);
    await _persistActiveConversationId(targetId);

    final res = await ref
        .read(curhaiRepositoryProvider)
        .sendMessage(userText: trimmed, history: targetHistory);

    if (res case Ok(:final value)) {
      final replyAt = DateTime.now();
      final withReply = state.conversations
          .map(
            (c) {
              if (c.id != targetId) return c;
              final updatedMessages = value.isOutOfScope
                  ? c.messages
                      .map(
                        (m) => m.id == userMsg.id
                            ? m.copyWith(isOutOfScope: true)
                            : m,
                      )
                      .toList()
                  : c.messages;
              return c.copyWith(
                messages: <ChatMessage>[...updatedMessages, value],
                updatedAt: replyAt,
              );
            },
          )
          .toList();
      state = state.copyWith(
        conversations: withReply,
        isTyping: false,
        clearTypingConversation: true,
        clearError: true,
      );
      await _persistConversations(withReply);
    } else if (res case Err(:final failure)) {
      state = state.copyWith(
        isTyping: false,
        clearTypingConversation: true,
        errorMessage: failure.message,
      );
    }
  }
}

final curhaiControllerProvider =
    NotifierProvider<CurhaiController, CurhaiState>(
  CurhaiController.new,
);
