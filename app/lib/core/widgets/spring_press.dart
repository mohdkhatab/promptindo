import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../animation/app_curves.dart';

/// Press-scale wrapper used by every pressable glass control:
///   press   → scale to 0.96 over 100ms, `Curves.easeOut`
///   release → spring back (mass 1 / stiffness 300 / damping 20), ~220ms
class SpringPress extends StatefulWidget {
  const SpringPress({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.scaleDown = 0.96,
    this.enabled = true,
    this.behavior = HitTestBehavior.deferToChild,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final double scaleDown;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<SpringPress> createState() => _SpringPressState();
}

class _SpringPressState extends State<SpringPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 1,
      duration: AppMotion.pressDown,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    widget.onTapDown?.call();
    _controller.animateTo(
      0,
      duration: AppMotion.pressDown,
      curve: AppMotion.pressDownCurve,
    );
  }

  void _release() {
    widget.onTapUp?.call();
    _controller.animateWith(
      SpringSimulation(AppMotion.pressSpring, _controller.value, 1, 0),
    );
  }

  void _cancel() {
    widget.onTapCancel?.call();
    _controller.animateWith(
      SpringSimulation(AppMotion.pressSpring, _controller.value, 1, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: widget.scaleDown,
      end: 1.0,
    ).animate(_controller);

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: widget.enabled ? (_) => _press() : null,
      onTapUp: widget.enabled ? (_) => _release() : null,
      onTapCancel: widget.enabled ? _cancel : null,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}
