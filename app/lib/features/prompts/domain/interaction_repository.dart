/// Likes / bookmarks / follows / copy / view — the composite-id side of the
/// model, plus the two callables.
///
/// Client writes are limited to *their own* like/bookmark/follow docs
/// (firestore.rules validates the `{uid}_…` id prefix) and to `set`/`delete`
/// only — every counter moves in the Cloud Function that fires on those docs.
abstract interface class InteractionRepository {
  /// The subset of [promptIds] the user has liked (prompt ids).
  Future<Set<String>> likedPromptIds(String uid, {int limit = 1000});

  /// The subset of [promptIds] the user has bookmarked.
  Future<Set<String>> bookmarkedPromptIds(String uid, {int limit = 1000});

  /// Saved feed: prompt ids in save order (newest first).
  Future<List<String>> savedPromptIds(String uid, {int limit = 100});

  /// Follower/following ids.
  Future<Set<String>> followingIds(String uid, {int limit = 1000});

  Future<bool> isFollowing({
    required String followerId,
    required String followedId,
  });

  Future<void> setLiked({
    required String uid,
    required String promptId,
    required bool liked,
  });

  Future<void> setBookmarked({
    required String uid,
    required String promptId,
    required bool bookmarked,
  });

  Future<void> setFollowing({
    required String followerId,
    required String followedId,
    required bool following,
  });

  /// Calls the `copyPrompt` callable (server-side copy_count increment).
  Future<void> recordCopy(String promptId);

  /// Calls the `recordView` callable (deduped server-side for 24h).
  Future<void> recordView(String promptId, {String? anonId});
}
