import 'dart:typed_data';

import '../domain/app_user.dart';

/// Profile contract: reads/writes `users/{uid}` (never the private doc) and
/// uploads avatars to Storage.
abstract interface class UserRepository {
  Stream<AppUser?> watchUser(String uid);

  Future<AppUser?> getUser(String uid);

  /// Creates the missing `users/{uid}` profile from the client (idempotent).
  Future<void> ensureProfile(String uid);

  Future<List<AppUser>> searchUsersByUsername(String query, {int limit = 10});

  Future<bool> isUsernameAvailable(String username);

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? username,
    String? bio,
    String? avatarUrl,
  });

  /// Uploads to `avatars/{uid}/{fileName}` (Storage rules enforce the owner),
  /// returning the download URL.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  });
}
