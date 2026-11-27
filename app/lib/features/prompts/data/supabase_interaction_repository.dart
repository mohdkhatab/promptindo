import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/interaction_repository.dart';

/// Supabase implementation of [InteractionRepository].
class SupabaseInteractionRepository implements InteractionRepository {
  SupabaseInteractionRepository(this._supabase);

  static const _anonIdPrefKey = 'promptindo_anon_viewer_id';
  final SupabaseClient _supabase;
  String? _cachedAnonId;

  @override
  Future<Set<String>> likedPromptIds(String uid, {int limit = 1000}) async {
    try {
      final rows = await _supabase
          .from('likes')
          .select('prompt_id')
          .eq('user_id', uid)
          .limit(limit);
      return rows
          .map((row) => asString(row['prompt_id']))
          .where((id) => id.isNotEmpty)
          .toSet();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<Set<String>> bookmarkedPromptIds(
    String uid, {
    int limit = 1000,
  }) async {
    try {
      final rows = await _supabase
          .from('bookmarks')
          .select('prompt_id')
          .eq('user_id', uid)
          .limit(limit);
      return rows
          .map((row) => asString(row['prompt_id']))
          .where((id) => id.isNotEmpty)
          .toSet();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<List<String>> savedPromptIds(String uid, {int limit = 100}) async {
    try {
      final rows = await _supabase
          .from('bookmarks')
          .select('prompt_id')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => asString(row['prompt_id']))
          .where((id) => id.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<Set<String>> followingIds(String uid, {int limit = 1000}) async {
    try {
      final rows = await _supabase
          .from('follows')
          .select('followed_id')
          .eq('follower_id', uid)
          .limit(limit);
      return rows
          .map((row) => asString(row['followed_id']))
          .where((id) => id.isNotEmpty)
          .toSet();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<bool> isFollowing({
    required String followerId,
    required String followedId,
  }) async {
    try {
      final row = await _supabase
          .from('follows')
          .select('followed_id')
          .eq('follower_id', followerId)
          .eq('followed_id', followedId)
          .maybeSingle();
      return row != null;
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> setLiked({
    required String uid,
    required String promptId,
    required bool liked,
  }) async {
    try {
      if (liked) {
        await _supabase.from('likes').insert({
          'user_id': uid,
          'prompt_id': promptId,
        });
      } else {
        await _supabase
            .from('likes')
            .delete()
            .eq('user_id', uid)
            .eq('prompt_id', promptId);
      }
    } on PostgrestException catch (e) {
      if (liked && e.code == '23505') return;
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> setBookmarked({
    required String uid,
    required String promptId,
    required bool bookmarked,
  }) async {
    try {
      if (bookmarked) {
        await _supabase.from('bookmarks').insert({
          'user_id': uid,
          'prompt_id': promptId,
        });
      } else {
        await _supabase
            .from('bookmarks')
            .delete()
            .eq('user_id', uid)
            .eq('prompt_id', promptId);
      }
    } on PostgrestException catch (e) {
      if (bookmarked && e.code == '23505') return;
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> setFollowing({
    required String followerId,
    required String followedId,
    required bool following,
  }) async {
    if (followerId == followedId) return;
    try {
      if (following) {
        await _supabase.from('follows').insert({
          'follower_id': followerId,
          'followed_id': followedId,
        });
      } else {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', followerId)
            .eq('followed_id', followedId);
      }
    } on PostgrestException catch (e) {
      if (following && e.code == '23505') return;
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> recordCopy(String promptId) async {
    await _rpcBestEffortWithRetry(
      () => _supabase.rpc('copy_prompt', params: {'p_prompt_id': promptId}),
    );
  }

  @override
  Future<void> recordView(String promptId, {String? anonId}) async {
    String? resolvedAnonId = emptyToNull(anonId);
    if (_supabase.auth.currentUser == null && resolvedAnonId == null) {
      resolvedAnonId = await _getOrCreateAnonId();
    }
    await _rpcBestEffortWithRetry(
      () => _supabase.rpc(
        'record_view',
        params: {'p_prompt_id': promptId, 'p_anon_id': resolvedAnonId},
      ),
    );
  }

  Future<String> _getOrCreateAnonId() async {
    if (_cachedAnonId != null) return _cachedAnonId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_anonIdPrefKey);
      if (existing != null && existing.length >= 8) {
        _cachedAnonId = existing;
        return existing;
      }
      final generated = const Uuid().v4();
      await prefs.setString(_anonIdPrefKey, generated);
      _cachedAnonId = generated;
      return generated;
    } catch (_) {
      final generated = const Uuid().v4();
      _cachedAnonId = generated;
      return generated;
    }
  }

  Future<void> _rpcBestEffortWithRetry(Future<dynamic> Function() call) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await call();
        return;
      } on PostgrestException catch (e) {
        // Non-transient validation/permission/not-found errors should not retry.
        if (e.code == 'P0002' || e.code == '42501' || e.code == '22023') {
          return;
        }
        if (attempt == 1) return;
      } catch (_) {
        if (attempt == 1) return;
      }
    }
  }
}
