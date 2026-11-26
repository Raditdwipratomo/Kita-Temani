import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';

String generateConversationTitle(String firstUserText) {
  final collapsed = firstUserText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return 'Obrolan baru';

  final capitalized = collapsed[0].toUpperCase() + collapsed.substring(1);
  if (capitalized.length <= 80) return capitalized;

  final slice = capitalized.substring(0, 79);
  final lastSpace = slice.lastIndexOf(' ');
  final cut =
      lastSpace >= 40 ? slice.substring(0, lastSpace).trimRight() : slice.trimRight();
  return '$cut…';
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;

  bool get hasCrisisAlert =>
      messages.any((m) => m.riskLevel == CrisisRiskLevel.crisis);

  ChatConversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_pinned': isPinned,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final parsedMessages = rawMessages is List
        ? rawMessages
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => !(e['id'] ?? '').toString().startsWith('init-'))
            .map(ChatMessage.fromJson)
            .toList()
        : <ChatMessage>[];

    final now = DateTime.now();
    final created =
        DateTime.tryParse((json['created_at'] ?? '').toString()) ?? now;
    final updated =
        DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? created;
    final rawTitle = (json['title'] ?? '').toString().trim();

    return ChatConversation(
      id: (json['id'] ?? '').toString(),
      title: rawTitle.isNotEmpty ? rawTitle : 'Obrolan baru',
      messages: parsedMessages,
      createdAt: created,
      updatedAt: updated,
      isPinned: json['is_pinned'] == true,
    );
  }
}
