import '../../../core/utils/value_utils.dart';

/// `comments/{commentId}` entity (auto-id).
class Comment {
  const Comment({
    required this.id,
    required this.promptId,
    required this.parentId,
    required this.authorId,
    required this.authorUsername,
    required this.authorAvatar,
    required this.content,
    required this.likeCount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String promptId;
  final String? parentId;
  final String authorId;
  final String authorUsername;
  final String authorAvatar;
  final String content;
  final int likeCount;
  final String status;
  final DateTime? createdAt;

  bool get isReply => parentId != null && parentId!.isNotEmpty;
  bool get isActive => status == 'active';

  factory Comment.fromMap(Map<String, dynamic> map, {String? id}) {
    final parent = map['parent_id'];
    return Comment(
      id: asString(map['id'], id ?? ''),
      promptId: asString(map['prompt_id']),
      parentId: parent is String && parent.isNotEmpty ? parent : null,
      authorId: asString(map['author_id']),
      authorUsername: asString(map['author_username']),
      authorAvatar: asString(map['author_avatar']),
      content: asString(map['content']),
      likeCount: asInt(map['like_count']),
      status: asString(map['status'], 'active'),
      createdAt: asDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'prompt_id': promptId,
    'parent_id': parentId,
    'author_id': authorId,
    'author_username': authorUsername,
    'author_avatar': authorAvatar,
    'content': content,
    'like_count': likeCount,
    'status': status,
    'created_at': createdAt,
  };

  Comment copyWith({int? likeCount}) => Comment(
    id: id,
    promptId: promptId,
    parentId: parentId,
    authorId: authorId,
    authorUsername: authorUsername,
    authorAvatar: authorAvatar,
    content: content,
    likeCount: likeCount ?? this.likeCount,
    status: status,
    createdAt: createdAt,
  );
}
