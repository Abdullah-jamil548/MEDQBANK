import '../entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatThread>> listThreads();

  Future<List<ChatMessage>> listMessages(String friendUserId, {DateTime? before, int limit = 50});

  Future<ChatMessage> sendText(String friendUserId, String body);

  Future<ChatMessage> sendBookShare({
    required String friendUserId,
    required String bookId,
    required String bookTitle,
    required int pageNo,
    String? selectedText,
    String? caption,
  });

  Future<void> markRead(String friendUserId);
}
