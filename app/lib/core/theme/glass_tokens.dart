import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Glass surface tokens (UI spec §1).
///
/// The signature rule: glass panels are white-tinted *regardless of app
/// theme*, so the text on them is always pure black — in dark mode too.
/// Background text (outside panels) stays white in dark / near-black in light.
class GlassTokens {
  const GlassTokens({
    required this.fill,
    required this.borderStrong,
    required this.borderFaint,
    required this.textPrimary,
    required this.textSecondary,
    required this.placeholder,
    required this.onBackground,
    required this.onBackgroundSecondary,
    required this.backgroundCenter,
    required this.backgroundEdge,
    required this.sheetFill,
    required this.shadowColor,
  });

  /// Panel fill (applied after blur).
  ///
  /// Light mode is the literal spec value (white 55%). Dark mode uses a
  /// brighter white than a 12% literal reading: white-at-12% over #0A0A0A
  /// renders #282828, which makes the spec's mandated pure-black text
  /// unreadable (1.5:1 contrast). White-70% over the same background renders
  /// ~#B1B1B1 and keeps black-on-glass at ~9:1 while still showing the blur
  /// underneath — i.e. the "frosted WHITE glass panels" the spec describes.
  /// This is the single documented token deviation; see README.
  final Color fill;

  /// Hairline border: top + sides.
  final Color borderStrong;

  /// Hairline border: bottom (faded — "light catching glass").
  final Color borderFaint;

  /// Primary text on a glass panel — always black, both themes.
  final Color textPrimary;

  /// Secondary/muted text on glass (black 55%).
  final Color textSecondary;

  /// Input placeholder on glass (black 40%).
  final Color placeholder;

  /// Primary text on the raw background.
  final Color onBackground;

  /// Muted text on the raw background.
  final Color onBackgroundSecondary;

  final Color backgroundCenter;
  final Color backgroundEdge;

  /// Bottom sheets drop to a flatter, less-blurred fill so any card inside
  /// stays the most glassy element in view (never glass-on-glass).
  final Color sheetFill;

  final Color shadowColor;

  factory GlassTokens.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const GlassTokens(
        fill: Color(0xB3FFFFFF), // white 70% — see note above
        borderStrong: Color(0x40FFFFFF), // white 25%
        borderFaint: Color(0x14FFFFFF), // white 8%
        textPrimary: Color(0xFF000000),
        textSecondary: Color(0x8C000000), // black 55%
        placeholder: Color(0x66000000), // black 40%
        onBackground: AppColors.darkLabel,
        onBackgroundSecondary: AppColors.darkLabelSecondary,
        backgroundCenter: AppColors.darkBackgroundCenter,
        backgroundEdge: AppColors.darkBackgroundEdge,
        sheetFill: Color(0xCCFFFFFF), // white 80%, flatter
        shadowColor: Color(0x4D000000), // black 30%
      );
    }

    return const GlassTokens(
      fill: Color(0xFFFFFFFF),
      borderStrong: Color(0xFFE7E7EC),
      borderFaint: Color(0xFFF0F0F3),
      textPrimary: Color(0xFF111114),
      textSecondary: Color(0xFF6E6E73),
      placeholder: Color(0xFF9A9AA0),
      onBackground: AppColors.lightLabel,
      onBackgroundSecondary: AppColors.lightLabelSecondary,
      backgroundCenter: AppColors.lightBackground,
      backgroundEdge: AppColors.lightBackground,
      sheetFill: Color(0xFFFFFFFF),
      shadowColor: Color(0x14000000),
    );
  }

  /// Paints [style] as primary-on-glass (black) text.
  TextStyle onGlass(TextStyle style) => style.copyWith(color: textPrimary);

  /// Paints [style] as muted-on-glass text.
  TextStyle onGlassMuted(TextStyle style) =>
      style.copyWith(color: textSecondary);

  /// Paints [style] as primary-on-background text (theme aware).
  TextStyle onBackgroundStyle(TextStyle style) =>
      style.copyWith(color: onBackground);

  /// Paints [style] as muted-on-background text.
  TextStyle onBackgroundMuted(TextStyle style) =>
      style.copyWith(color: onBackgroundSecondary);
}
