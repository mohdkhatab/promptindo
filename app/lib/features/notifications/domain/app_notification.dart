import '../../../core/utils/value_utils.dart';

/// `notifications/{id}` entity — created ONLY by Cloud Functions
/// (firestore.rules: `allow create: if false`), FCM push fans out from the
/// same function that writes the doc.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.actorUsername,
    required this.actorName,
    required this.actorAvatar,
    required this.type,
    required this.promptId,
    required this.commentId,
    required this.isRead,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String actorId;
  final String actorUsername;
  final String actorName;
  final String actorAvatar;
  final String type;
  final String? promptId;
  final String? commentId;
  final bool isRead;
  final Map<String, String> data;
  final DateTime? createdAt;

  bool get isUnread => !isRead;

  factory AppNotification.fromMap(Map<String, dynamic> map, {String? id}) {
    final promptId = map['prompt_id'];
    final commentId = map['comment_id'];
    return AppNotification(
      id: asString(map['id'], id ?? ''),
      recipientId: asString(map['recipient_id']),
      actorId: asString(map['actor_id']),
      actorUsername: asString(map['actor_username']),
      actorName: asString(map['actor_name']),
      actorAvatar: asString(map['actor_avatar']),
      type: asString(map['type'], 'system'),
      promptId: promptId is String && promptId.isNotEmpty ? promptId : null,
      commentId: commentId is String && commentId.isNotEmpty ? commentId : null,
      isRead: asBool(map['is_read']),
      data: asStringMap(map['data']),
      createdAt: asDateTime(map['created_at']),
    );
  }
}
