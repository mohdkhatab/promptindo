import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/comment.dart';
import '../domain/comment_repository.dart';

/// Supabase implementation of [CommentRepository].
class SupabaseCommentRepository implements CommentRepository {
  SupabaseCommentRepository(this._supabase);

  final SupabaseClient _supabase;

  Comment _map(Map<String, dynamic> row) =>
      Comment.fromMap(row, id: asString(row['id']));

  @override
  Future<List<Comment>> fetchComments(
    String promptId, {
    int limit = 100,
  }) async {
    try {
      final rows = await _supabase
          .from('comments')
          .select()
          .eq('prompt_id', promptId)
          .eq('status', 'active')
          .order('created_at', ascending: true)
          .limit(limit);
      return rows.map(_map).toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Stream<List<Comment>> watchComments(String promptId) => _supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('prompt_id', promptId)
      .map((rows) {
        final active = rows
            .where((row) => asString(row['status'], 'active') == 'active')
            .map(_map)
            .toList()
          ..sort((a, b) {
            final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return at.compareTo(bt);
          });
        return active;
      });

  @override
  Future<String> addComment({
    required String promptId,
    required String authorId,
    required String authorUsername,
    required String authorAvatar,
    required String content,
    String? parentId,
  }) async {
    try {
      // Only grantable columns are sent; author_username/avatar are populated
      // by `comments_before_insert` trigger.
      final row = await _supabase
          .from('comments')
          .insert({
            'prompt_id': promptId,
            'parent_id': emptyToNull(parentId),
            'author_id': authorId,
            'content': content,
          })
          .select('id')
          .single();
      return asString(row['id']);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase.from('comments').delete().eq('id', commentId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<Set<String>> likedCommentIds(String uid, {int limit = 1000}) async {
    try {
      final rows = await _supabase
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', uid)
          .limit(limit);
      return rows
          .map((row) => asString(row['comment_id']))
          .where((id) => id.isNotEmpty)
          .toSet();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> setCommentLiked({
    required String uid,
    required String commentId,
    required bool liked,
  }) async {
    try {
      if (liked) {
        await _supabase.from('comment_likes').insert({
          'user_id': uid,
          'comment_id': commentId,
        });
      } else {
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('user_id', uid)
            .eq('comment_id', commentId);
      }
    } on PostgrestException catch (e) {
      if (liked && e.code == '23505') return;
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }
}
