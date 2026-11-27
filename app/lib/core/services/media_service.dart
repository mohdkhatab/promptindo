import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../errors/supabase_error_mapper.dart';

class UploadedMedia {
  const UploadedMedia({required this.fileId, required this.url});

  final String fileId;
  final String url;

  /// Stored on `prompts.thumbnail_path` so the delete webhook knows to remove
  /// the Appwrite object (the bucket itself is never exposed to the app).
  String get storageRef => 'appwrite:$fileId';
}

/// Backend-mediated media upload. The Appwrite server key never reaches the
/// Flutter client; the app only sends bytes + its Supabase access token.
class MediaService {
  MediaService(this._supabase, this._http);

  final SupabaseClient _supabase;
  final http.Client _http;

  Future<UploadedMedia> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const AppMappedException(
        code: 'not-signed-in',
        message: 'Please sign in again to upload an image.',
      );
    }

    final uri = Uri.parse(
      '${AppConfig.normalizedApiBaseUrl}/api/media/upload',
    );
    final response = await _http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': contentType,
            'X-File-Name': fileName,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 201 && response.statusCode != 200) {
      var message = 'Could not upload the image.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final error = body['error'];
          if (error is Map<String, dynamic> && error['message'] is String) {
            message = error['message'] as String;
          }
        }
      } catch (_) {
        // Keep the generic message for non-JSON failures.
      }
      throw AppMappedException(code: 'media-upload-failed', message: message);
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['fileId'] is! String ||
        body['url'] is! String) {
      throw const AppMappedException(
        code: 'media-upload-failed',
        message: 'Upload response was invalid.',
      );
    }

    return UploadedMedia(
      fileId: body['fileId'] as String,
      url: body['url'] as String,
    );
  }
}
