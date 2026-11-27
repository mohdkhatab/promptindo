import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/shake.dart';

/// Final step of the email-link password-recovery flow.
///
/// The recovery deep link has already established a short-lived Supabase
/// session; this screen only asks for the new password and updates the user.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  int _failedAttempts = 0;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final problem = passwordProblem(_password.text);
    if (problem != null) {
      setState(() {
        _error = 'Password: $problem.';
        _failedAttempts++;
      });
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() {
        _error = 'Passwords do not match.';
        _failedAttempts++;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      GlassToast.show(context, 'Password updated');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      final mapped = SupabaseErrorMapper.map(error);
      setState(() {
        _error = mapped.code == 'same-password'
            ? 'Choose a password you have not used before.'
            : 'Reset link expired or invalid. Request a new link.';
        _failedAttempts++;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
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
                  GlassHeader(title: 'Set new password'),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'Choose a new password for your account. You are signed in '
                    'through the reset link, so no old password is needed.',
                    style: t.onBackgroundMuted(AppType.body()),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  ShakeWidget(
                    trigger: _failedAttempts,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        children: [
                          GlassInput(
                            controller: _password,
                            label: 'NEW PASSWORD',
                            hint: '8+ characters, letter + number',
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                          const SizedBox(height: AppSpace.md),
                          GlassInput(
                            controller: _confirm,
                            label: 'CONFIRM NEW PASSWORD',
                            hint: 'Repeat new password',
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
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
                            label: 'Save new password',
                            expand: true,
                            loading: _busy,
                            onPressed: _busy ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).popUntil(
                            (route) => route.isFirst,
                          ),
                    child: const Text('Back to sign in'),
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
