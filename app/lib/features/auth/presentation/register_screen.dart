import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/services/app_error_reporter.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/shake.dart';
import '../../../core/widgets/empty_state.dart';

/// Email/password registration. `users/{uid}` is provisioned by the
/// `onUserCreate` Cloud Function — the client only creates the Auth user.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  int _failedAttempts = 0;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _failedAttempts += 1;
      _busy = false;
    });
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    if (name.length < 2) {
      _fail('Tell us your name.');
      return;
    }
    if (!isValidEmail(_email.text)) {
      _fail('Enter a valid email address.');
      return;
    }
    final problem = passwordProblem(_password.text);
    if (problem != null) {
      _fail('Password: $problem.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.registerWithEmail(
        email: _email.text,
        password: _password.text,
        name: name,
      );
      if (repo.currentUid == null) {
        ref.read(pendingVerificationEmailProvider.notifier).state = _email.text
            .trim();
      }
      if (!mounted) return;
      // AuthGate is the single source of truth for verification/profile
      // transitions. Do not leave a pushed verification route above it.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, stack) {
      AppErrorReporter.report(e, stack);
      final mapped = SupabaseErrorMapper.map(e);
      if (mapped.code == 'email-already-in-use') {
        _fail('That email is already registered — try signing in.');
      } else if (mapped.code == 'weak-password') {
        _fail('Password is too weak.');
      } else if (mapped.code == 'network') {
        _fail('Network error — check your connection.');
      } else {
        _fail('Could not create the account. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassHeader(
                    title: 'Create account',
                    large: true,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  ShakeWidget(
                    trigger: _failedAttempts,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        children: [
                          GlassInput(
                            controller: _name,
                            label: 'DISPLAY NAME',
                            hint: 'Ada Pratama',
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                          ),
                          const SizedBox(height: AppSpace.md),
                          GlassInput(
                            controller: _email,
                            label: 'EMAIL',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: AppSpace.md),
                          GlassInput(
                            controller: _password,
                            label: 'PASSWORD',
                            hint: '8+ characters, letter + number',
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
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
                            label: 'Create account',
                            expand: true,
                            loading: _busy,
                            onPressed: _busy ? null : _register,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    'By continuing you agree to the Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: t.onBackgroundMuted(AppType.caption()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
