/// Auth contract (domain layer). Screens never touch backend SDKs directly.
abstract interface class AuthRepository {
  /// Emits the signed-in uid (null when signed out). Emits current session
  /// first, then subsequent auth state changes.
  Stream<String?> authStateChanges();

  String? get currentUid;

  String? get currentEmail;

  bool get isEmailVerified;

  Future<String> signInWithEmail({
    required String email,
    required String password,
  });

  Future<String> registerWithEmail({
    required String email,
    required String password,
    required String name,
  });

  Future<String> signInWithGoogle();

  Future<void> sendVerificationEmail({String? email});

  Future<void> verifyEmailCode({required String email, required String code});

  Future<void> sendPasswordReset({required String email});

  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Refreshes the active session.
  Future<void> reload();

  Future<void> signOut();
}
