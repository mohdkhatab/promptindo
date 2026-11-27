import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_typography.dart';

/// App-wide ThemeData: no Material ripple anywhere, Inter everywhere,
/// Cupertino-style page transitions on BOTH platforms (§5 requires the
/// interactive swipe-back to work on Android too).
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final label = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  final labelSecondary = isDark
      ? const Color(0x8CFFFFFF)
      : const Color(0x8A1C1C1E);
  final background = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F7);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF54647A),
        brightness: brightness,
        surface: background,
        onSurface: label,
        onSurfaceVariant: labelSecondary,
      ).copyWith(
        primary: isDark ? Colors.white : Colors.black,
        onPrimary: isDark ? Colors.black : Colors.white,
        secondary: isDark ? Colors.white : Colors.black,
        onSecondary: isDark ? Colors.black : Colors.white,
        error: const Color(0xFFFF3B30),
        onError: Colors.white,
        outline: labelSecondary,
      );

  final textTheme = TextTheme(
    displayLarge: AppType.display(color: label),
    displayMedium: AppType.display(color: label),
    headlineLarge: AppType.display(color: label),
    titleLarge: AppType.title(color: label),
    titleMedium: AppType.subtitle(color: label),
    titleSmall: AppType.subtitle(color: label),
    bodyLarge: AppType.body(color: label),
    bodyMedium: AppType.body(color: label),
    bodySmall: AppType.caption(color: labelSecondary),
    labelLarge: AppType.button(color: label),
    labelMedium: AppType.micro(color: label),
    labelSmall: AppType.micro(color: labelSecondary),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: AppType.family,
    scaffoldBackgroundColor: Colors.transparent,
    // No Material ripple anywhere in this app (§5 "What NOT to do").
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    primaryColor: isDark ? Colors.white : Colors.black,
    textTheme: textTheme,
    dividerColor: labelSecondary.withValues(alpha: 0.18),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: label, size: 22),
      titleTextStyle: AppType.title(color: label),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    // iOS-style transitions + interactive swipe-back on Android as well.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: isDark ? Colors.white : Colors.black,
      scaffoldBackgroundColor: Colors.transparent,
      barBackgroundColor: Colors.transparent,
      textTheme: CupertinoTextThemeData(
        primaryColor: label,
        textStyle: AppType.body(color: label),
        navTitleTextStyle: AppType.subtitle(color: label),
        navLargeTitleTextStyle: AppType.display(color: label),
        actionTextStyle: AppType.button(color: label),
        pickerTextStyle: AppType.body(color: label),
        tabLabelTextStyle: AppType.micro(color: labelSecondary),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: label,
      selectionColor: label.withValues(alpha: 0.25),
      selectionHandleColor: label,
    ),
    snackBarTheme: const SnackBarThemeData(
      // The app uses its own pill-shaped glass toast instead.
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppSpace.dialogRadius),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      showDragHandle: false,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: label,
      linearTrackColor: label.withValues(alpha: 0.08),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: label,
      textColor: label,
      titleTextStyle: AppType.body(color: label),
      subtitleTextStyle: AppType.caption(color: labelSecondary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      side: BorderSide.none,
      labelStyle: AppType.caption(color: label),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );
}
