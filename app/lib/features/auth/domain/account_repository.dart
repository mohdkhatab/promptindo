/// Account-level operations that need Cloud Functions or full teardown:
/// deleting the signed-in user's own account.
abstract interface class AccountRepository {
  /// Calls the `deleteUserAccount` callable: removes Firestore docs, Storage
  /// objects and the Auth user (re-auth may be required first).
  Future<void> deleteMyAccount();
}
