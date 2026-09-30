import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../domain/entities/chat_message.dart';
import '../../../../domain/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._repo);

  final ChatRepository _repo;

  List<ChatThread> threads = [];
  List<ChatMessage> messages = [];
  String? activeFriendId;
  String? activeFriendName;

  bool loadingThreads = false;
  bool loadingMessages = false;
  bool sending = false;
  String? error;

  Timer? _poll;

  void openThread({required String friendUserId, required String friendName}) {
    activeFriendId = friendUserId;
    activeFriendName = friendName;
    messages = [];
    error = null;
    notifyListeners();
    unawaited(loadMessages());
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (activeFriendId != null) unawaited(loadMessages(silent: true));
    });
  }

  void closeThread() {
    _poll?.cancel();
    _poll = null;
    activeFriendId = null;
    activeFriendName = null;
    messages = [];
  }

  Future<void> loadThreads({bool silent = false}) async {
    if (!silent) {
      loadingThreads = true;
      error = null;
      notifyListeners();
    }
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
    if (!silent) {
      loadingMessages = true;
      error = null;
      notifyListeners();
    }
    try {
      messages = await _repo.listMessages(friendId);
      await _repo.markRead(friendId);
      error = null;
    } catch (e) {
      if (!silent) error = apiErrorMessage(e);
    } finally {
      loadingMessages = false;
      notifyListeners();
    }
  }

  Future<bool> sendText(String body) async {
    final friendId = activeFriendId;
    final text = body.trim();
    if (friendId == null || text.isEmpty) return false;
    sending = true;
    error = null;
    notifyListeners();
    try {
      final msg = await _repo.sendText(friendId, text);
      messages = [...messages, msg];
      return true;
    } catch (e) {
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
        messages = [...messages, msg];
      }
      await loadThreads(silent: true);
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
