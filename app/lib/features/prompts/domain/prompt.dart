import '../../../core/utils/value_utils.dart';

/// Sort tabs on the home feed.
enum FeedSort { trending, latest, recommended }

/// Visibility values accepted by firestore.rules.
enum PromptVisibility {
  public('public'),
  unlisted('unlisted'),
  private('private');

  const PromptVisibility(this.value);
  final String value;

  static PromptVisibility fromValue(String raw) => PromptVisibility.values
      .firstWhere((v) => v.value == raw, orElse: () => PromptVisibility.public);
}

/// `prompts/{promptId}` entity.
///
/// Counters (`like_count`, `copy_count`, `view_count`, `comment_count`,
/// `bookmark_count`), `status`, `is_featured` and `trend_score` are written by
/// Cloud Functions only — firestore.rules rejects client edits to them, and
/// they start at their zero values on create.
class Prompt {
  const Prompt({
    required this.id,
    required this.title,
    required this.description,
    required this.promptContent,
    required this.categoryId,
    required this.tags,
    required this.aiModel,
    required this.visibility,
    required this.status,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorAvatar,
    required this.thumbnailUrl,
    required this.thumbnailPath,
    required this.likeCount,
    required this.copyCount,
    required this.viewCount,
    required this.commentCount,
    required this.bookmarkCount,
    required this.isFeatured,
    required this.trendScore,
    required this.remixedFromId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String promptContent;
  final String categoryId;
  final List<String> tags;
  final String aiModel;
  final PromptVisibility visibility;
  final String status;
  final String creatorId;
  final String creatorUsername;
  final String creatorAvatar;
  final String thumbnailUrl;
  final String thumbnailPath;
  final int likeCount;
  final int copyCount;
  final int viewCount;
  final int commentCount;
  final int bookmarkCount;
  final bool isFeatured;
  final int trendScore;
  final String remixedFromId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';
  bool get isVisibleToEveryone =>
      visibility == PromptVisibility.public && isActive;

  factory Prompt.fromMap(Map<String, dynamic> map, {String? id}) {
    return Prompt(
      id: asString(map['id'], id ?? ''),
      title: asString(map['title']),
      description: asString(map['description']),
      promptContent: asString(map['prompt_content']),
      categoryId: asString(map['category_id']),
      tags: asStringList(map['tags']),
      aiModel: asString(map['ai_model']),
      visibility: PromptVisibility.fromValue(
        asString(map['visibility'], 'public'),
      ),
      status: asString(map['status'], 'active'),
      creatorId: asString(map['creator_id']),
      creatorUsername: asString(map['creator_username']),
      creatorAvatar: asString(map['creator_avatar']),
      thumbnailUrl: asString(map['thumbnail_url']),
      thumbnailPath: asString(map['thumbnail_path']),
      likeCount: asInt(map['like_count']),
      copyCount: asInt(map['copy_count']),
      viewCount: asInt(map['view_count']),
      commentCount: asInt(map['comment_count']),
      bookmarkCount: asInt(map['bookmark_count']),
      isFeatured: asBool(map['is_featured']),
      trendScore: asInt(map['trend_score']),
      remixedFromId: asString(map['remixed_from_id']),
      createdAt: asDateTime(map['created_at']),
      updatedAt: asDateTime(map['updated_at']),
    );
  }

  /// The exact document shape a *client* is allowed to write (firestore.rules
  /// enforces these zero values on create).
  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'prompt_content': promptContent,
    'category_id': categoryId,
    'tags': tags,
    'ai_model': aiModel,
    'visibility': visibility.value,
    'status': status,
    'creator_id': creatorId,
    'creator_username': creatorUsername,
    'creator_avatar': creatorAvatar,
    'thumbnail_url': thumbnailUrl,
    'thumbnail_path': thumbnailPath,
    'like_count': likeCount,
    'copy_count': copyCount,
    'view_count': viewCount,
    'comment_count': commentCount,
    'bookmark_count': bookmarkCount,
    'is_featured': isFeatured,
    'trend_score': trendScore,
    'remixed_from_id': remixedFromId,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  Prompt copyWith({
    String? title,
    String? description,
    String? promptContent,
    String? categoryId,
    List<String>? tags,
    String? aiModel,
    PromptVisibility? visibility,
    String? thumbnailUrl,
    String? thumbnailPath,
    int? likeCount,
    int? copyCount,
    int? viewCount,
    int? commentCount,
    int? bookmarkCount,
    int? trendScore,
    DateTime? updatedAt,
  }) {
    return Prompt(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      promptContent: promptContent ?? this.promptContent,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      aiModel: aiModel ?? this.aiModel,
      visibility: visibility ?? this.visibility,
      status: status,
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      creatorAvatar: creatorAvatar,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      likeCount: likeCount ?? this.likeCount,
      copyCount: copyCount ?? this.copyCount,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      bookmarkCount: bookmarkCount ?? this.bookmarkCount,
      isFeatured: isFeatured,
      trendScore: trendScore ?? this.trendScore,
      remixedFromId: remixedFromId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Opaque keyset cursor for paged prompt feeds.
class PromptCursor {
  const PromptCursor({
    required this.id,
    required this.createdAt,
    required this.trendScore,
  });

  factory PromptCursor.fromPrompt(Prompt prompt) => PromptCursor(
    id: prompt.id,
    createdAt:
        (prompt.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
            .toUtc(),
    trendScore: prompt.trendScore,
  );

  final String id;
  final DateTime createdAt;
  final int trendScore;

  /// Always UTC ISO-8601 with trailing `Z` (never `+00:00`, which breaks URLs).
  String get utcIso => createdAt.toUtc().toIso8601String();
}

/// One page of a feed query — [nextCursor] is passed back to `fetchFeed`.
class PromptPage {
  const PromptPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Prompt> items;
  final bool hasMore;
  final Object? nextCursor;

  static const empty = PromptPage(items: [], hasMore: false);
}
