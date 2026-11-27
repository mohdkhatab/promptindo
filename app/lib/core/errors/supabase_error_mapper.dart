import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Normalized application exception produced from Supabase/HTTP/network errors.
class AppMappedException implements Exception {
  const AppMappedException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'AppMappedException(code: $code, message: $message)';
}

/// Centralizes mapping of Supabase (`PostgrestException`, `AuthException`,
/// `StorageException`) and network errors into stable codes and safe messages.
class SupabaseErrorMapper {
  SupabaseErrorMapper._();

  static AppMappedException map(Object error) {
    if (error is AppMappedException) return error;
    if (error is PostgrestException) return mapPostgrest(error);
    if (error is AuthException) return mapAuth(error);
    if (error is StorageException) return mapStorage(error);
    if (error is TimeoutException) {
      return const AppMappedException(
        code: 'timeout',
        message: 'Error: timeout',
      );
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('connection refused') ||
        raw.contains('network')) {
      return const AppMappedException(
        code: 'network',
        message: 'Network error — check your connection.',
      );
    }

    return const AppMappedException(
      code: 'unknown',
      message: 'Something went wrong. Please try again.',
    );
  }

  static AppMappedException mapPostgrest(PostgrestException error) {
    switch (error.code) {
      case '23505':
        return const AppMappedException(
          code: 'conflict',
          message: 'Already exists or conflicts with an existing item.',
        );
      case '42501':
        return const AppMappedException(
          code: 'forbidden',
          message: 'You do not have permission to perform this action.',
        );
      case 'P0002':
        return const AppMappedException(
          code: 'not-found',
          message: 'The requested item was not found.',
        );
      case '22023':
      case '23514':
        return const AppMappedException(
          code: 'invalid-argument',
          message: 'Invalid input provided.',
        );
      case '28000':
        return const AppMappedException(
          code: 'requires-recent-login',
          message: 'Please sign in again first.',
        );
      default:
        final code = (error.code ?? '').trim();
        return AppMappedException(
          code: code.isEmpty ? 'database-error' : code,
          message: 'Database request failed.',
        );
    }
  }

  static AppMappedException mapAuth(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final msg = error.message.toLowerCase();

    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return const AppMappedException(
        code: 'email-not-confirmed',
        message: 'Please verify your email before signing in.',
      );
    }
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return const AppMappedException(
        code: 'invalid-credential',
        message: 'Email or password is incorrect.',
      );
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return const AppMappedException(
        code: 'email-already-in-use',
        message: 'That email is already registered — try signing in.',
      );
    }
    if (code == 'weak_password' || msg.contains('weak password')) {
      return const AppMappedException(
        code: 'weak-password',
        message: 'Password is too weak.',
      );
    }
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        error.statusCode == '429' ||
        msg.contains('rate limit') ||
        msg.contains('too many') ||
        msg.contains('for security purposes')) {
      return const AppMappedException(
        code: 'too-many-requests',
        message: 'Too many attempts. Try again later.',
      );
    }
    if (code == 'otp_expired' ||
        msg.contains('token has expired') ||
        msg.contains('expired or is invalid')) {
      return const AppMappedException(
        code: 'invalid-otp',
        message: 'Verification code is invalid or expired.',
      );
    }
    if (code == 'same_password' ||
        msg.contains('different from the old password')) {
      return const AppMappedException(
        code: 'same-password',
        message: 'New password must be different from your current password.',
      );
    }
    if (code == 'user_not_found' || msg.contains('user not found')) {
      return const AppMappedException(
        code: 'user-not-found',
        message: 'No account with that email.',
      );
    }
    if (code == 'session_not_found' || code == 'refresh_token_not_found') {
      return const AppMappedException(
        code: 'requires-recent-login',
        message: 'Please sign in again first.',
      );
    }

    return AppMappedException(
      code: code.isEmpty ? 'auth-error' : code,
      message: error.message.trim().isNotEmpty
          ? error.message.trim()
          : 'Authentication failed.',
    );
  }

  static AppMappedException mapStorage(StorageException error) {
    final status = error.statusCode ?? '';
    if (status == '401' || status == '403') {
      return const AppMappedException(
        code: 'forbidden',
        message: 'Permission denied for file upload.',
      );
    }
    if (status == '413') {
      return const AppMappedException(
        code: 'file-too-large',
        message: 'File exceeds the maximum allowed size.',
      );
    }
    return const AppMappedException(
      code: 'storage-error',
      message: 'Could not upload file.',
    );
  }

  static String messageFor(Object error) => map(error).message;
}
