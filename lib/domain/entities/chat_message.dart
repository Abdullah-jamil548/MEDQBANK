enum MessageDeliveryStatus { pending, sent, delivered, seen }

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
    this.deliveredAt,
    this.readAt,
    this.status = MessageDeliveryStatus.sent,
    this.pending = false,
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
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final MessageDeliveryStatus status;
  final bool pending;

  bool get isBookShare => messageType == 'book_share';

  MessageDeliveryStatus get displayStatus {
    if (pending) return MessageDeliveryStatus.pending;
    if (readAt != null || status == MessageDeliveryStatus.seen) {
      return MessageDeliveryStatus.seen;
    }
    if (deliveredAt != null || status == MessageDeliveryStatus.delivered) {
      return MessageDeliveryStatus.delivered;
    }
    return MessageDeliveryStatus.sent;
  }

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

  ChatMessage copyWith({
    String? messageId,
    DateTime? deliveredAt,
    DateTime? readAt,
    MessageDeliveryStatus? status,
    bool? pending,
    bool clearDeliveredAt = false,
    bool clearReadAt = false,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId,
      recipientId: recipientId,
      messageType: messageType,
      mine: mine,
      body: body,
      bookId: bookId,
      bookTitle: bookTitle,
      pageNo: pageNo,
      selectedText: selectedText,
      createdAt: createdAt,
      deliveredAt: clearDeliveredAt ? null : (deliveredAt ?? this.deliveredAt),
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      status: status ?? this.status,
      pending: pending ?? this.pending,
    );
  }

  static MessageDeliveryStatus _parseStatus(
    String? raw, {
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    if (readAt != null || raw == 'seen') return MessageDeliveryStatus.seen;
    if (deliveredAt != null || raw == 'delivered') {
      return MessageDeliveryStatus.delivered;
    }
    if (raw == 'pending') return MessageDeliveryStatus.pending;
    return MessageDeliveryStatus.sent;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final deliveredAt = json['delivered_at'] != null
        ? DateTime.tryParse(json['delivered_at'] as String)
        : null;
    final readAt = json['read_at'] != null
        ? DateTime.tryParse(json['read_at'] as String)
        : null;
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
      deliveredAt: deliveredAt,
      readAt: readAt,
      status: _parseStatus(
        json['status'] as String?,
        deliveredAt: deliveredAt,
        readAt: readAt,
      ),
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
    this.muted = false,
  });

  final String friendUserId;
  final String fullName;
  final String email;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool muted;

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

  ChatThread copyWith({
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? muted,
  }) {
    return ChatThread(
      friendUserId: friendUserId,
      fullName: fullName,
      email: email,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
    );
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
      muted: json['muted'] as bool? ?? false,
    );
  }
}
