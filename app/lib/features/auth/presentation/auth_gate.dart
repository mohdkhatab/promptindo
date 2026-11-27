import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/providers/current_user_provider.dart';
import '../../../core/services/app_error_reporter.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../shell/app_shell.dart';
import 'login_screen.dart';
import 'username_setup_screen.dart';
import 'verify_email_screen.dart';

/// Routing heart of the auth flow — computes where the user should be:
///
///   session restoring      → splash
///   pending email OTP      → verify-email screen
///   signed out             → login / register stack
///   email unverified       → verify-email screen
///   profile still missing  → provisioning wait (retry + sign-out escape)
///   username not chosen    → username setup
///   banned                 → immediate sign-out (§Auth: banned check)
///   otherwise              → app shell
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _signingOut = false;

  Future<void> _signOutBanned() async {
    if (_signingOut) return;
    _signingOut = true;
    await ref.read(authRepositoryProvider).signOut();
    _signingOut = false;
    if (mounted) {
      GlassToast.show(
        context,
        'This account has been suspended.',
        icon: Icons.block_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final pendingEmail = ref.watch(pendingVerificationEmailProvider);
    final profile = ref.watch(currentUserProvider);
    final repo = ref.watch(authRepositoryProvider);

    if (auth.isLoading) return const _GateSplash();

    final uid = auth.value;
    if (uid == null) {
      if (pendingEmail != null && pendingEmail.isNotEmpty) {
        return const VerifyEmailScreen();
      }
      return const LoginScreen();
    }

    // Post-login banned check: sign out at once, never render the shell.
    final user = profile.value;
    if (user != null && user.isBanned) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _signOutBanned());
      return const _GateSplash(message: 'Account suspended');
    }

    if (!repo.isEmailVerified) return const VerifyEmailScreen();

    if (profile.isLoading) {
      return const _GateSplash(message: 'Finishing setup…');
    }

    if (profile.hasError) {
      final error = profile.error!;
      final stack = profile.stackTrace;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppErrorReporter.report(error, stack),
      );
      return _GateSplash(
        message:
            'Could not load your profile.\n${AppErrorReporter.messageFor(error)}',
        showRetry: true,
        onRetry: () => ref.invalidate(currentUserProvider),
        showSignOut: true,
        onSignOut: () => ref.read(authRepositoryProvider).signOut(),
      );
    }

    if (user == null) {
      return _GateSplash(
        message: 'Finishing setup…',
        showRetry: true,
        onRetry: () => ref.invalidate(currentUserProvider),
        showSignOut: true,
        onSignOut: () => ref.read(authRepositoryProvider).signOut(),
      );
    }

    if (user.username.isEmpty) {
      return const UsernameSetupScreen(isNewUser: true);
    }

    return const AppShell();
  }
}

class _GateSplash extends StatelessWidget {
  const _GateSplash({
    this.message,
    this.showRetry = false,
    this.onRetry,
    this.showSignOut = false,
    this.onSignOut,
  });

  final String? message;
  final bool showRetry;
  final VoidCallback? onRetry;
  final bool showSignOut;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PromptIndo', style: t.onBackgroundStyle(AppType.display())),
            const SizedBox(height: AppSpace.xl),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: t.onBackground,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpace.lg),
              Text(message!, style: t.onBackgroundMuted(AppType.body())),
            ],
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: AppSpace.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry setup'),
              ),
            ],
            if (showSignOut && onSignOut != null) ...[
              const SizedBox(height: AppSpace.md),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ],
        ),
      ),
    );
  }
}
