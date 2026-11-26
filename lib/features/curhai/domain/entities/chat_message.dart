enum ChatSender { user, assistant }

enum CrisisRiskLevel { normal, elevated, crisis }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.riskLevel = CrisisRiskLevel.normal,
    this.showQuickActions = false,
    this.isOutOfScope = false,
  });

  final String id;
  final ChatSender sender;
  final String content;
  final DateTime timestamp;
  final CrisisRiskLevel riskLevel;
  final bool showQuickActions;
  final bool isOutOfScope;

  ChatMessage copyWith({
    String? id,
    ChatSender? sender,
    String? content,
    DateTime? timestamp,
    CrisisRiskLevel? riskLevel,
    bool? showQuickActions,
    bool? isOutOfScope,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      riskLevel: riskLevel ?? this.riskLevel,
      showQuickActions: showQuickActions ?? this.showQuickActions,
      isOutOfScope: isOutOfScope ?? this.isOutOfScope,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender == ChatSender.user ? 'user' : 'assistant',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'risk_level': riskLevel.name,
        'show_quick_actions': showQuickActions,
        'is_out_of_scope': isOutOfScope,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      sender: json['sender'] == 'user'
          ? ChatSender.user
          : ChatSender.assistant,
      content: (json['content'] ?? '').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
      riskLevel: switch (json['risk_level']) {
        'crisis' => CrisisRiskLevel.crisis,
        'elevated' => CrisisRiskLevel.elevated,
        _ => CrisisRiskLevel.normal,
      },
      showQuickActions: json['show_quick_actions'] == true,
      isOutOfScope: json['is_out_of_scope'] == true,
    );
  }
}
