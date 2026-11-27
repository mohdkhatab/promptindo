import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/app_error_reporter.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorReporter.install();

  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Firebase is retained solely for FCM push notifications.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleWebClientId.isEmpty
          ? null
          : AppConfig.googleWebClientId,
    );
  } catch (_) {
    // Email/password auth must remain usable if Google native setup is absent.
  }

  // Background FCM handler must be a top-level function; a no-op is enough
  // because every notification is also persisted in `public.notifications`.
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  runApp(const ProviderScope(child: PromptIndoApp()));
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Notification rows live in Supabase; push delivery is handled by the backend.
}
