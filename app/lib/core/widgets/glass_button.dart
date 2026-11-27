import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'glass_container.dart';
import 'spring_press.dart';

/// Pill-shaped glass buttons (UI spec §6):
///   primary     — white-glass pill, black text/icon, white inner top highlight
///   secondary   — transparent glass fill, black 1.5px border, black text
///   destructive — white-glass fill with red text/icon (never a solid red block)
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    this.edgeHighlight = true,
    this.borderColor,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final EdgeInsetsGeometry padding;
  final bool edgeHighlight;
  final Color? borderColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    Color fill;
    Color? border;
    Color labelColor = textColor ?? const Color(0xFF000000);
    double borderWidth = 0;

    switch (variant) {
      case GlassButtonVariant.primary:
        // High-contrast solid ink pill on the white canvas.
        fill = const Color(0xFF111114);
        labelColor = textColor ?? const Color(0xFFFFFFFF);
      case GlassButtonVariant.secondary:
        fill = Colors.transparent;
        border = borderColor ?? const Color(0xFF000000);
        borderWidth = 1.5;
      case GlassButtonVariant.destructive:
        fill = const Color(0xE6FFFFFF);
        labelColor = textColor ?? const Color(0xFFFF3B30);
    }

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          CupertinoActivityIndicator(radius: 9, color: labelColor)
        else if (icon != null)
          Icon(icon, size: 18, color: labelColor),
        if ((loading || icon != null) && label.isNotEmpty)
          const SizedBox(width: AppSpace.sm),
        if (label.isNotEmpty)
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.button(color: labelColor),
          ),
      ],
    );

    Widget button = GlassContainer(
      borderRadius: 1000,
      padding: padding,
      width: expand ? double.infinity : null,
      fillColor: fill,
      borderStrongColor: border,
      borderFaintColor: border,
      borderWidth: borderWidth,
      showShadow: border == null,
      borderSides: border == null
          ? GlassBorderSides.none
          : GlassBorderSides.full,
      child: edgeHighlight && border == null
          ? _EdgeHighlighted(child: content)
          : content,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SpringPress(enabled: enabled, onTap: onPressed, child: button),
    );
  }
}

/// 1px gradient line along the very top of the button (white 40% →
/// transparent) — sells the "glass edge catching light" look.
class _EdgeHighlighted extends StatelessWidget {
  const _EdgeHighlighted({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 24,
          right: 24,
          height: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Text-only pressable (used for inline links like "Forgot password?" that
/// sit on the raw background, where a glass pill would be overkill).
class GlassTextButton extends StatelessWidget {
  const GlassTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 16, color: color),
            if (icon != null) const SizedBox(width: 6),
            Text(
              label,
              style: AppType.button(color: color).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: color?.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular glass icon button (back buttons, sheet grabs, action rows).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 38,
    this.iconSize = 20,
    this.color,
    this.fillColor,
    this.showShadow = false,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? fillColor;
  final bool showShadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = color ?? const Color(0xFF000000);
    return SpringPress(
      enabled: onPressed != null,
      onTap: onPressed,
      child: GlassContainer(
        borderRadius: 1000,
        width: size,
        height: size,
        padding: EdgeInsets.zero,
        fillColor: fillColor,
        showShadow: showShadow,
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Icon(icon, size: iconSize, color: t),
        ),
      ),
    );
  }
}

enum GlassButtonVariant { primary, secondary, destructive }
