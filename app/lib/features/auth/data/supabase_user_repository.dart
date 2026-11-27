import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/app_user.dart';
import '../domain/user_repository.dart';

/// Supabase implementation of [UserRepository] backed by `public.profiles` and
/// the `avatars` Storage bucket.
class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Stream<AppUser?> watchUser(String uid) => _supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map(
        (rows) => rows.isEmpty
            ? null
            : AppUser.fromMap(rows.first, id: asString(rows.first['id'], uid)),
      );

  @override
  Future<AppUser?> getUser(String uid) async {
    try {
      final row = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
      return row == null
          ? null
          : AppUser.fromMap(row, id: asString(row['id'], uid));
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  /// No-op: `public.handle_new_user()` provisions the profile inside the same
  /// transaction as `auth.users` INSERT.
  @override
  Future<void> ensureProfile(String uid) async {}

  @override
  Future<List<AppUser>> searchUsersByUsername(
    String query, {
    int limit = 10,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final escaped = escapeLikePattern(q);
    try {
      final rows = await _supabase
          .from('profiles')
          .select()
          .like('username_lower', '$escaped%')
          .limit(limit);
      return rows
          .map((row) => AppUser.fromMap(row, id: asString(row['id'])))
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id')
          .eq('username_lower', normalized)
          .limit(1);
      return rows.isEmpty;
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> updateProfile({
    required String uid,
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    // Only these four columns are grantable on public.profiles; username_lower
    // is generated and updated_at is maintained by trigger.
    final updates = <String, dynamic>{
      'name': ?name,
      'username': ?username,
      'bio': ?bio,
      'avatar_url': ?avatarUrl,
    };
    if (updates.isEmpty) return;
    try {
      await _supabase.from('profiles').update(updates).eq('id', uid);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppMappedException(
          code: 'username-taken',
          message: 'That username is already taken.',
        );
      }
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = '$uid/$fileName';
    try {
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
              cacheControl: '604800',
            ),
          );
      return _supabase.storage.from('avatars').getPublicUrl(path);
    } on StorageException catch (e) {
      throw SupabaseErrorMapper.mapStorage(e);
    }
  }
}
