import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/backend_providers.dart';
import '../../../core/providers/theme_controller.dart';
import '../../../core/routing/glass_route.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_sheets.dart';
import '../../../core/widgets/glass_toast.dart';
import '../../../core/widgets/spring_press.dart';
import '../../auth/presentation/auth_gate.dart';
import '../presentation/terms_screens.dart';

/// Settings (user app only): appearance, security (change password), legal
/// links, account deletion and sign-out. Moderation lives server-side — there
/// is intentionally no admin surface in the app.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();

    final ok = await showGlassBottomSheet<bool>(
      context,
      builder: (sheetContext) => GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change password',
              style: GlassTokens.of(sheetContext).onGlass(AppType.title()),
            ),
            const SizedBox(height: AppSpace.lg),
            GlassInput(
              controller: current,
              label: 'CURRENT PASSWORD',
              obscureText: true,
            ),
            const SizedBox(height: AppSpace.md),
            GlassInput(
              controller: next,
              label: 'NEW PASSWORD',
              obscureText: true,
            ),
            const SizedBox(height: AppSpace.md),
            GlassInput(
              controller: confirm,
              label: 'CONFIRM NEW PASSWORD',
              obscureText: true,
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                label: 'Update password',
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    if (next.text != confirm.text) {
      GlassToast.show(
        context,
        'New passwords do not match',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: current.text,
            newPassword: next.text,
          );
      if (mounted) GlassToast.show(context, 'Password updated');
    } catch (e) {
      final raw = e.toString();
      if (mounted) {
        GlassToast.show(
          context,
          raw.contains('wrong-password') || raw.contains('invalid-credential')
              ? 'Current password is incorrect'
              : raw.contains('requires-recent-login')
              ? 'Please sign in again first'
              : 'Could not update password',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showGlassConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'Your profile, prompts, comments and uploads are removed '
          'permanently. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).deleteMyAccount();
      if (mounted) {
        GlassToast.show(context, 'Account deleted');
        Navigator.of(context).pushAndRemoveUntil(
          GlassPageRoute<void>(builder: (_) => const AuthGate()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        GlassToast.show(
          context,
          'Could not delete account',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showGlassConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You can sign back in any time.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        GlassPageRoute<void>(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final themeMode = ref.watch(themeControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.screen),
          children: [
            GlassHeader(title: 'Settings', padding: EdgeInsets.zero),
            const SizedBox(height: AppSpace.lg),
            GlassContainer(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.dark_mode_outlined,
                    label: 'Appearance',
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Auto'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) => ref
                          .read(themeControllerProvider.notifier)
                          .setMode(selection.first),
                    ),
                    onTap: null,
                  ),
                  _Row(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change password',
                    trailing: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: t.textSecondary,
                          ),
                    onTap: _busy ? null : _changePassword,
                  ),
                  _Row(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy policy',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: t.textSecondary,
                    ),
                    onTap: () => Navigator.of(context).push(
                      GlassPageRoute<void>(
                        builder: (_) => const PrivacyScreen(),
                      ),
                    ),
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'Terms of service',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: t.textSecondary,
                    ),
                    onTap: () => Navigator.of(context).push(
                      GlassPageRoute<void>(builder: (_) => const TermsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            GlassButton(
              label: 'Sign out',
              variant: GlassButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : _signOut,
            ),
            const SizedBox(height: AppSpace.md),
            GlassButton(
              label: 'Delete account',
              variant: GlassButtonVariant.destructive,
              expand: true,
              loading: _busy,
              onPressed: _busy ? null : _deleteAccount,
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              'PromptIndo v1.0.0',
              textAlign: TextAlign.center,
              style: t.onBackgroundMuted(AppType.micro()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return SpringPress(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: t.textPrimary),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(label, style: t.onGlass(AppType.body()))),
            trailing,
          ],
        ),
      ),
    );
  }
}
