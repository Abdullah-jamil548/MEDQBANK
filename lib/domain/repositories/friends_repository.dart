import '../entities/friend.dart';

abstract class FriendsRepository {
  Future<List<Friend>> listFriends();

  Future<List<FriendRequest>> listRequests();

  Future<List<UserSearchHit>> searchByEmail(String email);

  Future<FriendRequest> sendRequest(String email);

  Future<Friend> acceptRequest(String friendshipId);

  Future<void> declineRequest(String friendshipId);

  Future<void> removeFriend(String friendshipId);

  Future<void> heartbeat();

  Future<({bool hidePresence, bool hideReadingActivity})> updatePrivacy({
    bool? hidePresence,
    bool? hideReadingActivity,
  });
}
