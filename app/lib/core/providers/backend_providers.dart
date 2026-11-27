import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/supabase_account_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/data/supabase_user_repository.dart';
import '../../features/auth/domain/account_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/user_repository.dart';
import '../../features/categories/data/supabase_category_repository.dart';
import '../../features/categories/domain/category_repository.dart';
import '../../features/comments/data/supabase_comment_repository.dart';
import '../../features/comments/domain/comment_repository.dart';
import '../../features/notifications/data/supabase_notification_repository.dart';
import '../../features/notifications/domain/notification_repository.dart';
import '../../features/profile/data/supabase_follow_repository.dart';
import '../../features/profile/data/supabase_report_repository.dart';
import '../../features/profile/domain/follow_repository.dart';
import '../../features/profile/domain/report_repository.dart';
import '../../features/prompts/data/supabase_interaction_repository.dart';
import '../../features/prompts/data/supabase_prompt_repository.dart';
import '../../features/prompts/domain/interaction_repository.dart';
import '../../features/prompts/domain/prompt_repository.dart';
import '../services/category_service.dart';
import '../services/fcm.dart';
import '../services/media_service.dart';

/// ---------------------------------------------------------------------------
/// Backend singletons (pure infrastructure — no screens import these).
/// ---------------------------------------------------------------------------

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  // Initialization is awaited once in main() before the widget tree starts.
  return GoogleSignIn.instance;
});

/// ---------------------------------------------------------------------------
/// Repositories — screens depend on these contracts, never on Supabase types.
/// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(googleSignInProvider),
    onBeforeSignOut: () => ref.read(fcmServiceProvider).unregisterAndDeleteToken(),
  ),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => SupabaseUserRepository(ref.watch(supabaseClientProvider)),
);

final promptRepositoryProvider = Provider<PromptRepository>(
  (ref) => SupabasePromptRepository(ref.watch(supabaseClientProvider)),
);

/// Privileged image uploads go through the Next.js backend; the app never
/// receives the Appwrite server key.
final mediaServiceProvider = Provider<MediaService>(
  (ref) => MediaService(
    ref.watch(supabaseClientProvider),
    ref.watch(httpClientProvider),
  ),
);

/// Free-text category resolution; there is no in-app category catalogue.
final categoryServiceProvider = Provider<CategoryService>(
  (ref) => CategoryService(
    ref.watch(supabaseClientProvider),
    ref.watch(httpClientProvider),
  ),
);

final interactionRepositoryProvider = Provider<InteractionRepository>(
  (ref) => SupabaseInteractionRepository(ref.watch(supabaseClientProvider)),
);

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => SupabaseCommentRepository(ref.watch(supabaseClientProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => SupabaseCategoryRepository(ref.watch(supabaseClientProvider)),
);

/// The notification repo needs the *current* uid at call time (its streams are
/// rebuilt when auth state changes), so it takes a getter rather than a fixed
/// string.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => SupabaseNotificationRepository(
    ref.watch(supabaseClientProvider),
    () => ref.watch(supabaseClientProvider).auth.currentUser?.id ?? '',
  ),
);

final followRepositoryProvider = Provider<FollowRepository>(
  (ref) => SupabaseFollowRepository(ref.watch(supabaseClientProvider)),
);

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => SupabaseReportRepository(ref.watch(supabaseClientProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(httpClientProvider),
    onAccountDeleted: () async {
      try {
        await ref.read(fcmServiceProvider).deleteToken();
      } catch (_) {}
      try {
        await ref.read(googleSignInProvider).signOut();
      } catch (_) {}
    },
  ),
);
