import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/realtime_client.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../domain/entities/chat_message.dart';
import '../../../../domain/repositories/chat_repository.dart';
import '../../../session/presentation/providers/session_provider.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._repo, this._session, this._realtime) {
    _eventSub = _realtime.events.listen(_onRealtimeEvent);
    _realtime.addListener(_onRealtimeConnectionChanged);
  }

  final ChatRepository _repo;
  final SessionProvider _session;
  final RealtimeClient _realtime;

  List<ChatThread> threads = [];
  List<ChatMessage> messages = [];
  String? activeFriendId;
  String? activeFriendName;

  bool loadingThreads = false;
  bool loadingMessages = false;
  bool sending = false;
  String? error;

  StreamSubscription? _eventSub;
  Timer? _fallbackPoll;
  int _loadGeneration = 0;

  bool get socketConnected => _realtime.connected;

  bool get activeThreadMuted {
    final id = activeFriendId;
    if (id == null) return false;
    for (final t in threads) {
      if (t.friendUserId == id) return t.muted;
    }
    return false;
  }

  void _onRealtimeConnectionChanged() {
    notifyListeners();
    _syncFallbackPoll();
  }

  void _syncFallbackPoll() {
    final inThread = activeFriendId != null;
    final needPoll = inThread && !_realtime.connected;
    if (needPoll) {
      _fallbackPoll ??= Timer.periodic(const Duration(seconds: 3), (_) {
        if (activeFriendId != null && !_realtime.connected) {
          unawaited(loadMessages(silent: true));
        }
      });
    } else {
      _fallbackPoll?.cancel();
      _fallbackPoll = null;
    }
  }

  void openThread({required String friendUserId, required String friendName}) {
    activeFriendId = friendUserId;
    activeFriendName = friendName;
    messages = [];
    error = null;
    _realtime.start();
    notifyListeners();
    unawaited(loadMessages());
    _syncFallbackPoll();
  }

  void closeThread() {
    activeFriendId = null;
    activeFriendName = null;
    messages = [];
    _syncFallbackPoll();
  }

  Future<void> loadThreads({bool silent = false}) async {
    if (!silent) {
      loadingThreads = true;
      error = null;
      notifyListeners();
    }
    if (_session.profile.notificationsEnabled) {
      unawaited(NotificationService.instance.requestPermission());
    }
    _realtime.start();
    try {
      threads = await _repo.listThreads();
      error = null;
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loadingThreads = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages({bool silent = false}) async {
    final friendId = activeFriendId;
    if (friendId == null) return;
    final gen = ++_loadGeneration;
    if (!silent) {
      loadingMessages = true;
      error = null;
      notifyListeners();
    }
    try {
      final pending = messages.where((m) => m.pending).toList();
      final loaded = await _repo.listMessages(friendId);
      if (gen != _loadGeneration || activeFriendId != friendId) return;

      final stillPending = pending.where((p) {
        return !loaded.any(
          (m) => m.mine && m.body == p.body && m.messageType == p.messageType,
        );
      });
      messages = [...loaded, ...stillPending];
      await _repo.markRead(friendId);
      error = null;
    } catch (e) {
      if (!silent && gen == _loadGeneration) error = apiErrorMessage(e);
    } finally {
      if (gen == _loadGeneration) {
        loadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<bool> sendText(String body) async {
    final friendId = activeFriendId;
    final me = _session.userId;
    final text = body.trim();
    if (friendId == null || me == null || text.isEmpty) return false;

    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      messageId: tempId,
      senderId: me,
      recipientId: friendId,
      messageType: 'text',
      mine: true,
      body: text,
      createdAt: DateTime.now().toUtc(),
      pending: true,
    );
    messages = [...messages, optimistic];
    sending = true;
    error = null;
    notifyListeners();

    try {
      final msg = await _repo.sendText(friendId, text);
      if (activeFriendId != friendId) return true;
      messages = [
        for (final m in messages)
          if (m.messageId == tempId) msg else m,
      ];
      final seen = <String>{};
      messages = [
        for (final m in messages)
          if (seen.add(m.messageId)) m,
      ];
      _upsertThreadPreview(friendId, msg);
      return true;
    } catch (e) {
      if (activeFriendId == friendId) {
        messages = messages.where((m) => m.messageId != tempId).toList();
      }
      error = apiErrorMessage(e);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<bool> sendBookShare({
    required String friendUserId,
    required String bookId,
    required String bookTitle,
    required int pageNo,
    String? selectedText,
    String? caption,
  }) async {
    sending = true;
    error = null;
    notifyListeners();
    try {
      final msg = await _repo.sendBookShare(
        friendUserId: friendUserId,
        bookId: bookId,
        bookTitle: bookTitle,
        pageNo: pageNo,
        selectedText: selectedText,
        caption: caption,
      );
      if (activeFriendId == friendUserId) {
        if (!messages.any((m) => m.messageId == msg.messageId)) {
          messages = [...messages, msg];
        }
      }
      _upsertThreadPreview(friendUserId, msg);
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> toggleMute() async {
    final friendId = activeFriendId;
    if (friendId == null) return;
    final currentlyMuted = activeThreadMuted;
    try {
      final muted = await _repo.setMuted(friendId, !currentlyMuted);
      threads = [
        for (final t in threads)
          if (t.friendUserId == friendId) t.copyWith(muted: muted) else t,
      ];
      notifyListeners();
    } catch (e) {
      error = apiErrorMessage(e);
      notifyListeners();
    }
  }

  void _upsertThreadPreview(String friendId, ChatMessage msg) {
    threads = [
      for (final t in threads)
        if (t.friendUserId == friendId)
          t.copyWith(lastMessage: msg, unreadCount: 0)
        else
          t,
    ];
  }

  void _appendOrReplaceMessage(ChatMessage msg) {
    final idx = messages.indexWhere((m) => m.messageId == msg.messageId);
    if (idx >= 0) {
      messages = [
        for (var i = 0; i < messages.length; i++)
          if (i == idx) msg else messages[i],
      ];
      return;
    }
    final pendingIdx = messages.indexWhere(
      (m) => m.pending && m.mine && m.body == msg.body && msg.mine,
    );
    if (pendingIdx >= 0) {
      messages = [
        for (var i = 0; i < messages.length; i++)
          if (i == pendingIdx) msg else messages[i],
      ];
      return;
    }
    messages = [...messages, msg];
  }

  void _onRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'chat.message') {
      final raw = event['message'];
      if (raw is! Map) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(raw));
      final peerId = msg.mine ? msg.recipientId : msg.senderId;

      if (activeFriendId == peerId) {
        _appendOrReplaceMessage(msg);
        if (!msg.mine) {
          unawaited(_repo.markRead(peerId));
        }
        notifyListeners();
      } else if (!msg.mine) {
        var found = false;
        threads = threads.map((t) {
          if (t.friendUserId != peerId) return t;
          found = true;
          return t.copyWith(
            lastMessage: msg,
            unreadCount: t.unreadCount + 1,
          );
        }).toList();
        notifyListeners();
        if (!found) unawaited(loadThreads(silent: true));
      }

      final show = event['show_notification'] as bool? ?? false;
      final viewing = activeFriendId == peerId;
      if (show && !msg.mine && !viewing) {
        final name = event['from_full_name'] as String? ?? 'Friend';
        unawaited(
          NotificationService.instance.showChatMessage(
            title: name,
            body: msg.preview,
            payload: peerId,
          ),
        );
      }
    } else if (type == 'friend.request') {
      final show = event['show_notification'] as bool? ?? true;
      if (show) {
        final name = event['full_name'] as String? ?? 'Someone';
        unawaited(
          NotificationService.instance.showFriendRequest(
            title: 'Friend request',
            body: '$name wants to be friends',
          ),
        );
      }
    }
  }

  static String formatMessageTime(DateTime utcOrLocal) {
    final local = utcOrLocal.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    if (sameDay) return DateFormat.jm().format(local);
    if (now.difference(local).inDays < 7) {
      return '${DateFormat.E().format(local)} ${DateFormat.jm().format(local)}';
    }
    return DateFormat('MMM d, h:mm a').format(local);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _realtime.removeListener(_onRealtimeConnectionChanged);
    _fallbackPoll?.cancel();
    super.dispose();
  }
}
