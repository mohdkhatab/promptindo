import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supabase_error_mapper.dart';
import '../domain/auth_repository.dart';

/// Supabase implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._supabase,
    this._google, {
    this.onBeforeSignOut,
  });

  final SupabaseClient _supabase;
  final GoogleSignIn _google;
  final Future<void> Function()? onBeforeSignOut;

  @override
  Stream<String?> authStateChanges() async* {
    yield _supabase.auth.currentSession?.user.id;
    await for (final event in _supabase.auth.onAuthStateChange) {
      yield event.session?.user.id;
    }
  }

  @override
  String? get currentUid => _supabase.auth.currentUser?.id;

  @override
  String? get currentEmail => _supabase.auth.currentUser?.email;

  @override
  bool get isEmailVerified =>
      _supabase.auth.currentUser?.emailConfirmedAt != null;

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = res.user;
      if (user == null) {
        throw const AppMappedException(
          code: 'user-not-found',
          message: 'No account with that email.',
        );
      }
      return user.id;
    } on AuthException catch (e) {
      final mapped = SupabaseErrorMapper.mapAuth(e);
      if (mapped.code == 'email-not-confirmed') {
        try {
          await _supabase.auth.resend(
            type: OtpType.signup,
            email: email.trim(),
          );
        } catch (_) {
          // VerifyEmailScreen still exposes manual resend with cooldown.
        }
      }
      throw mapped;
    }
  }

  @override
  Future<String> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      final user = res.user;
      if (user == null) {
        throw const AppMappedException(
          code: 'unknown',
          message: 'Could not create the account. Try again.',
        );
      }
      // Supabase returns an empty identities list when an existing confirmed
      // email is passed to signUp with email confirmation enabled.
      if (user.identities != null && user.identities!.isEmpty) {
        throw const AppMappedException(
          code: 'email-already-in-use',
          message: 'That email is already registered — try signing in.',
        );
      }
      return user.id;
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<String> signInWithGoogle() async {
    try {
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AppMappedException(
          code: 'missing-id-token',
          message: 'Google did not return an ID token.',
        );
      }
      final authorization = await account.authorizationClient
          .authorizationForScopes(const ['email', 'profile']);
      final res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );
      final user = res.user;
      if (user == null) {
        throw const AppMappedException(
          code: 'unknown',
          message: 'Could not sign in. Please try again.',
        );
      }
      return user.id;
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> sendVerificationEmail({String? email}) async {
    final targetEmail = (email ?? _supabase.auth.currentUser?.email ?? '')
        .trim();
    if (targetEmail.isEmpty) return;
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: targetEmail);
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: code.trim(),
      );
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'promptindo://reset-password',
      );
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<bool> completePasswordRecovery(Uri uri) async {
    try {
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        await _supabase.auth.exchangeCodeForSession(code);
      } else {
        await _supabase.auth.getSessionFromUrl(uri);
      }
      return _supabase.auth.currentSession != null;
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AppMappedException(
        code: 'requires-recent-login',
        message: 'Please sign in again first.',
      );
    }

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException catch (e) {
      final mapped = SupabaseErrorMapper.mapAuth(e);
      if (mapped.code == 'invalid-credential') {
        throw const AppMappedException(
          code: 'wrong-password',
          message: 'Current password is incorrect',
        );
      }
      throw const AppMappedException(
        code: 'requires-recent-login',
        message: 'Please sign in again first',
      );
    }

    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> reload() async {
    if (_supabase.auth.currentSession == null) return;
    try {
      await _supabase.auth.refreshSession();
    } on AuthException catch (e) {
      throw SupabaseErrorMapper.mapAuth(e);
    }
  }

  @override
  Future<void> signOut() async {
    if (onBeforeSignOut != null) {
      try {
        await onBeforeSignOut!();
      } catch (_) {
        // Token cleanup is best-effort; never block sign-out.
      }
    }
    try {
      await _google.signOut();
    } catch (_) {
      // Not signed in with Google — nothing to do.
    }
    await _supabase.auth.signOut();
  }
}
