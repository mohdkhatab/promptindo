import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/follow_repository.dart';

class SupabaseFollowRepository implements FollowRepository {
  SupabaseFollowRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<String>> followerIds(String uid, {int limit = 200}) async {
    try {
      final rows = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('followed_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => asString(row['follower_id']))
          .where((id) => id.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<List<String>> followingIds(String uid, {int limit = 200}) async {
    try {
      final rows = await _supabase
          .from('follows')
          .select('followed_id')
          .eq('follower_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => asString(row['followed_id']))
          .where((id) => id.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Stream<int> watchFollowerCount(String uid) => _supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map(
        (rows) =>
            rows.isEmpty ? 0 : asInt(rows.first['follower_count']),
      );

  @override
  Stream<int> watchFollowingCount(String uid) => _supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map(
        (rows) =>
            rows.isEmpty ? 0 : asInt(rows.first['following_count']),
      );
}
