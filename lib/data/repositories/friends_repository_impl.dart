import '../../core/network/api_client.dart';
import '../../domain/entities/friend.dart';
import '../../domain/repositories/friends_repository.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  FriendsRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<Friend>> listFriends() async {
    final res = await _api.get<List<dynamic>>('/friends');
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => Friend.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<FriendRequest>> listRequests() async {
    final res = await _api.get<List<dynamic>>('/friends/requests');
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => FriendRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<UserSearchHit>> searchByEmail(String email) async {
    final res = await _api.get<List<dynamic>>(
      '/friends/search',
      queryParameters: {'email': email.trim()},
    );
    return (res.data ?? [])
        .whereType<Map>()
        .map((e) => UserSearchHit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<FriendRequest> sendRequest(String email) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/friends/request',
      data: {'email': email.trim().toLowerCase()},
    );
    return FriendRequest.fromJson(res.data ?? {});
  }

  @override
  Future<Friend> acceptRequest(String friendshipId) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/friends/$friendshipId/accept',
    );
    return Friend.fromJson(res.data ?? {});
  }

  @override
  Future<void> declineRequest(String friendshipId) async {
    await _api.post('/friends/$friendshipId/decline');
  }

  @override
  Future<void> removeFriend(String friendshipId) async {
    await _api.delete('/friends/$friendshipId');
  }

  @override
  Future<void> heartbeat() async {
    await _api.post('/presence/heartbeat');
  }

  @override
  Future<({bool hidePresence, bool hideReadingActivity})> updatePrivacy({
    bool? hidePresence,
    bool? hideReadingActivity,
  }) async {
    final body = <String, dynamic>{
      if (hidePresence != null) 'hide_presence': hidePresence,
      if (hideReadingActivity != null) 'hide_reading_activity': hideReadingActivity,
    };
    final res = await _api.patch<Map<String, dynamic>>('/me', data: body);
    final data = res.data ?? {};
    return (
      hidePresence: data['hide_presence'] as bool? ?? false,
      hideReadingActivity: data['hide_reading_activity'] as bool? ?? false,
    );
  }
}
