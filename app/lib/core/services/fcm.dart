import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/backend_providers.dart';

/// Firebase Cloud Messaging bootstrap (push delivery only).
///
/// Notification rows are persisted in Postgres (`public.notifications`) and
/// pushed by the Next.js webhook. The client requests permission, registers the
/// device token via the `register_fcm_token` RPC on login/refresh, and
/// unregisters it via `unregister_fcm_token` on sign-out.
class FcmService {
  FcmService(this._messaging, this._supabase);

  final FirebaseMessaging _messaging;
  final SupabaseClient _supabase;
  StreamSubscription<String>? _refreshSub;
  String? _lastToken;

  String get _platform =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
      ? 'ios'
      : 'android';

  /// Asks for notification permission, gets the FCM token, registers it in
  /// Supabase, and subscribes to token refreshes.
  Future<String?> requestPermissionAndGetToken() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(token);
    }

    _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((newToken) {
      if (newToken.isNotEmpty) {
        _registerToken(newToken).catchError((_) {});
      }
    });

    return token;
  }

  Future<void> _registerToken(String token) async {
    _lastToken = token;
    if (_supabase.auth.currentUser == null) return;
    await _supabase.rpc(
      'register_fcm_token',
      params: {'p_token': token, 'p_platform': _platform},
    );
  }

  /// Unregisters the token from Supabase (while still authenticated) and
  /// deletes the local FCM token.
  Future<void> unregisterAndDeleteToken() async {
    await _refreshSub?.cancel();
    _refreshSub = null;

    String? token = _lastToken;
    if (token == null || token.isEmpty) {
      try {
        token = await _messaging.getToken();
      } catch (_) {
        token = null;
      }
    }

    if (token != null &&
        token.isNotEmpty &&
        _supabase.auth.currentUser != null) {
      try {
        await _supabase.rpc(
          'unregister_fcm_token',
          params: {'p_token': token},
        );
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Best-effort cleanup.
    }
    _lastToken = null;
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> deleteToken() => _messaging.deleteToken();
}

final fcmServiceProvider = Provider<FcmService>(
  (ref) => FcmService(
    FirebaseMessaging.instance,
    ref.watch(supabaseClientProvider),
  ),
);
