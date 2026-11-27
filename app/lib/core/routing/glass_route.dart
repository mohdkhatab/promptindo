import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../widgets/glass_button.dart';

/// iOS-style push transition, retimed to the spec (§5):
///   • incoming screen slides from the right with `Curves.easeOutQuint`
///     over 380ms
///   • the previous screen scales to 0.95, shifts slightly left and darkens
///     by 10%
///   • popping is the reverse AND interactive — CupertinoPageRoute gives us
///     the 1:1 swipe-back gesture on Android as well, with the route's own
///     300ms settle when the gesture completes.
class GlassPageRoute<T> extends CupertinoPageRoute<T> {
  GlassPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
  });

  @override
  Duration get transitionDuration => AppMotion.screenPush;

  @override
  Duration get reverseTransitionDuration => AppMotion.screenPopSettle;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppMotion.pushCurve,
      reverseCurve: AppMotion.popCurve,
    );

    Widget content = child;

    // While THIS route is on top, the route below it scales + darkens.
    if (secondaryAnimation.value > 0) {
      content = AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (context, child) {
          final value = secondaryAnimation.value;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Transform.translate(
                offset: Offset(-18 * value, 0),
                child: Transform.scale(
                  scale: 1 - 0.05 * value,
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
              // 10% darken over the outgoing screen.
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.10 * value),
                child: const SizedBox.expand(),
              ),
            ],
          );
        },
        child: content,
      );
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(incoming),
      child: content,
    );
  }
}

/// Push helper so every screen uses the shared route.
Future<T?> pushGlass<T extends Object?>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  String? name,
}) {
  return Navigator.of(context).push<T>(
    GlassPageRoute<T>(
      builder: builder,
      settings: name == null ? null : RouteSettings(name: name),
    ),
  );
}

/// Replacement used for auth-flow transitions (no back stack into login).
Future<T?> pushGlassReplacement<T extends Object?>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  String? name,
}) {
  return Navigator.of(context).pushReplacement<T, Object?>(
    GlassPageRoute<T>(
      builder: builder,
      settings: name == null ? null : RouteSettings(name: name),
    ),
  );
}

/// Convenience for screens that just need a glass back button + title row.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: CupertinoIcons.chevron_back,
      semanticLabel: 'Back',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
