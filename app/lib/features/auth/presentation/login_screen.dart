import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/shake.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Email/password + Google sign-in.
///
/// Banned accounts are checked right after the credential resolves: the
/// session is torn down before any screen renders (§Auth).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  bool _googleBusy = false;
  int _failedAttempts = 0;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _failedAttempts += 1;
      _busy = false;
      _googleBusy = false;
    });
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      _fail('Enter a valid email address.');
      return;
    }
    if (_password.text.isEmpty) {
      _fail('Enter your password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signInWithEmail(email: email, password: _password.text);
      await _checkBanned();
    } catch (e) {
      final mapped = SupabaseErrorMapper.map(e);
      if (mapped.code == 'email-not-confirmed') {
        ref.read(pendingVerificationEmailProvider.notifier).state = email;
        return;
      }
      _fail(_messageFor(e));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signInWithGoogle();
      await _checkBanned();
    } catch (e) {
      _fail(_messageFor(e));
    }
  }

  Future<void> _checkBanned() async {
    final uid = ref.read(authRepositoryProvider).currentUid;
    if (uid == null) return;
    final user = await ref.read(userRepositoryProvider).getUser(uid);
    if (user != null && user.isBanned) {
      await ref.read(authRepositoryProvider).signOut();
      _fail('This account has been suspended.');
    }
  }

  String _messageFor(Object error) {
    final mapped = SupabaseErrorMapper.map(error);
    switch (mapped.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Email or password is incorrect.';
      case 'user-not-found':
        return 'No account with that email.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network':
        return 'Network error — check your connection.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  Future<void> _forgotPassword() async {
    await pushGlass<void>(
      context: context,
      builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
      name: '/forgot-password',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.xxl),
                  Text(
                    'PromptIndo',
                    textAlign: TextAlign.center,
                    style: t.onBackgroundStyle(AppType.display()),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Discover, save and share prompts that actually work.',
                    textAlign: TextAlign.center,
                    style: t.onBackgroundMuted(AppType.body()),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  ShakeWidget(
                    trigger: _failedAttempts,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        children: [
                          GlassInput(
                            controller: _email,
                            focusNode: _emailFocus,
                            label: 'EMAIL',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            onSubmitted: (_) => _passwordFocus.requestFocus(),
                          ),
                          const SizedBox(height: AppSpace.md),
                          GlassInput(
                            controller: _password,
                            focusNode: _passwordFocus,
                            label: 'PASSWORD',
                            hint: 'Your password',
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _signIn(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppSpace.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _error!,
                                style: AppType.caption(
                                  color: const Color(0xFFFF3B30),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          GlassButton(
                            label: 'Sign in',
                            expand: true,
                            loading: _busy,
                            onPressed: _busy ? null : _signIn,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          GlassTextButton(
                            label: 'Forgot password?',
                            onPressed: _busy ? null : _forgotPassword,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  GlassButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata_rounded,
                    variant: GlassButtonVariant.secondary,
                    expand: true,
                    loading: _googleBusy,
                    onPressed: _googleBusy ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: t.onBackgroundMuted(AppType.body()),
                      ),
                      GlassTextButton(
                        label: 'Create one',
                        color: t.onBackground,
                        onPressed: () => pushGlass<void>(
                          context: context,
                          builder: (_) => const RegisterScreen(),
                          name: '/register',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
