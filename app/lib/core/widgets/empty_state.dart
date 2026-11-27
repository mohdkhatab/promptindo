import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/glass_tokens.dart';
import 'glass_button.dart';
import 'glass_container.dart';

/// Shared empty state, built from the glass system like everything else.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassContainer(
              borderRadius: 1000,
              width: 72,
              height: 72,
              padding: EdgeInsets.zero,
              child: Icon(icon, size: 30, color: t.textPrimary),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.onBackgroundStyle(AppType.subtitle()),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: t.onBackgroundMuted(AppType.body()),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.xl),
              GlassButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared error view with optional retry — used by every async screen so
/// failures never look like a broken screen.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = CupertinoIcons.exclamationmark_triangle,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: t.onBackgroundSecondary),
            const SizedBox(height: AppSpace.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: t.onBackgroundMuted(AppType.body()),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.xl),
              GlassButton(
                label: 'Try again',
                variant: GlassButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard screen header row: optional back button, title, trailing actions.
class GlassHeader extends StatelessWidget {
  const GlassHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showBack = true,
    this.onBack,
    this.large = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.screen,
      AppSpace.sm,
      AppSpace.screen,
      AppSpace.md,
    ),
  });

  final String title;
  final List<Widget>? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final bool large;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showBack) ...[
            GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              size: 40,
              iconSize: 17,
              semanticLabel: 'Back',
              color: t.onBackground,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: large
                  ? t.onBackgroundStyle(AppType.display())
                  : t.onBackgroundStyle(AppType.title()),
            ),
          ),
          if (trailing != null)
            ...trailing!.map(
              (w) => Padding(
                padding: const EdgeInsets.only(left: AppSpace.sm),
                child: w,
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable pagination spinner used at the bottom of every infinite list.
class LoadMoreSpinner extends StatelessWidget {
  const LoadMoreSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CupertinoActivityIndicator(radius: 9),
        ),
      ),
    );
  }
}
