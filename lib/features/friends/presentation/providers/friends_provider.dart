import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../domain/entities/friend.dart';
import '../../../../domain/repositories/friends_repository.dart';
import '../../../session/presentation/providers/session_provider.dart';

class FriendsProvider extends ChangeNotifier {
  FriendsProvider(this._repo, this._session);

  final FriendsRepository _repo;
  final SessionProvider _session;

  List<Friend> friends = [];
  List<FriendRequest> requests = [];
  List<UserSearchHit> searchHits = [];

  bool loading = false;
  bool searching = false;
  bool acting = false;
  String? error;
  String? searchError;
  String searchQuery = '';

  Timer? _heartbeat;
  Timer? _refresh;
  bool _presenceStarted = false;

  void startPresence() {
    if (_presenceStarted || !_session.isLoggedIn) return;
    _presenceStarted = true;
    unawaited(_safeHeartbeat());
    unawaited(refresh(silent: true));
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_safeHeartbeat());
    });
    _refresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_session.isLoggedIn) unawaited(refresh(silent: true));
    });
  }

  void stopPresence() {
    _heartbeat?.cancel();
    _refresh?.cancel();
    _heartbeat = null;
    _refresh = null;
    _presenceStarted = false;
  }

  Future<void> _safeHeartbeat() async {
    if (!_session.isLoggedIn) return;
    try {
      await _repo.heartbeat();
    } catch (_) {
      // Presence is best-effort; ignore transient errors.
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (!_session.isLoggedIn) return;
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _repo.listFriends(),
        _repo.listRequests(),
      ]);
      friends = results[0] as List<Friend>;
      requests = results[1] as List<FriendRequest>;
      error = null;
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    searchQuery = query.trim();
    if (searchQuery.length < 2) {
      searchHits = [];
      searchError = null;
      notifyListeners();
      return;
    }
    searching = true;
    searchError = null;
    notifyListeners();
    try {
      searchHits = await _repo.searchByEmail(searchQuery);
    } catch (e) {
      searchError = apiErrorMessage(e);
      searchHits = [];
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<bool> sendRequest(String email) async {
    acting = true;
    error = null;
    notifyListeners();
    try {
      await _repo.sendRequest(email);
      await refresh(silent: true);
      if (searchQuery.isNotEmpty) await search(searchQuery);
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      acting = false;
      notifyListeners();
    }
  }

  Future<bool> accept(String friendshipId) async {
    acting = true;
    error = null;
    notifyListeners();
    try {
      await _repo.acceptRequest(friendshipId);
      await refresh(silent: true);
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      acting = false;
      notifyListeners();
    }
  }

  Future<bool> decline(String friendshipId) async {
    acting = true;
    error = null;
    notifyListeners();
    try {
      await _repo.declineRequest(friendshipId);
      await refresh(silent: true);
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      acting = false;
      notifyListeners();
    }
  }

  Future<bool> remove(String friendshipId) async {
    acting = true;
    error = null;
    notifyListeners();
    try {
      await _repo.removeFriend(friendshipId);
      await refresh(silent: true);
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      acting = false;
      notifyListeners();
    }
  }

  Future<bool> setPrivacy({
    bool? hidePresence,
    bool? hideReadingActivity,
  }) async {
    acting = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repo.updatePrivacy(
        hidePresence: hidePresence,
        hideReadingActivity: hideReadingActivity,
      );
      _session.updateProfile(
        _session.profile.copyWith(
          hidePresence: result.hidePresence,
          hideReadingActivity: result.hideReadingActivity,
        ),
      );
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      acting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPresence();
    super.dispose();
  }
}
