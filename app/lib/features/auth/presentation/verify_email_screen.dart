import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/services/app_error_reporter.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/shake.dart';

/// Email verification checkpoint: user enters the 6-digit OTP code sent to
/// their email, with resend + 30s cooldown and sign-out fallback.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  int _cooldown = 0;
  int _failedAttempts = 0;
  String? _error;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _code.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String? targetEmail) async {
    FocusScope.of(context).unfocus();
    final email = (targetEmail ?? '').trim();
    final code = _code.text.trim();

    if (email.isEmpty) {
      setState(() {
        _error = 'Missing email address. Try signing in again.';
        _failedAttempts++;
      });
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = 'Enter the 6-digit verification code.';
        _failedAttempts++;
      });
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(email: email, code: code);
      ref.read(pendingVerificationEmailProvider.notifier).state = null;
      ref.invalidate(authStateProvider);
    } catch (error, stack) {
      AppErrorReporter.report(error, stack);
      if (!mounted) return;
      final mapped = SupabaseErrorMapper.map(error);
      setState(() {
        _error = mapped.code == 'invalid-otp'
            ? mapped.message
            : 'Could not verify code. Please check and try again.';
        _failedAttempts++;
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend(String? targetEmail) async {
    if (_cooldown > 0 || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendVerificationEmail(email: targetEmail);
      if (mounted) {
        GlassToast.show(context, 'Verification code sent');
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
    } catch (error, stack) {
      AppErrorReporter.report(error, stack);
      if (mounted) {
        GlassToast.show(
          context,
          'Could not send email',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _useDifferentAccount() async {
    ref.read(pendingVerificationEmailProvider.notifier).state = null;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final repo = ref.watch(authRepositoryProvider);
    final pendingEmail = ref.watch(pendingVerificationEmailProvider);
    final email = pendingEmail ?? repo.currentEmail;
    final displayEmail = (email != null && email.isNotEmpty)
        ? email
        : 'your email';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShakeWidget(
                    trigger: _failedAttempts,
                    child: GlassContainer(
                      padding: const EdgeInsets.all(AppSpace.xl),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            size: 34,
                            color: t.textPrimary,
                          ),
                          const SizedBox(height: AppSpace.lg),
                          Text(
                            'Verify your email',
                            textAlign: TextAlign.center,
                            style: t.onGlass(AppType.title()),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            'Enter the 6-digit verification code we sent to '
                            '$displayEmail.',
                            textAlign: TextAlign.center,
                            style: t.onGlassMuted(AppType.body()),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          GlassInput(
                            controller: _code,
                            label: 'VERIFICATION CODE',
                            hint: '123456',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textInputAction: TextInputAction.done,
                            errorText: _error,
                            onSubmitted: (_) => _verify(email),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          GlassButton(
                            label: 'Verify email',
                            expand: true,
                            loading: _verifying,
                            onPressed: _verifying ? null : () => _verify(email),
                          ),
                          const SizedBox(height: AppSpace.md),
                          GlassButton(
                            label: _cooldown > 0
                                ? 'Resend in ${_cooldown}s'
                                : 'Resend code',
                            expand: true,
                            variant: GlassButtonVariant.secondary,
                            loading: _sending,
                            onPressed: _cooldown > 0
                                ? null
                                : () => _resend(email),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  GlassTextButton(
                    label: 'Use a different account',
                    color: t.onBackground,
                    onPressed: _useDifferentAccount,
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
