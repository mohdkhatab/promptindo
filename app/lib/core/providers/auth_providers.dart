import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'backend_providers.dart';

/// Raw auth state stream (uid or null).
final authStateProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// True when the signed-in user's email has been confirmed.
final emailVerifiedProvider = Provider<bool>(
  (ref) => ref.watch(authRepositoryProvider).isEmailVerified,
);

/// Email waiting for 6-digit signup OTP verification (when Confirm email is ON
/// and Supabase has not issued a session yet).
final pendingVerificationEmailProvider = StateProvider<String?>((ref) => null);

/// Signed-in uid, or null. Convenience over watching the whole AsyncValue.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value,
);
