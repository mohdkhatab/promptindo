import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../domain/app_notification.dart';

/// Live notifications for the signed-in user (always filtered by
/// `recipient_id` — firestore.rules enforces the same predicate).
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref
      .watch(notificationRepositoryProvider)
      .watchNotifications(limit: 50);
});

/// Unread badge count shown on the notifications entry point.
final unreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream<int>.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount();
});
