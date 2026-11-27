import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../animation/app_curves.dart';

/// Error shake (§5): horizontal shake, 3 cycles of ±6px, `Curves.easeInOut`,
/// 400ms total — only on hard validation failures, never on every server error.
class ShakeWidget extends StatefulWidget {
  const ShakeWidget({super.key, required this.child, required this.trigger});

  final Widget child;

  /// Increment (e.g. a failed-attempt counter) to fire the shake.
  final int trigger;

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.errorShake,
  );
  int _lastTrigger = 0;

  @override
  void initState() {
    super.initState();
    _lastTrigger = widget.trigger;
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != _lastTrigger) {
      _lastTrigger = widget.trigger;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = AppMotion.shakeCurve.transform(_controller.value);
        final dx = math.sin(t * 3 * 2 * math.pi) * 6;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
