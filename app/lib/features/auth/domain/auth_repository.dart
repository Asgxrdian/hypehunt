import 'app_user.dart';

/// Contract for authentication. Presentation depends on this interface;
/// the Supabase implementation lives in the data layer (Bible §7).
abstract interface class AuthRepository {
  /// Emits the current user immediately, then on every auth change.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<void> signUp({required String email, required String password});

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Sends the 6-digit recovery code email (M1 spec D2).
  Future<void> requestPasswordReset(String email);

  /// Verifies the code and sets the new password.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
