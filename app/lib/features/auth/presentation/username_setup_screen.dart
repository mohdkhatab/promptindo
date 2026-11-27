import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/backend_providers.dart';
import '../../../core/services/app_error_reporter.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/shake.dart';
import '../../../core/widgets/stagger.dart';

/// First-run profile completion: pick a username (checked against
/// `username_lower`, best-effort uniqueness — see README "Usernames") plus a
/// display name. Also reachable later when a Google account lands without one.
class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key, this.isNewUser = false});

  final bool isNewUser;

  @override
  ConsumerState<UsernameSetupScreen> createState() =>
      _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final _username = TextEditingController();
  final _name = TextEditingController();

  bool _checking = false;
  bool _saving = false;
  bool? _available;
  int _failedAttempts = 0;
  int _availabilityRequest = 0;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final uid = ref.read(authRepositoryProvider).currentUid;
    if (uid == null) return;
    final user = await ref.read(userRepositoryProvider).getUser(uid);
    if (user != null && mounted) {
      _name.text = user.name;
      if (user.username.isNotEmpty) _username.text = user.username;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability(String raw) async {
    final value = raw.trim();
    final request = ++_availabilityRequest;
    if (!isValidUsername(value)) {
      if (mounted) setState(() => _available = null);
      return;
    }
    if (mounted) setState(() => _checking = true);
    try {
      final free = await ref
          .read(userRepositoryProvider)
          .isUsernameAvailable(value)
          .timeout(const Duration(seconds: 8));
      if (!mounted || request != _availabilityRequest) return;
      setState(() {
        _available = free;
      });
    } catch (error, stack) {
      AppErrorReporter.report(error, stack);
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _available = null);
      GlassToast.show(
        context,
        'Could not check username. Retry.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final username = _username.text.trim();
    final name = _name.text.trim();

    if (!isValidUsername(username)) {
      setState(() => _failedAttempts++);
      return;
    }
    if (name.length < 2) {
      setState(() => _failedAttempts++);
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authRepositoryProvider).currentUid;
      if (uid == null) return;

      final free = await ref
          .read(userRepositoryProvider)
          .isUsernameAvailable(username)
          .timeout(const Duration(seconds: 8));
      if (!free) {
        if (mounted) {
          setState(() {
            _available = false;
            _failedAttempts++;
          });
        }
        return;
      }

      await ref
          .read(userRepositoryProvider)
          .updateProfile(uid: uid, name: name, username: username);
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      GlassToast.show(context, 'Profile ready');
    } catch (error, stack) {
      AppErrorReporter.report(error, stack);
      if (mounted) {
        setState(() {
          _failedAttempts++;
        });
        GlassToast.show(
          context,
          'Could not save username',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? get _usernameError {
    final value = _username.text.trim();
    if (value.isEmpty) return null;
    if (!isValidUsername(value)) {
      return '3–24 chars: letters, numbers, underscores';
    }
    if (_available == false) return 'That username is taken.';
    return null;
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
              child: StaggeredEntrance(
                children: [
                  Text(
                    widget.isNewUser ? 'Claim your handle' : 'Complete profile',
                    textAlign: TextAlign.center,
                    style: t.onBackgroundStyle(AppType.display()),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Your @username is how people find and follow you.',
                    textAlign: TextAlign.center,
                    style: t.onBackgroundMuted(AppType.body()),
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
                          ),
                          const SizedBox(height: AppSpace.md),
                          GlassInput(
                            controller: _username,
                            label: 'USERNAME',
                            hint: 'ada_prompts',
                            prefixIcon: Icons.alternate_email_rounded,
                            errorText: _usernameError,
                            onChanged: _checkAvailability,
                            suffix: _checking
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : _available == true
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: Color(0xFF34C759),
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpace.lg),
                          GlassButton(
                            label: 'Continue',
                            expand: true,
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'Username changes may be limited later to keep links stable.',
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
