import 'package:flutter/material.dart';

/// Raw-background colour tokens (UI spec §1). Anything painted *on a glass
/// panel* uses [GlassTokens] instead — never these directly.
class AppColors {
  AppColors._();

  // Dark mode background: near-black with a very subtle radial gradient —
  // flat black reads cheap, a faint gradient reads premium.
  static const Color darkBackgroundCenter = Color(0xFF0A0A0A);
  static const Color darkBackgroundEdge = Color(0xFF121212);

  // Light mode background: iOS system background grey. NOT pure white —
  // pure white would make the white glass panels invisible.
  static const Color lightBackground = Color(0xFFF5F5F7);

  // Labels on the raw background (not on glass).
  static const Color darkLabel = Color(0xFFFFFFFF);
  static const Color darkLabelSecondary = Color(0x8CFFFFFF); // white 55%
  static const Color lightLabel = Color(0xFF1C1C1E); // near-black
  static const Color lightLabelSecondary = Color(0x8A1C1C1E); // ~55%

  // iOS system red — text/icons on glass only, never a solid fill block.
  static const Color destructive = Color(0xFFFF3B30);

  /// The single muted accent, used only when a hue is unavoidable
  /// (soft graphite-blue). Black-on-white / white-on-black comes first.
  static const Color accent = Color(0xFF54647A);

  /// Backdrop for every glass surface.
  static Widget background(BuildContext context, {required bool animated}) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final center = isDark
        ? AppColors.darkBackgroundCenter
        : AppColors.lightBackground;
    final edge = isDark
        ? AppColors.darkBackgroundEdge
        : AppColors.lightBackground;

    final decoration = isDark
        ? BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [center, edge],
              stops: const [0.0, 1.0],
            ),
          )
        : const BoxDecoration(color: lightBackground);

    if (!animated) {
      return DecoratedBox(
        position: DecorationPosition.background,
        decoration: decoration,
        child: const SizedBox.expand(),
      );
    }

    // Theme toggle cross-fades the background over 300ms (§7) instead of
    // flipping instantly — an instant flip looks broken on a liquid theme.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: decoration,
      child: const SizedBox.expand(),
    );
  }
}
