import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_auth_repository.dart';
import '../domain/auth_failure.dart';

/// Drives every auth form. State is AsyncValue<void>: loading while a
/// request runs, error carrying an [AuthFailure] message, data on rest.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } on AuthFailure catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> signUp(String email, String password) =>
      _run(() => ref.read(authRepositoryProvider).signUp(
            email: email.trim(),
            password: password,
          ));

  Future<bool> signIn(String email, String password) =>
      _run(() => ref.read(authRepositoryProvider).signIn(
            email: email.trim(),
            password: password,
          ));

  Future<bool> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  Future<bool> requestPasswordReset(String email) => _run(
      () => ref.read(authRepositoryProvider).requestPasswordReset(email.trim()));

  Future<bool> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _run(() => ref.read(authRepositoryProvider).confirmPasswordReset(
            email: email.trim(),
            code: code.trim(),
            newPassword: newPassword,
          ));
}

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(
  AuthController.new,
);
