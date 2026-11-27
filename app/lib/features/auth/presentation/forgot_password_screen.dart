import 'dart:async';

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

/// Two-step password reset:
/// 1) Enter account email -> sends 6-digit recovery OTP.
/// 2) Enter the 6-digit code + new password to update credentials.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _busy = false;
  int _failedAttempts = 0;
  String? _error;
  bool _sent = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_cooldown <= 1) {
          _cooldown = 0;
          timer.cancel();
        } else {
          _cooldown--;
        }
      });
    });
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!isValidEmail(_email.text)) {
      setState(() {
        _error = 'Enter a valid email address.';
        _failedAttempts++;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(email: _email.text);
      if (mounted) {
        setState(() => _sent = true);
        _startCooldown();
        GlassToast.show(context, 'Reset code sent');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not send the reset code.';
          _failedAttempts++;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetWithCode() async {
    FocusScope.of(context).unfocus();
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = 'Enter the 6-digit code from your email.';
        _failedAttempts++;
      });
      return;
    }
    final problem = passwordProblem(_newPassword.text);
    if (problem != null) {
      setState(() {
        _error = 'Password: $problem.';
        _failedAttempts++;
      });
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      setState(() {
        _error = 'New passwords do not match.';
        _failedAttempts++;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordWithCode(
            email: _email.text,
            code: code,
            newPassword: _newPassword.text,
          );
      if (mounted) {
        GlassToast.show(context, 'Password updated');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (error) {
      if (mounted) {
        final mapped = SupabaseErrorMapper.map(error);
        setState(() {
          _error = mapped.code == 'invalid-otp'
              ? mapped.message
              : 'Could not reset password. Check the code and try again.';
          _failedAttempts++;
        });
      }
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
                  GlassHeader(title: 'Reset password'),
                  const SizedBox(height: AppSpace.md),
                  if (_sent) ...[
                    Text(
                      'Enter the 6-digit code sent to ${_email.text.trim()} '
                      'and choose a new password.',
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
                              controller: _code,
                              label: 'RESET CODE',
                              hint: '123456',
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: AppSpace.md),
                            GlassInput(
                              controller: _newPassword,
                              label: 'NEW PASSWORD',
                              hint: '8+ characters, letter + number',
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: AppSpace.md),
                            GlassInput(
                              controller: _confirmPassword,
                              label: 'CONFIRM NEW PASSWORD',
                              hint: 'Repeat new password',
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _resetWithCode(),
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
                              label: 'Reset password',
                              expand: true,
                              loading: _busy,
                              onPressed: _busy ? null : _resetWithCode,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    GlassButton(
                      label: _cooldown > 0
                          ? 'Resend in ${_cooldown}s'
                          : 'Resend code',
                      expand: true,
                      variant: GlassButtonVariant.secondary,
                      onPressed: (_busy || _cooldown > 0) ? null : _send,
                    ),
                  ] else ...[
                    Text(
                      'Enter the email you registered with and we will send a '
                      '6-digit reset code.',
                      style: t.onBackgroundMuted(AppType.body()),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    ShakeWidget(
                      trigger: _failedAttempts,
                      child: GlassInput(
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    GlassButton(
                      label: 'Send reset code',
                      expand: true,
                      loading: _busy,
                      onPressed: _busy ? null : _send,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
