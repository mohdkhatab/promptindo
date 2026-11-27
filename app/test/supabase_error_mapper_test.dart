import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:promptindo/core/errors/supabase_error_mapper.dart';
import 'package:promptindo/core/services/app_error_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseErrorMapper.mapPostgrest', () {
    test('maps 23505, 42501, P0002, 22023, and 28000', () {
      expect(
        SupabaseErrorMapper.map(
          const PostgrestException(message: 'duplicate', code: '23505'),
        ).code,
        'conflict',
      );
      expect(
        SupabaseErrorMapper.map(
          const PostgrestException(message: 'rls', code: '42501'),
        ).code,
        'forbidden',
      );
      expect(
        SupabaseErrorMapper.map(
          const PostgrestException(message: 'missing', code: 'P0002'),
        ).code,
        'not-found',
      );
      expect(
        SupabaseErrorMapper.map(
          const PostgrestException(message: 'invalid', code: '22023'),
        ).code,
        'invalid-argument',
      );
      expect(
        SupabaseErrorMapper.map(
          const PostgrestException(message: 'auth', code: '28000'),
        ).code,
        'requires-recent-login',
      );
    });
  });

  group('SupabaseErrorMapper.mapAuth', () {
    test('maps core AuthException codes and messages', () {
      expect(
        SupabaseErrorMapper.map(
          const AuthException('Email not confirmed', code: 'email_not_confirmed'),
        ).code,
        'email-not-confirmed',
      );
      expect(
        SupabaseErrorMapper.map(
          const AuthException('Invalid login credentials'),
        ).code,
        'invalid-credential',
      );
      expect(
        SupabaseErrorMapper.map(
          const AuthException('User already registered'),
        ).code,
        'email-already-in-use',
      );
      expect(
        SupabaseErrorMapper.map(
          const AuthException('Password should be at least 8 characters', code: 'weak_password'),
        ).code,
        'weak-password',
      );
      expect(
        SupabaseErrorMapper.map(
          const AuthException('Rate limit exceeded', statusCode: '429'),
        ).code,
        'too-many-requests',
      );
      expect(
        SupabaseErrorMapper.map(
          const AuthException('Token has expired or is invalid', code: 'otp_expired'),
        ).code,
        'invalid-otp',
      );
    });
  });

  group('SupabaseErrorMapper generic errors', () {
    test('maps StorageException, TimeoutException, and network errors', () {
      expect(
        SupabaseErrorMapper.map(
          const StorageException('Forbidden', statusCode: '403'),
        ).code,
        'forbidden',
      );
      expect(
        SupabaseErrorMapper.map(
          const StorageException('Payload Too Large', statusCode: '413'),
        ).code,
        'file-too-large',
      );
      expect(
        SupabaseErrorMapper.map(TimeoutException('timed out')).code,
        'timeout',
      );
      expect(
        SupabaseErrorMapper.map(Exception('SocketException: Failed host lookup')).code,
        'network',
      );
    });

    test('AppErrorReporter.messageFor surfaces mapped user-facing message', () {
      final msg = AppErrorReporter.messageFor(
        const PostgrestException(message: 'rls', code: '42501'),
      );
      expect(msg, 'You do not have permission to perform this action.');
    });
  });
}
