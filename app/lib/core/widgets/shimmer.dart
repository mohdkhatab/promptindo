import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/app_typography.dart';
import '../theme/glass_tokens.dart';
import 'glass_container.dart';

/// Skeleton shimmer (§5): a soft white light-band (~20% over the glass fill,
/// never grey) sweeping left→right, 1400ms loop on `Curves.easeInOut`.
class GlassShimmer extends StatefulWidget {
  const GlassShimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmerLoop,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(GlassShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final center = -0.35 + t * 1.7;

        double previous = 0;
        final stops = <double>[];
        for (final raw in <double>[
          center - 0.32,
          center - 0.14,
          center + 0.14,
          center + 0.32,
        ]) {
          var value = raw.clamp(0.0, 1.0);
          if (value < previous) value = previous;
          stops.add(value);
          previous = value;
        }

        return ShaderMask(
          // Additive: the white band passes OVER the placeholder shapes.
          blendMode: BlendMode.plus,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Colors.transparent,
              Color(0x33FFFFFF),
              Color(0x33FFFFFF),
              Colors.transparent,
            ],
            stops: stops,
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A glass-tinted placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return GlassContainer(
      borderRadius: radius,
      width: width,
      height: height,
      padding: EdgeInsets.zero,
      fillColor: t.fill,
      showShadow: false,
      borderSides: GlassBorderSides.none,
      child: const SizedBox.shrink(),
    );
  }
}

/// Generic card-shaped loading placeholder used by every list first-load.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.withThumbnail = true});

  final bool withThumbnail;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: withThumbnail
          ? EdgeInsets.zero
          : const EdgeInsets.all(AppSpace.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (withThumbnail) ...[
            const SkeletonBox(height: 160, radius: 0),
            const SizedBox(height: AppSpace.md),
          ],
          Padding(
            padding: withThumbnail
                ? const EdgeInsets.fromLTRB(
                    AppSpace.cardPadding,
                    0,
                    AppSpace.cardPadding,
                    AppSpace.cardPadding,
                  )
                : EdgeInsets.zero,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 180, height: 16),
                SizedBox(height: AppSpace.sm),
                SkeletonBox(width: 110, height: 12),
                SizedBox(height: AppSpace.md),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: AppSpace.xs),
                SkeletonBox(width: 220, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
