import '../domain/app_notification.dart';

/// Notification contract. The client can only read its own notifications,
/// flip `is_read`, and delete them — creation is Cloud-Function-only.
abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications({int limit = 50});

  Stream<int> watchUnreadCount();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  Future<void> deleteNotification(String notificationId);

  Future<void> clearAll();
}
