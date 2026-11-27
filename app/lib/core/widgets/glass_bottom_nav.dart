import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/app_typography.dart';
import '../theme/glass_tokens.dart';
import 'glass_container.dart';
import 'spring_press.dart';

/// Floating frosted-glass bottom nav (§6): 16px from screen edges + safe
/// area, ~64px tall, fully pill-shaped, 5 icon+label tabs, an active glass
/// pill that *slides* between tabs (250ms easeOutCubic) and labels that
/// crossfade (150ms easeOut).
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final height = 64.0;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        0,
        AppSpace.lg,
        AppSpace.lg,
      ),
      child: GlassContainer(
        borderRadius: 1000,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                // The sliding glass pill.
                AnimatedPositioned(
                  duration: AppMotion.tabPill,
                  curve: AppMotion.tabPillCurve,
                  left:
                      tabWidth * currentIndex +
                      (tabWidth - tabWidth * 0.62) / 2,
                  top: (height - tabWidth * 0.62) / 2,
                  width: tabWidth * 0.62,
                  height: tabWidth * 0.62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D5DF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(1000),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SizedBox(
                        width: tabWidth,
                        height: height,
                        child: SpringPress(
                          onTap: () => onSelect(i),
                          scaleDown: 0.94,
                          child: _NavItem(
                            item: items[i],
                            active: i == currentIndex,
                            labelColor: t.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.labelColor,
  });

  final GlassNavItem item;
  final bool active;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          active ? (item.activeIcon ?? item.icon) : item.icon,
          size: 21,
          color: labelColor,
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: AppMotion.tabFade,
          curve: AppMotion.tabFadeCurve,
          style: AppType.micro(
            color: active ? labelColor : labelColor.withValues(alpha: 0.5),
          ),
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.clip),
        ),
      ],
    );
  }
}

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.semanticLabel,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String? semanticLabel;
}
