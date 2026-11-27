import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';

/// Comment-like state for the signed-in user (composite ids again —
/// `comment_likes/{uid_commentId}`), hydrated once and toggled optimistically
/// exactly like prompt likes.
class CommentLikesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  Future<void> hydrate(String uid) async {
    if (state.isNotEmpty) return;
    try {
      state = await ref.read(commentRepositoryProvider).likedCommentIds(uid);
    } catch (_) {
      // Offline — buttons still work optimistically.
    }
  }

  Future<void> toggle(String uid, String commentId) async {
    final wasLiked = state.contains(commentId);
    state = wasLiked ? (state..remove(commentId)) : (state..add(commentId));
    try {
      await ref
          .read(commentRepositoryProvider)
          .setCommentLiked(uid: uid, commentId: commentId, liked: !wasLiked);
    } catch (_) {
      state = wasLiked ? (state..add(commentId)) : (state..remove(commentId));
      rethrow;
    }
  }
}

final commentLikesProvider =
    NotifierProvider<CommentLikesNotifier, Set<String>>(
      CommentLikesNotifier.new,
    );

/// Hydrates comment likes as soon as a signed-in user exists.
final commentLikesHydrationProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid != null) {
    // Fire and forget; the notifier guards against duplicate loads.
    Future.microtask(
      () => ref.read(commentLikesProvider.notifier).hydrate(uid),
    );
  }
});
