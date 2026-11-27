import 'dart:ui';

import 'package:flutter/material.dart';

import '../animation/app_curves.dart';
import '../theme/glass_tokens.dart';

/// THE glass surface. Every card, button, sheet, nav bar and dialog in
/// PromptIndo is built from this widget — there are no one-off
/// `BackdropFilter` calls in screen files (UI spec §4).
///
/// Layer order matches the spec:
///   1. BackdropFilter (blur, default σ26)
///   2. Container with the theme's fill + hairline border + radius
///   3. child content
/// plus the required floating shadow (black 30%, blur 20, y-offset 8).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22,
    this.blurSigma = 26,
    this.fillColor,
    this.borderStrongColor,
    this.borderFaintColor,
    this.borderWidth = 1,
    this.showShadow = true,
    this.width,
    this.height,
    this.alignment,
    this.onTap,
    this.borderSides = GlassBorderSides.full,
  });

  final Widget child;

  /// 22px cards by default; pass a large radius for pill shapes.
  final double borderRadius;

  /// Default 26 (spec allows 24–30). Pass a subtler value for list rows or
  /// sheet surfaces that must sit *behind* the primary glass element.
  final double blurSigma;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? fillColor;
  final Color? borderStrongColor;
  final Color? borderFaintColor;
  final double borderWidth;
  final bool showShadow;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final VoidCallback? onTap;
  final GlassBorderSides borderSides;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final radius = BorderRadius.circular(borderRadius);

    final strong = borderStrongColor ?? t.borderStrong;
    final faint = borderFaintColor ?? t.borderFaint;

    final Border border;
    switch (borderSides) {
      case GlassBorderSides.full:
        border = Border(
          top: BorderSide(width: borderWidth, color: strong),
          left: BorderSide(width: borderWidth, color: strong),
          right: BorderSide(width: borderWidth, color: strong),
          // Bottom edge faded — this is what sells the light-catching look.
          bottom: BorderSide(width: borderWidth, color: faint),
        );
      case GlassBorderSides.topOnly:
        border = Border(
          top: BorderSide(width: borderWidth, color: strong),
          left: BorderSide(width: borderWidth, color: strong),
          right: BorderSide(width: borderWidth, color: strong),
          bottom: BorderSide(width: borderWidth, color: Colors.transparent),
        );
      case GlassBorderSides.none:
        border = Border.all(width: 0, color: Colors.transparent);
    }

    // AnimatedContainer makes the dark↔light toggle cross-fade the glass
    // fills over 300ms instead of flipping instantly (§7).
    Widget panel = AnimatedContainer(
      duration: AppMotion.themeFade,
      curve: AppMotion.themeCurve,
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor ?? t.fill,
        borderRadius: radius,
        border: border,
      ),
      child: child,
    );

    Widget result = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: panel,
      ),
    );

    if (showShadow) {
      // The glass should look like it floats slightly above the background.
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: t.shadowColor,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: result,
      );
    }

    if (onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: result,
      );
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }
    return result;
  }
}

enum GlassBorderSides { full, topOnly, none }
