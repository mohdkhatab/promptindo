import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/app_typography.dart';
import '../theme/glass_tokens.dart';
import 'glass_button.dart';
import 'glass_container.dart';

/// Bottom sheets + action sheets + dialogs, all glass (§5 + §6).
///
/// Sheets: slide up + fade with `easeOutCubic`/300ms, closing with
/// `easeInCubic`/250ms over a 40% black scrim. The sheet surface uses a
/// flatter fill/blur so any card inside stays the most glassy element —
/// never glass-on-glass.

Future<T?> showGlassBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(GlassSheetRoute<T>(builder: builder, dismissible: dismissible));
}

class GlassSheetRoute<T> extends PopupRoute<T> {
  GlassSheetRoute({required this.builder, this.dismissible = true});

  final WidgetBuilder builder;
  final bool dismissible;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.40);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get barrierDismissible => dismissible;

  @override
  Duration get transitionDuration => AppMotion.sheetOpen;

  @override
  Duration get reverseTransitionDuration => AppMotion.sheetClose;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      // Content clears the keyboard while the sheet is open.
      data: media.copyWith(viewInsets: EdgeInsets.zero),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: builder(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.sheetOpenCurve,
      reverseCurve: AppMotion.sheetCloseCurve,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// The sheet scaffold: drag handle + content, on the flatter sheet surface.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child, this.showHandle = true});

  final Widget child;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return GlassContainer(
      borderRadius: 28,
      blurSigma: 14, // flatter than foreground glass (never glass-on-glass)
      fillColor: t.sheetFill,
      showShadow: true,
      padding: EdgeInsets.fromLTRB(
        AppSpace.lg,
        showHandle ? AppSpace.sm : AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// iOS-style action sheet re-skinned with the glass fill/blur (§6).
class GlassSheetAction<T> {
  const GlassSheetAction({
    required this.label,
    required this.value,
    this.destructive = false,
    this.isDefault = false,
  });

  final String label;
  final T value;
  final bool destructive;
  final bool isDefault;
}

Future<T?> showGlassActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<GlassSheetAction<T>> actions,
  String cancelLabel = 'Cancel',
}) {
  return showGlassBottomSheet<T>(
    context,
    builder: (sheetContext) {
      return GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  0,
                  AppSpace.md,
                  AppSpace.md,
                ),
                child: Column(
                  children: [
                    if (title != null)
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GlassTokens.of(sheetContext)
                            .onGlass(AppType.subtitle()),
                      ),
                    if (message != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GlassTokens.of(sheetContext)
                            .onGlassMuted(AppType.caption()),
                      ),
                    ],
                  ],
                ),
              ),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
              _ActionRow<T>(
                action: actions[i],
                onTap: () => Navigator.of(sheetContext).pop(actions[i].value),
              ),
            ],
            const SizedBox(height: AppSpace.md),
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                label: cancelLabel,
                variant: GlassButtonVariant.secondary,
                onPressed: () => Navigator.of(sheetContext).maybePop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({required this.action, required this.onTap});

  final GlassSheetAction<T> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // GestureDetector, never InkWell — no Material ripple anywhere (§5).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            action.label,
            textAlign: TextAlign.center,
            style:
                AppType.body(
                  color: action.destructive
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF000000),
                ).copyWith(
                  fontSize: 17,
                  fontWeight: action.isDefault
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
          ),
        ),
      ),
    );
  }
}

/// Glass confirmation dialog (§3: 24px radius). Returns true when confirmed.
Future<bool> showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    GlassDialogRoute(
      builder: (dialogContext) {
        return GlassContainer(
          borderRadius: 24,
          blurSigma: 18,
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GlassTokens.of(dialogContext).onGlass(AppType.title()),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GlassTokens.of(dialogContext)
                    .onGlassMuted(AppType.body()),
              ),
              const SizedBox(height: AppSpace.xl),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: cancelLabel,
                      variant: GlassButtonVariant.secondary,
                      expand: true,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: GlassButton(
                      label: confirmLabel,
                      expand: true,
                      variant: destructive
                          ? GlassButtonVariant.destructive
                          : GlassButtonVariant.primary,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
  return result ?? false;
}

class GlassDialogRoute<T> extends PopupRoute<T> {
  GlassDialogRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.40);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => AppMotion.sheetOpen;

  @override
  Duration get reverseTransitionDuration => AppMotion.sheetClose;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl * 1.5),
        child: builder(context),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.sheetOpenCurve,
      reverseCurve: AppMotion.sheetCloseCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
