import 'dart:async';

import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/app_typography.dart';
import 'glass_container.dart';

/// Pill-shaped glass toast (§5): scale-in from 0.9 + fade with easeOutBack
/// over 250ms, hold 1600ms, fade out over 200ms. Sits near the bottom, above
/// the nav bar — never a full-width Material snackbar. One toast at a time.
class GlassToast {
  GlassToast._();

  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_rounded,
  }) {
    remove();
    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        icon: icon,
        onFinished: () {
          if (identical(_entry, entry)) {
            _entry = null;
            entry.remove();
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Immediately dismiss whatever toast is on screen.
  static void remove() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    try {
      entry.remove();
    } catch (_) {
      // Already removed by the overlay — nothing to do.
    }
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.icon,
    required this.onFinished,
  });

  final String message;
  final IconData icon;
  final VoidCallback onFinished;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.toastOut,
      reverseDuration: AppMotion.toastOut,
    )..forward();
    _run();
  }

  Future<void> _run() async {
    await Future<void>.delayed(AppMotion.toastIn + AppMotion.toastHold);
    if (!mounted || _finished) return;
    await _controller.reverse();
    _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Positioned(
      left: AppSpace.xl,
      right: AppSpace.xl,
      // Above the floating nav bar (16 + 64 + margin) plus safe area.
      bottom: media.padding.bottom + 104,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(
              CurvedAnimation(
                parent: _controller,
                curve: AppMotion.toastCurve,
                reverseCurve: Curves.easeIn,
              ),
            ),
            child: Center(
              child: GlassContainer(
                borderRadius: 1000,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: 12,
                ),
                fillColor: const Color(0xF2FFFFFF),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 16, color: Colors.black),
                    const SizedBox(width: AppSpace.sm),
                    Flexible(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppType.button(color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
