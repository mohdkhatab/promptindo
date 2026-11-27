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

/// Password reset step 1: send a Supabase recovery link.
///
/// Step 2 happens when the user taps the link: the app receives
/// `promptindo://reset-password` (or the https fallback), establishes the
/// recovery session, and shows [ResetPasswordScreen].
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

  bool _busy = false;
  int _failedAttempts = 0;
  String? _error;
  bool _sent = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _email.dispose();
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
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
      GlassToast.show(context, 'Reset link sent');
    } catch (error) {
      if (!mounted) return;
      final mapped = SupabaseErrorMapper.map(error);
      setState(() {
        _error = mapped.code == 'network'
            ? 'Network error — check your connection.'
            : 'Could not send the reset link. Try again.';
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
                  GlassHeader(title: 'Reset password'),
                  const SizedBox(height: AppSpace.md),
                  if (_sent) ...[
                    Text(
                      'We sent a reset link to ${_email.text.trim()}. '
                      'Open it on this device to choose a new password.',
                      style: t.onBackgroundMuted(AppType.body()),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    GlassContainer(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 42,
                            color: t.onBackground,
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            'The link opens PromptIndo and finishes the reset '
                            'inside the app. If it expired, send a new one.',
                            textAlign: TextAlign.center,
                            style: t.onBackgroundMuted(AppType.body()),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          GlassButton(
                            label: _cooldown > 0
                                ? 'Resend in ${_cooldown}s'
                                : 'Resend link',
                            expand: true,
                            variant: GlassButtonVariant.secondary,
                            onPressed: (_busy || _cooldown > 0) ? null : _send,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Enter the email you registered with and we will send a '
                      'password-reset link.',
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
                      label: 'Send reset link',
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
