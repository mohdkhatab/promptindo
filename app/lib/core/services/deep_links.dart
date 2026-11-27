import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Deep links (`app_links`) — PromptIndo links resolve through the Next.js
/// site hosted on Vercel (`AppConfig.siteUrl`, e.g.
/// `https://www.promptindo.app/p/{id}`) + `assetlinks.json` / AASA, and the
/// app opens them through universal links.
class DeepLinkService {
  DeepLinkService(this._links);

  final AppLinks _links;
  StreamSubscription<Uri>? _sub;

  void start(void Function(Uri uri) onUri) {
    _sub?.cancel();
    _sub = _links.uriLinkStream.listen(onUri);
    // Cold start (app launched by tapping a link).
    _links
        .getInitialLink()
        .then((uri) {
          if (uri != null) onUri(uri);
        })
        .catchError((_) {});
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>(
  (ref) => DeepLinkService(AppLinks()),
);

/// Canonical share URL for a prompt using [AppConfig.normalizedSiteUrl].
String promptShareUrl(String promptId) =>
    '${AppConfig.normalizedSiteUrl}/p/$promptId';

/// True when [uri] is a Supabase password-recovery redirect.
///
/// Supports the `promptindo://reset-password` custom scheme and the https
/// fallback (`/reset-password#access_token=…` or `?code=…`).
bool isPasswordRecoveryUri(Uri uri) {
  if (uri.scheme == 'promptindo' && uri.host == 'reset-password') {
    return true;
  }
  if (uri.path == '/reset-password') return true;
  final fragment = uri.fragment;
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters['type'] == 'recovery' ||
      fragment.contains('type=recovery') ||
      fragment.contains('access_token=');
}

/// Parses `…/p/{promptId}` (and legacy `?id=` shapes) into a prompt id.
String? promptIdFromUri(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2 && segments[segments.length - 2] == 'p') {
    return segments.last;
  }
  final id = uri.queryParameters['id'];
  if (id != null && id.isNotEmpty) return id;
  return null;
}

/// Shared navigator key so deep links and global error notifications can work
/// without a BuildContext.
final appNavigatorKey = GlobalKey<NavigatorState>();

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => appNavigatorKey,
);
