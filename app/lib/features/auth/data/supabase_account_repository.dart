import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/supabase_error_mapper.dart';
import '../domain/account_repository.dart';

/// Next.js API + Supabase implementation of [AccountRepository].
class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(
    this._supabase,
    this._httpClient, {
    this.onAccountDeleted,
  });

  final SupabaseClient _supabase;
  final http.Client _httpClient;
  final Future<void> Function()? onAccountDeleted;

  @override
  Future<void> deleteMyAccount() async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const AppMappedException(
        code: 'requires-recent-login',
        message: 'Please sign in again first.',
      );
    }

    final uri = Uri.parse('${AppConfig.normalizedApiBaseUrl}/api/account/delete');
    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppMappedException(
        code: response.statusCode == 401
            ? 'requires-recent-login'
            : 'account-delete-failed',
        message: 'Could not delete account (${response.statusCode}).',
      );
    }

    if (onAccountDeleted != null) {
      try {
        await onAccountDeleted!();
      } catch (_) {}
    }
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Session is already deleted server-side.
    }
  }
}
