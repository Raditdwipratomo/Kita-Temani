import 'package:kitatemani/core/error/result.dart';
import 'package:kitatemani/features/curhai/domain/entities/chat_message.dart';

abstract interface class CurhaiRepository {
  Future<Result<ChatMessage>> sendMessage({
    required String userText,
    required List<ChatMessage> history,
  });
}
