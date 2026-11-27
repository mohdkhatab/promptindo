import '../../../core/utils/value_utils.dart';

/// Public profile entity (`users/{uid}`). `email` is deliberately absent —
/// it lives in `users_private/{uid}` because Firestore rules cannot redact
/// fields on a single doc.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.usernameLower,
    required this.avatarUrl,
    required this.bio,
    required this.role,
    required this.status,
    required this.followerCount,
    required this.followingCount,
    required this.promptCount,
    required this.totalLikesReceived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String name;
  final String username;
  final String usernameLower;
  final String avatarUrl;
  final String bio;
  final String role;
  final String status;
  final int followerCount;
  final int followingCount;
  final int promptCount;
  final int totalLikesReceived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isAdmin => role == 'admin';
  bool get isBanned => status == 'banned';
  bool get isActive => status == 'active';

  factory AppUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppUser(
      uid: asString(map['uid'], id ?? ''),
      name: asString(map['name']),
      username: asString(map['username']),
      usernameLower: asString(
        map['username_lower'],
        asString(map['username']).toLowerCase(),
      ),
      avatarUrl: asString(map['avatar_url']),
      bio: asString(map['bio']),
      role: asString(map['role'], 'user'),
      status: asString(map['status'], 'active'),
      followerCount: asInt(map['follower_count']),
      followingCount: asInt(map['following_count']),
      promptCount: asInt(map['prompt_count']),
      totalLikesReceived: asInt(map['total_likes_received']),
      createdAt: asDateTime(map['created_at']),
      updatedAt: asDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'username': username,
    'username_lower': usernameLower,
    'avatar_url': avatarUrl,
    'bio': bio,
    'role': role,
    'status': status,
    'follower_count': followerCount,
    'following_count': followingCount,
    'prompt_count': promptCount,
    'total_likes_received': totalLikesReceived,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  AppUser copyWith({
    String? name,
    String? username,
    String? usernameLower,
    String? avatarUrl,
    String? bio,
    int? followerCount,
    int? followingCount,
    int? promptCount,
    int? totalLikesReceived,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      usernameLower: usernameLower ?? this.usernameLower,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role,
      status: status,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      promptCount: promptCount ?? this.promptCount,
      totalLikesReceived: totalLikesReceived ?? this.totalLikesReceived,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
