import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/prompt.dart';
import '../domain/prompt_repository.dart';

/// Supabase implementation of [PromptRepository] with keyset cursor pagination.
class SupabasePromptRepository implements PromptRepository {
  SupabasePromptRepository(
    this._supabase, {
    String? Function()? currentUid,
  }) : _currentUid = currentUid ?? (() => _supabase.auth.currentUser?.id);

  final SupabaseClient _supabase;
  final String? Function() _currentUid;

  /// List cards (`PromptCard`, `FeaturedCard`) never display or copy
  /// `prompt_content`, so omit up to 20 KB per row on list queries.
  static const String listColumns =
      'id, title, description, category_id, tags, ai_model, visibility, status, '
      'creator_id, creator_username, creator_avatar, thumbnail_url, thumbnail_path, '
      'like_count, copy_count, view_count, comment_count, bookmark_count, '
      'is_featured, trend_score, remixed_from_id, created_at, updated_at';

  /// Builds the PostgREST `.or(...)` keyset predicate for `created_at desc, id desc`.
  static String latestCursorFilter(PromptCursor cursor) {
    final c = cursor.utcIso;
    final id = cursor.id;
    return 'created_at.lt.$c,and(created_at.eq.$c,id.lt.$id)';
  }

  /// Builds the PostgREST `.or(...)` keyset predicate for
  /// `trend_score desc, created_at desc, id desc`.
  static String trendingCursorFilter(PromptCursor cursor) {
    final s = cursor.trendScore;
    final c = cursor.utcIso;
    final id = cursor.id;
    return 'trend_score.lt.$s,'
        'and(trend_score.eq.$s,created_at.lt.$c),'
        'and(trend_score.eq.$s,created_at.eq.$c,id.lt.$id)';
  }

  /// Client-grantable insert columns only (`category_id` & `remixed_from_id`
  /// convert empty strings to `null` for UUID compatibility).
  static Map<String, dynamic> toInsertMap(Prompt prompt) => {
    'creator_id': prompt.creatorId,
    'title': prompt.title,
    'description': prompt.description,
    'prompt_content': prompt.promptContent,
    'category_id': emptyToNull(prompt.categoryId),
    'tags': prompt.tags,
    'ai_model': prompt.aiModel,
    'visibility': prompt.visibility.value,
    'thumbnail_url': prompt.thumbnailUrl,
    'thumbnail_path': prompt.thumbnailPath,
    'remixed_from_id': emptyToNull(prompt.remixedFromId),
  };

  /// Client-grantable update columns only.
  static Map<String, dynamic> toUpdateMap(Prompt prompt) => {
    'title': prompt.title,
    'description': prompt.description,
    'prompt_content': prompt.promptContent,
    'category_id': emptyToNull(prompt.categoryId),
    'tags': prompt.tags,
    'ai_model': prompt.aiModel,
    'visibility': prompt.visibility.value,
    'thumbnail_url': prompt.thumbnailUrl,
    'thumbnail_path': prompt.thumbnailPath,
  };

  PromptCursor? _resolveCursor(Object? cursor) {
    if (cursor is PromptCursor) return cursor;
    if (cursor is Prompt) return PromptCursor.fromPrompt(cursor);
    return null;
  }

  @override
  Future<PromptPage> fetchFeed({
    required FeedSort sort,
    String? categoryId,
    String? tag,
    String? creatorId,
    Object? cursor,
    int limit = 12,
  }) async {
    final parsedCursor = _resolveCursor(cursor);
    final isProfileFeed =
        creatorId != null &&
        creatorId.isNotEmpty &&
        sort != FeedSort.recommended &&
        (categoryId == null || categoryId.isEmpty) &&
        (tag == null || tag.isEmpty);
    final isOwnProfileFeed = isProfileFeed && creatorId == _currentUid();

    try {
      var filter = _supabase.from('prompts').select(listColumns);

      if (!isOwnProfileFeed) {
        filter = filter.eq('status', 'active').eq('visibility', 'public');
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        filter = filter.eq('category_id', categoryId);
      } else if (tag != null && tag.isNotEmpty) {
        filter = filter.contains('tags', [tag.trim().toLowerCase()]);
      } else if (creatorId != null && creatorId.isNotEmpty) {
        filter = filter.eq('creator_id', creatorId);
      }

      final useTrending =
          sort == FeedSort.trending &&
          (categoryId == null || categoryId.isEmpty) &&
          (tag == null || tag.isEmpty) &&
          !isProfileFeed;

      if (parsedCursor != null) {
        filter = filter.or(
          useTrending
              ? trendingCursorFilter(parsedCursor)
              : latestCursorFilter(parsedCursor),
        );
      }

      final ordered = useTrending
          ? filter
                .order('trend_score', ascending: false)
                .order('created_at', ascending: false)
                .order('id', ascending: false)
          : filter
                .order('created_at', ascending: false)
                .order('id', ascending: false);

      final rows = await ordered.limit(limit);
      final items = rows
          .map((row) => Prompt.fromMap(row, id: asString(row['id'])))
          .toList();

      return PromptPage(
        items: items,
        hasMore: items.length == limit,
        nextCursor: items.isEmpty ? null : PromptCursor.fromPrompt(items.last),
      );
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Stream<Prompt?> watchPrompt(String promptId) => _supabase
      .from('prompts')
      .stream(primaryKey: ['id'])
      .eq('id', promptId)
      .map(
        (rows) => rows.isEmpty
            ? null
            : Prompt.fromMap(
                rows.first,
                id: asString(rows.first['id'], promptId),
              ),
      );

  @override
  Future<Prompt?> getPrompt(String promptId) async {
    try {
      final row = await _supabase
          .from('prompts')
          .select()
          .eq('id', promptId)
          .maybeSingle();
      return row == null
          ? null
          : Prompt.fromMap(row, id: asString(row['id'], promptId));
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<List<Prompt>> searchPrompts(String query, {int limit = 20}) async {
    final raw = query.trim();
    if (raw.isEmpty) return const [];
    try {
      final rows = await _supabase.rpc(
        'search_prompts',
        params: {'q': raw, 'lim': limit},
      );
      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map((row) => Prompt.fromMap(row, id: asString(row['id'])))
          .toList();
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<Prompt?> fetchFeatured() async {
    try {
      final rows = await _supabase
          .from('prompts')
          .select(listColumns)
          .eq('status', 'active')
          .eq('visibility', 'public')
          .eq('is_featured', true)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return Prompt.fromMap(rows.first, id: asString(rows.first['id']));
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<({String url, String path})> uploadThumbnail({
    required String uid,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final path = '$uid/$fileName';
    try {
      await _supabase.storage
          .from('thumbnails')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
              cacheControl: '604800',
            ),
          );
      final url = _supabase.storage.from('thumbnails').getPublicUrl(path);
      return (url: url, path: path);
    } on StorageException catch (e) {
      throw SupabaseErrorMapper.mapStorage(e);
    }
  }

  @override
  Future<String> createPrompt(Prompt prompt) async {
    try {
      final row = await _supabase
          .from('prompts')
          .insert(toInsertMap(prompt))
          .select('id')
          .single();
      return asString(row['id']);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> updatePrompt(Prompt prompt) async {
    try {
      await _supabase
          .from('prompts')
          .update(toUpdateMap(prompt))
          .eq('id', prompt.id);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> deletePrompt(String promptId) async {
    try {
      await _supabase.from('prompts').delete().eq('id', promptId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }
}
