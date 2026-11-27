import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider (Riverpod 3)

import '../../features/prompts/domain/prompt.dart';
import 'backend_providers.dart';

/// ---------------------------------------------------------------------------
/// Feed "target" providers (§Riverpod note in README): a single
/// `AsyncNotifier` watches these instead of using `family` notifiers.
/// ---------------------------------------------------------------------------

/// Active home-feed sort tab.
final feedSortProvider = StateProvider<FeedSort>((ref) => FeedSort.trending);

/// Explore: currently selected category id (null = all).
final exploreCategoryProvider = StateProvider<String?>((ref) => null);

/// Explore/search: current search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Prompt details: the prompt whose comments are loaded.
final activePromptIdProvider = StateProvider<String>((ref) => '');

/// Profile: which uid's profile list is open (followers/following sheet).
final profileTargetUidProvider = StateProvider<String>((ref) => '');

/// ---------------------------------------------------------------------------
/// Interaction state — likes / bookmarks / follows with optimistic updates.
/// ---------------------------------------------------------------------------

/// Which prompt ids the signed-in user has liked/bookmarked. Hydrated once per
/// session, then kept consistent by the optimistic toggles below (Firestore
/// itself is the source of truth; a failed write reverts).
class InteractionsState {
  const InteractionsState({
    this.liked = const {},
    this.bookmarked = const {},
    this.following = const {},
    this.hydrated = false,
  });

  final Set<String> liked;
  final Set<String> bookmarked;
  final Set<String> following;
  final bool hydrated;

  InteractionsState copyWith({
    Set<String>? liked,
    Set<String>? bookmarked,
    Set<String>? following,
    bool? hydrated,
  }) => InteractionsState(
    liked: liked ?? this.liked,
    bookmarked: bookmarked ?? this.bookmarked,
    following: following ?? this.following,
    hydrated: hydrated ?? this.hydrated,
  );
}

class InteractionsNotifier extends Notifier<InteractionsState> {
  @override
  InteractionsState build() => const InteractionsState();

  Future<void> hydrate(String uid) async {
    if (state.hydrated) return;
    final repo = ref.read(interactionRepositoryProvider);
    try {
      final liked = await repo.likedPromptIds(uid);
      final bookmarked = await repo.bookmarkedPromptIds(uid);
      final following = await repo.followingIds(uid);
      state = InteractionsState(
        liked: liked,
        bookmarked: bookmarked,
        following: following,
        hydrated: true,
      );
    } catch (_) {
      // Offline / rules error — leave the empty state, buttons still work
      // optimistically and the write path will surface real errors.
      state = state.copyWith(hydrated: true);
    }
  }

  /// Optimistic like toggle with revert-on-failure.
  Future<void> toggleLike(String uid, String promptId) async {
    final wasLiked = state.liked.contains(promptId);
    state = state.copyWith(
      liked: wasLiked
          ? (state.liked..remove(promptId))
          : (state.liked..add(promptId)),
    );
    try {
      await ref
          .read(interactionRepositoryProvider)
          .setLiked(uid: uid, promptId: promptId, liked: !wasLiked);
    } catch (_) {
      state = state.copyWith(
        liked: wasLiked
            ? (state.liked..add(promptId))
            : (state.liked..remove(promptId)),
      );
      rethrow;
    }
  }

  Future<void> toggleBookmark(String uid, String promptId) async {
    final wasSaved = state.bookmarked.contains(promptId);
    state = state.copyWith(
      bookmarked: wasSaved
          ? (state.bookmarked..remove(promptId))
          : (state.bookmarked..add(promptId)),
    );
    try {
      await ref
          .read(interactionRepositoryProvider)
          .setBookmarked(uid: uid, promptId: promptId, bookmarked: !wasSaved);
    } catch (_) {
      state = state.copyWith(
        bookmarked: wasSaved
            ? (state.bookmarked..add(promptId))
            : (state.bookmarked..remove(promptId)),
      );
      rethrow;
    }
  }

  Future<void> toggleFollow(String followerId, String followedId) async {
    final wasFollowing = state.following.contains(followedId);
    state = state.copyWith(
      following: wasFollowing
          ? (state.following..remove(followedId))
          : (state.following..add(followedId)),
    );
    try {
      await ref
          .read(interactionRepositoryProvider)
          .setFollowing(
            followerId: followerId,
            followedId: followedId,
            following: !wasFollowing,
          );
    } catch (_) {
      state = state.copyWith(
        following: wasFollowing
            ? (state.following..add(followedId))
            : (state.following..remove(followedId)),
      );
      rethrow;
    }
  }

  void reset() => state = const InteractionsState();
}

final interactionsProvider =
    NotifierProvider<InteractionsNotifier, InteractionsState>(
      InteractionsNotifier.new,
    );

/// Screen-level "is the create sheet open" flag (the Create tab pushes a
/// route instead of switching tabs).
final createSheetOpenProvider = StateProvider<bool>((ref) => false);

/// Local, per-session record of prompts whose `recordView` callable has already
/// fired (the callable also dedupes server-side for 24h — this just avoids
/// hammering the endpoint on rebuilds).
final viewedPromptIdsProvider = StateProvider<Set<String>>(
  (ref) => const <String>{},
);

/// Debug helper — log line only in profile mode.
void debugLog(String message) {
  assert(() {
    debugPrint('[PromptIndo] $message');
    return true;
  }());
}
