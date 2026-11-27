import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/backend_providers.dart';
import 'core/providers/theme_controller.dart';
import 'core/routing/glass_route.dart';
import 'core/services/deep_links.dart';
import 'core/services/fcm.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/glass_background.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'features/prompts/presentation/prompt_details_screen.dart';

/// Root widget: theming, global background, auth gate and deep-link wiring.
class PromptIndoApp extends ConsumerStatefulWidget {
  const PromptIndoApp({super.key});

  @override
  ConsumerState<PromptIndoApp> createState() => _PromptIndoAppState();
}

class _PromptIndoAppState extends ConsumerState<PromptIndoApp> {
  StreamSubscription<RemoteMessage>? _fcmOpenSub;

  @override
  void initState() {
    super.initState();
    // Universal links: `/p/{promptId}` resolves into prompt details, and
    // Supabase recovery links open the set-new-password screen.
    final links = ref.read(deepLinkServiceProvider);
    links.start((uri) {
      if (isPasswordRecoveryUri(uri)) {
        _openPasswordRecovery(uri);
        return;
      }
      final promptId = promptIdFromUri(uri);
      if (promptId == null) return;
      _openPrompt(promptId);
    });

    // Notification tap routing (background + terminated state).
    try {
      final fcm = ref.read(fcmServiceProvider);
      _fcmOpenSub = fcm.onMessageOpenedApp.listen(_handlePushMessage);
      fcm.getInitialMessage().then((message) {
        if (message != null) _handlePushMessage(message);
      }).catchError((_) {});
    } catch (_) {
      // Push unavailable (e.g. missing Play Services) — deep links still work.
    }
  }

  void _handlePushMessage(RemoteMessage message) {
    final promptId = message.data['prompt_id']?.toString() ?? '';
    if (promptId.isEmpty) return;
    _openPrompt(promptId);
  }

  void _openPrompt(String promptId) {
    _pushWhenReady('/prompt/$promptId');
  }

  Future<void> _openPasswordRecovery(Uri uri) async {
    try {
      final established = await ref
          .read(authRepositoryProvider)
          .completePasswordRecovery(uri);
      if (!mounted || !established) return;
      _pushWhenReady('/reset-password');
    } catch (_) {
      // Expired/invalid recovery links land back on the auth gate.
    }
  }

  /// A cold-start deep link can arrive before the navigator is mounted.
  void _pushWhenReady(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = ref.read(rootNavigatorKeyProvider).currentState;
      if (navigator != null) {
        navigator.pushNamed(route);
      } else {
        _pushWhenReady(route);
      }
    });
  }

  @override
  void dispose() {
    _fcmOpenSub?.cancel();
    ref.read(deepLinkServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'PromptIndo',
      debugShowCheckedModeBanner: false,
      navigatorKey: ref.read(rootNavigatorKeyProvider),
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      // §7: theme toggle cross-fades background + glass over 300ms.
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
      // The background paints behind every route (including sheets/dialogs).
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [const AppBackground(), ?child],
      ),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final promptMatch = RegExp(
          r'^/prompt/([A-Za-z0-9_-]+)$',
        ).firstMatch(name);
        if (promptMatch != null) {
          return GlassPageRoute<void>(
            builder: (_) =>
                PromptDetailsScreen(promptId: promptMatch.group(1)!),
          );
        }
        if (name == '/reset-password') {
          return GlassPageRoute<void>(
            builder: (_) => const ResetPasswordScreen(),
          );
        }
        return null;
      },
      home: const AuthGate(),
    );
  }
}
