class FriendReadingActivity {
  const FriendReadingActivity({
    required this.bookId,
    required this.bookTitle,
    required this.pageNo,
    this.progressPct,
    this.updatedAt,
  });

  final String bookId;
  final String bookTitle;
  final int pageNo;
  final double? progressPct;
  final DateTime? updatedAt;

  factory FriendReadingActivity.fromJson(Map<String, dynamic> json) {
    return FriendReadingActivity(
      bookId: json['book_id'] as String? ?? '',
      bookTitle: json['book_title'] as String? ?? '',
      pageNo: json['page_no'] as int? ?? 1,
      progressPct: (json['progress_pct'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class Friend {
  const Friend({
    required this.friendshipId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.status,
    this.isOnline,
    this.lastSeenAt,
    this.presenceHidden = false,
    this.readingHidden = false,
    this.lastReading,
  });

  final String friendshipId;
  final String userId;
  final String fullName;
  final String email;
  final String status;
  final bool? isOnline;
  final DateTime? lastSeenAt;
  final bool presenceHidden;
  final bool readingHidden;
  final FriendReadingActivity? lastReading;

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

  factory Friend.fromJson(Map<String, dynamic> json) {
    final reading = json['last_reading'];
    return Friend(
      friendshipId: json['friendship_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? 'accepted',
      isOnline: json['is_online'] as bool?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      presenceHidden: json['presence_hidden'] as bool? ?? false,
      readingHidden: json['reading_hidden'] as bool? ?? false,
      lastReading: reading is Map
          ? FriendReadingActivity.fromJson(Map<String, dynamic>.from(reading))
          : null,
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.friendshipId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.direction,
    this.createdAt,
  });

  final String friendshipId;
  final String userId;
  final String fullName;
  final String email;
  final String direction; // incoming | outgoing
  final DateTime? createdAt;

  bool get isIncoming => direction == 'incoming';

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      friendshipId: json['friendship_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      direction: json['direction'] as String? ?? 'incoming',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class UserSearchHit {
  const UserSearchHit({
    required this.userId,
    required this.fullName,
    required this.email,
    this.friendshipId,
    this.friendshipStatus,
    this.direction,
  });

  final String userId;
  final String fullName;
  final String email;
  final String? friendshipId;
  final String? friendshipStatus;
  final String? direction;

  factory UserSearchHit.fromJson(Map<String, dynamic> json) {
    return UserSearchHit(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      friendshipId: json['friendship_id'] as String?,
      friendshipStatus: json['friendship_status'] as String?,
      direction: json['direction'] as String?,
    );
  }
}
