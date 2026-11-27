import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode preference — a *UI* preference only, so SharedPreferences is the
/// right store (per the brief: nothing domain-related goes in prefs).
///
/// Defaults to the clean white theme on first launch, then persists the
/// user's explicit choice. The theme itself cross-fades over 300ms via
/// `MaterialApp.themeAnimationDuration`.
class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    if (mode != state) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Toggles between an explicit dark and light (used by the settings switch).
  Future<void> toggle(Brightness currentBrightness) async {
    final next = state == ThemeMode.system
        ? (currentBrightness == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark)
        : (state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    await setMode(next);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
