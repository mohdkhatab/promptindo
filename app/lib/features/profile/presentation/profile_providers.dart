import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/backend_providers.dart';
import '../../auth/domain/app_user.dart';

/// Another user's profile (`users/{uid}`) — used by the profile screen when
/// viewing someone else, and by the follow list sheet rows.
final otherProfileProvider = StreamProvider.family<AppUser?, String>(
  (ref, uid) => ref.watch(userRepositoryProvider).watchUser(uid),
);
