import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';
import '../widgets/glass_toast.dart';
import 'deep_links.dart';

/// Centralized, user-visible runtime diagnostics for development and support.
/// Sensitive tokens and credentials are never included in the message.
class AppErrorReporter {
  AppErrorReporter._();

  static bool _installed = false;
  static String? _lastMessage;
  static DateTime? _lastAt;

  static void install() {
    if (_installed) return;
    _installed = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
  }

  static void report(Object error, [StackTrace? stack]) {
    final message = _safeMessage(error);
    debugPrint('PromptIndo error: $message');
    if (stack != null) debugPrintStack(stackTrace: stack);

    // Prevent one repeated network error from covering the screen in toasts.
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastMessage = message;
    _lastAt = now;

    final context = appNavigatorKey.currentContext;
    if (context != null) {
      GlassToast.show(context, message, icon: Icons.error_outline_rounded);
    }
  }

  static String messageFor(Object error) => _safeMessage(error);

  static String _safeMessage(Object error) {
    if (error is AppMappedException) return error.message;
    if (error is PostgrestException ||
        error is AuthException ||
        error is StorageException) {
      return SupabaseErrorMapper.messageFor(error);
    }

    final raw = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    final code = RegExp(r'code[=: ]+([a-zA-Z0-9_-]+)')
        .firstMatch(raw)
        ?.group(1);
    if (code != null && code.isNotEmpty) return 'Error: $code';
    if (error is TimeoutException || raw.contains('TimeoutException')) {
      return 'Error: timeout';
    }
    if (raw.toLowerCase().contains('network') ||
        raw.contains('SocketException')) {
      return 'Error: network';
    }
    if (raw.contains('permission-denied')) return 'Error: permission-denied';
    if (raw.isEmpty) return 'Error: unknown';
    return raw.length > 100 ? '${raw.substring(0, 100)}…' : raw;
  }
}

Future<void> reportAsyncError(Future<void> future) async {
  try {
    await future;
  } catch (error, stack) {
    AppErrorReporter.report(error, stack);
  }
}
