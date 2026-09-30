class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.recipientId,
    required this.messageType,
    required this.mine,
    required this.createdAt,
    this.body,
    this.bookId,
    this.bookTitle,
    this.pageNo,
    this.selectedText,
    this.readAt,
  });

  final String messageId;
  final String senderId;
  final String recipientId;
  final String messageType; // text | book_share
  final bool mine;
  final String? body;
  final String? bookId;
  final String? bookTitle;
  final int? pageNo;
  final String? selectedText;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isBookShare => messageType == 'book_share';

  String get preview {
    if (isBookShare) {
      final title = bookTitle ?? 'Book';
      final page = pageNo == null ? '' : ' · p.$pageNo';
      final quote = (selectedText ?? '').trim();
      if (quote.isNotEmpty) {
        final short = quote.length > 60 ? '${quote.substring(0, 60)}…' : quote;
        return '$title$page · “$short”';
      }
      return '$title$page';
    }
    return body ?? '';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      mine: json['mine'] as bool? ?? false,
      body: json['body'] as String?,
      bookId: json['book_id'] as String?,
      bookTitle: json['book_title'] as String?,
      pageNo: json['page_no'] as int?,
      selectedText: json['selected_text'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }
}

class ChatThread {
  const ChatThread({
    required this.friendUserId,
    required this.fullName,
    required this.email,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String friendUserId;
  final String fullName;
  final String email;
  final ChatMessage? lastMessage;
  final int unreadCount;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'];
    return ChatThread(
      friendUserId: json['friend_user_id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      lastMessage: last is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(last))
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
