import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../errors/supabase_error_mapper.dart';

/// Resolves a user-typed category name to a category row through the backend.
/// The app has no built-in category list; users can enter anything.
class CategoryService {
  CategoryService(this._supabase, this._http);

  final SupabaseClient _supabase;
  final http.Client _http;

  Future<String?> resolve(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;

    final response = await _http
        .post(
          Uri.parse(
            '${AppConfig.normalizedApiBaseUrl}/api/categories/resolve',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'name': trimmed}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppMappedException(
        code: 'category-resolve-failed',
        message: 'Could not save the category.',
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    final category = body['category'];
    if (category is Map<String, dynamic> && category['id'] is String) {
      return category['id'] as String;
    }
    return null;
  }
}
