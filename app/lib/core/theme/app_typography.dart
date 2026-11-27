import 'package:flutter/material.dart';

/// Typography scale (UI spec §2). Inter is bundled in `assets/fonts` — the
/// default system font never shows up as an obvious fallback.
class AppType {
  AppType._();

  static const String family = 'Inter';
  static const String monoFamily = 'RobotoMono';

  static TextStyle _base({
    required double fontSize,
    required FontWeight fontWeight,
    double? height,
    double letterSpacing = 0,
    Color? color,
    String? fontFamily,
  }) {
    return TextStyle(
      fontFamily: fontFamily ?? family,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Display 32/700, line-height 1.15 (headers).
  static TextStyle display({Color? color}) => _base(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: color,
  );

  /// Title 22/700, line-height 1.15.
  static TextStyle title({Color? color}) => _base(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    color: color,
  );

  /// Subtitle 17/600, line-height 1.15.
  static TextStyle subtitle({Color? color}) => _base(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.15,
    color: color,
  );

  /// Body 15/400, line-height 1.3.
  static TextStyle body({Color? color}) => _base(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: color,
  );

  /// Caption 13/400, line-height 1.3.
  static TextStyle caption({Color? color}) => _base(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: color,
  );

  /// Micro 11/500, letter-spacing 0.5 — section labels like "TRENDING".
  /// Callers pass the label text already uppercased (there is no portable
  /// all-caps font feature across bundled fonts), e.g. via `SectionLabel`.
  static TextStyle micro({Color? color}) => _base(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.5,
    color: color,
  );

  /// Button label 15/600, letter-spacing 0.2.
  static TextStyle button({Color? color}) => _base(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: color,
  );

  /// Monospace-styled badge for the AI-model name on prompt cards.
  static TextStyle badge({Color? color, double fontSize = 11}) => _base(
    fontFamily: monoFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.2,
    color: color,
  );
}

/// Spacing / radius tokens (UI spec §3) — 8px grid only (4/8/12/16/24/32).
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Screen horizontal padding.
  static const double screen = 20;

  /// Gap between feed cards.
  static const double cardGap = 12;

  /// Card internal padding.
  static const double cardPadding = 16;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(22));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(28),
  );
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(24),
  );
  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(16));

  /// Fully pill-shaped button (height/2 → a large radius clips to a pill).
  static const BorderRadius pill = BorderRadius.all(Radius.circular(1000));
}
