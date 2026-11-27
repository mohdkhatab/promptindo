import 'dart:typed_data';

import '../domain/prompt.dart';

/// Everything that reads or writes `prompts` goes through this contract —
/// screens never touch the database/storage client directly.
abstract interface class PromptRepository {
  /// Paged feed. Every public feed query filters on `status == active` AND
  /// `visibility == public` (own-profile queries allow owner's unlisted/private).
  Future<PromptPage> fetchFeed({
    required FeedSort sort,
    String? categoryId,
    String? tag,
    String? creatorId,
    Object? cursor,
    int limit = 12,
  });

  Stream<Prompt?> watchPrompt(String promptId);

  Future<Prompt?> getPrompt(String promptId);

  /// Title-substring + tag search via Postgres RPC.
  Future<List<Prompt>> searchPrompts(String query, {int limit = 20});

  /// Featured prompt for the home carousel (`is_featured == true`).
  Future<Prompt?> fetchFeatured();

  /// Uploads a thumbnail to `thumbnails/{uid}/{fileName}` and returns `(url, path)`.
  Future<({String url, String path})> uploadThumbnail({
    required String uid,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  });

  /// Publishes a new prompt using only client-grantable columns.
  Future<String> createPrompt(Prompt prompt);

  Future<void> updatePrompt(Prompt prompt);

  /// Delete → DB cascade + webhook removes the Storage thumbnail.
  Future<void> deletePrompt(String promptId);
}
