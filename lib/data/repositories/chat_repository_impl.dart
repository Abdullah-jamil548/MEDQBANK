import '../../core/network/api_client.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<ChatThread>> listThreads() async {
    final res = await _api.get<List<dynamic>>('/chat/threads');
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<ChatMessage>> listMessages(
    String friendUserId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final res = await _api.get<List<dynamic>>(
      '/chat/$friendUserId/messages',
      queryParameters: {
        'limit': limit,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      },
    );
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<ChatMessage> sendText(String friendUserId, String body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/chat/$friendUserId/messages',
      data: {
        'message_type': 'text',
        'body': body,
      },
    );
    return ChatMessage.fromJson(res.data ?? {});
  }

  @override
  Future<ChatMessage> sendBookShare({
    required String friendUserId,
    required String bookId,
    required String bookTitle,
    required int pageNo,
    String? selectedText,
    String? caption,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/chat/$friendUserId/messages',
      data: {
        'message_type': 'book_share',
        'body': caption,
        'book_id': bookId,
        'book_title': bookTitle,
        'page_no': pageNo,
        'selected_text': selectedText,
      },
    );
    return ChatMessage.fromJson(res.data ?? {});
  }

  @override
  Future<void> markRead(String friendUserId) async {
    await _api.post('/chat/$friendUserId/read');
  }

  @override
  Future<bool> setMuted(String friendUserId, bool muted) async {
    if (muted) {
      final res = await _api.post<Map<String, dynamic>>('/chat/$friendUserId/mute');
      return res.data?['muted'] as bool? ?? true;
    }
    final res = await _api.delete<Map<String, dynamic>>('/chat/$friendUserId/mute');
    return res.data?['muted'] as bool? ?? false;
  }
}
