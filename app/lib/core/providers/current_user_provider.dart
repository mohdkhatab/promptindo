import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/app_user.dart';
import 'auth_providers.dart';
import 'backend_providers.dart';

/// Current user's `profiles` row (created atomically by the `handle_new_user`
/// Postgres trigger when the auth user is inserted).
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ref
      .watch(userRepositoryProvider)
      .getUser(uid)
      .timeout(const Duration(seconds: 8));
});

/// Watch variant used by profile/settings so trigger-maintained counters
/// (`follower_count`, `prompt_count`, …) update live.
final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// Convenience: signed-in uid + non-null profile together. Screens that need
/// "the user must be fully provisioned" watch this instead of two providers.
final readyUserProvider = Provider<(String, AppUser)?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final user = ref.watch(currentUserProvider).value;
  if (uid == null || user == null) return null;
  return (uid, user);
});
