import '../domain/comment.dart';

/// Comment contract. Comment likes use their own composite-id collection
/// (`comment_likes/{uid_commentId}`) with identical rules to `likes`.
abstract interface class CommentRepository {
  /// Top-level + threaded comments for a prompt, oldest first
  /// (`prompt_id, status, created_at asc` index).
  Future<List<Comment>> fetchComments(String promptId, {int limit = 100});

  Stream<List<Comment>> watchComments(String promptId);

  Future<String> addComment({
    required String promptId,
    required String authorId,
    required String authorUsername,
    required String authorAvatar,
    required String content,
    String? parentId,
  });

  Future<void> deleteComment(String commentId);

  Future<Set<String>> likedCommentIds(String uid, {int limit = 1000});

  Future<void> setCommentLiked({
    required String uid,
    required String commentId,
    required bool liked,
  });
}
