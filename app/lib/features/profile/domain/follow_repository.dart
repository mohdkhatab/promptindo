/// Follower/following lists plus profile counters — the counters themselves
/// (`follower_count`, `following_count`) are Cloud-Function-only fields, so
/// this contract only ever *reads* them.
abstract interface class FollowRepository {
  Future<List<String>> followerIds(String uid, {int limit = 200});

  Future<List<String>> followingIds(String uid, {int limit = 200});

  Stream<int> watchFollowerCount(String uid);

  Stream<int> watchFollowingCount(String uid);
}
