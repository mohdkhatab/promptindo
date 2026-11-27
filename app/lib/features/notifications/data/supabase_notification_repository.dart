import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/utils/value_utils.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

/// Supabase implementation of [NotificationRepository].
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._supabase, this._currentUid);

  final SupabaseClient _supabase;
  final String Function() _currentUid;

  AppNotification _map(Map<String, dynamic> row) =>
      AppNotification.fromMap(row, id: asString(row['id']));

  @override
  Stream<List<AppNotification>> watchNotifications({int limit = 50}) {
    final uid = _currentUid();
    if (uid.isEmpty) return Stream.value(const []);
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map(_map).toList());
  }

  @override
  Stream<int> watchUnreadCount() {
    final uid = _currentUid();
    if (uid.isEmpty) return Stream.value(0);
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', uid)
        .map((rows) => rows.where((row) => !asBool(row['is_read'])).length);
  }

  @override
  Future<void> markRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> markAllRead() async {
    final uid = _currentUid();
    if (uid.isEmpty) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', uid)
          .eq('is_read', false);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }

  @override
  Future<void> clearAll() async {
    final uid = _currentUid();
    if (uid.isEmpty) return;
    try {
      await _supabase.from('notifications').delete().eq('recipient_id', uid);
    } on PostgrestException catch (e) {
      throw SupabaseErrorMapper.mapPostgrest(e);
    }
  }
}
