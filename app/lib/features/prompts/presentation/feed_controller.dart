import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../domain/prompt.dart';

/// One page of feed content plus the pagination cursor. The cursor is the last
/// document of the previous page (typed as [Object] so the domain layer stays
/// free of Firestore imports) and is passed straight back into
/// `PromptRepository.fetchFeed`.
class FeedState {
  const FeedState({
    this.items = const [],
    this.cursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  static const empty = FeedState();

  final List<Prompt> items;
  final Object? cursor;
  final bool hasMore;
  final bool loadingMore;

  FeedState copyWith({
    List<Prompt>? items,
    Object? cursor,
    bool? hasMore,
    bool? loadingMore,
  }) => FeedState(
    items: items ?? this.items,
    cursor: cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Home feed — rebuilds whenever the sort tab changes (target-provider pattern
/// instead of a `family` notifier, per README "Riverpod").
class HomeFeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final sort = ref.watch(feedSortProvider);
    final page = await ref
        .read(promptRepositoryProvider)
        .fetchFeed(sort: sort, limit: 12);
    return FeedState(
      items: page.items,
      hasMore: page.hasMore,
      cursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(promptRepositoryProvider)
          .fetchFeed(
            sort: ref.read(feedSortProvider),
            limit: 12,
            cursor: current.cursor,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          loadingMore: false,
          cursor: page.nextCursor ?? current.cursor,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final homeFeedProvider = AsyncNotifierProvider<HomeFeedNotifier, FeedState>(
  HomeFeedNotifier.new,
);

/// Explore feed filtered by the selected category (null = newest overall).
class CategoryFeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final categoryId = ref.watch(exploreCategoryProvider);
    final page = await ref
        .read(promptRepositoryProvider)
        .fetchFeed(sort: FeedSort.latest, categoryId: categoryId, limit: 20);
    return FeedState(
      items: page.items,
      hasMore: page.hasMore,
      cursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(promptRepositoryProvider)
          .fetchFeed(
            sort: FeedSort.latest,
            categoryId: ref.read(exploreCategoryProvider),
            limit: 20,
            cursor: current.cursor,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          loadingMore: false,
          cursor: page.nextCursor ?? current.cursor,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final categoryFeedProvider =
    AsyncNotifierProvider<CategoryFeedNotifier, FeedState>(
      CategoryFeedNotifier.new,
    );

/// Tag + title-prefix search (README "Search" documents the simplification:
/// no external search service).
class SearchFeedNotifier extends AsyncNotifier<List<Prompt>> {
  @override
  Future<List<Prompt>> build() async {
    final query = ref.watch(searchQueryProvider);
    if (query.trim().isEmpty) return const [];
    return ref.read(promptRepositoryProvider).searchPrompts(query, limit: 30);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final searchFeedProvider =
    AsyncNotifierProvider<SearchFeedNotifier, List<Prompt>>(
      SearchFeedNotifier.new,
    );

/// A profile's prompt list (an own-profile query includes unlisted/private —
/// the `creator_id` filter is exactly what firestore.rules verifies).
class ProfileFeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final uid = ref.watch(profileTargetUidProvider);
    if (uid.isEmpty) return FeedState.empty;
    final page = await ref
        .read(promptRepositoryProvider)
        .fetchFeed(sort: FeedSort.latest, creatorId: uid, limit: 20);
    return FeedState(
      items: page.items,
      hasMore: page.hasMore,
      cursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref
          .read(promptRepositoryProvider)
          .fetchFeed(
            sort: FeedSort.latest,
            creatorId: ref.read(profileTargetUidProvider),
            limit: 20,
            cursor: current.cursor,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          hasMore: page.hasMore,
          loadingMore: false,
          cursor: page.nextCursor ?? current.cursor,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final profileFeedProvider =
    AsyncNotifierProvider<ProfileFeedNotifier, FeedState>(
      ProfileFeedNotifier.new,
    );

/// Saved (bookmarked) prompts: bookmark ids in save order, hydrated into full
/// prompt docs — anything the user can no longer read drops out silently.
class SavedFeedNotifier extends AsyncNotifier<List<Prompt>> {
  @override
  Future<List<Prompt>> build() async {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const [];

    final ids = await ref
        .read(interactionRepositoryProvider)
        .savedPromptIds(uid, limit: 60);
    final prompts = ref.read(promptRepositoryProvider);
    final docs = await Future.wait(
      ids.map((id) async {
        try {
          return await prompts.getPrompt(id);
        } catch (_) {
          return null;
        }
      }),
    );
    return docs.whereType<Prompt>().toList();
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final savedFeedProvider =
    AsyncNotifierProvider<SavedFeedNotifier, List<Prompt>>(
      SavedFeedNotifier.new,
    );
