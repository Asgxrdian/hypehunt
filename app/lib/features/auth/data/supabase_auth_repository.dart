import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

final authStateChangesProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(id: user.id, email: user.email ?? '');
  }

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() async* {
    // Seed with the persisted session so the router never flickers
    // through Welcome for an already-signed-in user (M1 spec §4).
    yield currentUser;
    yield* _client.auth.onAuthStateChange
        .map((event) => _toAppUser(event.session?.user));
  }

  @override
  Future<void> signUp({required String email, required String password}) =>
      _guard(() async {
        final response =
            await _client.auth.signUp(email: email, password: password);
        // Supabase does NOT throw when email confirmation is pending —
        // it returns a user with a NULL session. M1 treats sign-up as
        // successful only when a live session comes back (founder
        // decision, M1): never navigate into the app unauthenticated.
        if (response.session == null) {
          throw const AuthFailure(
            'Your account was created, but we couldn\'t sign you in '
            'automatically. If you received a confirmation email, confirm '
            'it and then sign in.',
          );
        }
      });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _client.auth
            .signInWithPassword(email: email, password: password),
      );

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email));

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _guard(() async {
        await _client.auth.verifyOTP(
          email: email,
          token: code,
          type: OtpType.recovery,
        );
        await _client.auth.updateUser(UserAttributes(password: newPassword));
      });

  /// Runs [action], translating SDK exceptions into user-safe
  /// [AuthFailure]s. Raw messages never reach the UI. Domain failures
  /// thrown inside pass through untouched.
  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (_) {
      throw const AuthFailure(
        'Something went wrong. Check your connection and try again.',
      );
    }
  }

  String _friendlyMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Email or password is incorrect';
    }
    if (m.contains('already registered')) {
      return 'An account with that email already exists';
    }
    if (m.contains('expired') ||
        m.contains('invalid token') ||
        m.contains('otp')) {
      return 'That code is invalid or has expired. Request a new one.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (m.contains('password')) {
      return 'Passwords need at least 8 characters';
    }
    return 'Something went wrong. Please try again.';
  }
}