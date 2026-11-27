import 'package:flutter/animation.dart';

/// Every curve and duration in PromptIndo comes from this table (UI spec §5).
///
/// Nothing in this app uses `Curves.linear` or a bare `Duration` without a
/// curve — if you need a new motion, add it here first so it stays consistent
/// across screens.
class AppMotion {
  AppMotion._();

  // --- durations ---------------------------------------------------------
  static const Duration pressDown = Duration(milliseconds: 100);
  static const Duration pressUp = Duration(milliseconds: 220);
  static const Duration likeFill = Duration(milliseconds: 350);
  static const Duration bookmarkFill = Duration(milliseconds: 250);
  static const Duration screenPush = Duration(milliseconds: 380);
  static const Duration screenPopSettle = Duration(milliseconds: 300);
  static const Duration sheetOpen = Duration(milliseconds: 300);
  static const Duration sheetClose = Duration(milliseconds: 250);
  static const Duration toastIn = Duration(milliseconds: 250);
  static const Duration toastHold = Duration(milliseconds: 1600);
  static const Duration toastOut = Duration(milliseconds: 200);
  static const Duration tabFade = Duration(milliseconds: 150);
  static const Duration tabPill = Duration(milliseconds: 250);
  static const Duration listItem = Duration(milliseconds: 300);
  static const Duration shimmerLoop = Duration(milliseconds: 1400);
  static const Duration dotFade = Duration(milliseconds: 200);
  static const Duration errorShake = Duration(milliseconds: 400);
  static const Duration focusGlow = Duration(milliseconds: 200);
  static const Duration themeFade = Duration(milliseconds: 300);
  static const Duration likeButton = Duration(milliseconds: 350);

  /// Stagger offset between list items on a screen's first load.
  static const Duration staggerStep = Duration(milliseconds: 40);

  // --- curves ------------------------------------------------------------
  static const Curve pressDownCurve = Curves.easeOut;
  static const Curve likeCurve = Curves.easeOutBack;
  static const Curve bookmarkCurve = Curves.easeOutCubic;
  static const Curve pushCurve = Curves.easeOutQuint;
  static const Curve popCurve = Curves.easeIn;
  static const Curve sheetOpenCurve = Curves.easeOutCubic;
  static const Curve sheetCloseCurve = Curves.easeInCubic;
  static const Curve toastCurve = Curves.easeOutBack;
  static const Curve tabFadeCurve = Curves.easeOut;
  static const Curve tabPillCurve = Curves.easeOutCubic;
  static const Curve listCurve = Curves.easeOutCubic;
  static const Curve shimmerCurve = Curves.easeInOut;
  static const Curve shakeCurve = Curves.easeInOut;
  static const Curve themeCurve = Curves.easeInOut;
  static const Curve dotCurve = Curves.easeOut;
  static const Curve focusCurve = Curves.easeOut;

  /// Release spring for every pressable glass control — damped, not a
  /// cartoonish bounce (mass 1, stiffness 300, damping 20 per spec §5).
  static const SpringDescription pressSpring = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 20,
  );

  /// Hero tag helpers — the single continuity cue from feed → details.
  static String thumbHero(String id) => 'prompt-thumb-$id';
  static String titleHero(String id) => 'prompt-title-$id';
}
