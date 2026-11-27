import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/app_typography.dart';

/// Staggered entrance for a screen's FIRST load only (§5): each child fades
/// + slides up over 300ms easeOutCubic, offset by 40ms from the previous one.
/// Pass `animate: false` on rebuilds / pagination pages.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.animate = true,
  });

  final List<Widget> children;
  final bool animate;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final count = widget.children.length;
    final total =
        AppMotion.listItem +
        (count > 0 ? AppMotion.staggerStep * (count - 1) : Duration.zero);
    _controller = AnimationController(vsync: this, duration: total);
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Column(children: widget.children);
    }

    final totalMs = _controller.duration!.inMilliseconds;

    return AnimatedBuilder(
      animation: _controller,
      child: Column(children: widget.children),
      builder: (context, child) {
        final children = widget.children;
        final wrapped = <Widget>[];
        for (var i = 0; i < children.length; i++) {
          final startMs = AppMotion.staggerStep.inMilliseconds * i;
          final endMs = startMs + AppMotion.listItem.inMilliseconds;
          final interval = Interval(
            (startMs / totalMs).clamp(0.0, 1.0),
            (endMs / totalMs).clamp(0.0, 1.0),
            curve: AppMotion.listCurve,
          );
          wrapped.add(
            FadeTransition(
              opacity: _controller.drive(CurveTween(curve: interval)),
              child: SlideTransition(
                position: _controller.drive(
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: interval)),
                ),
                child: children[i],
              ),
            ),
          );
        }
        return Column(children: wrapped);
      },
    );
  }
}

/// "TRENDING"-style micro section label (uppercase, letter-spaced).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(), style: AppType.micro(color: color)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
