import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperhunt/features/auth/data/supabase_auth_repository.dart';
import 'package:hyperhunt/features/auth/presentation/auth_controller.dart';

import 'fakes.dart';

void main() {
  late FakeAuthRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  test('signIn success: loading -> data, returns true', () async {
    final controller = container.read(authControllerProvider.notifier);
    final result = controller.signIn('a@test.dev', 'password123');
    expect(container.read(authControllerProvider).isLoading, isTrue);
    expect(await result, isTrue);
    expect(container.read(authControllerProvider).hasError, isFalse);
    expect(fake.calls, contains('signIn:a@test.dev'));
  });

  test('signIn failure: error state carries the friendly message', () async {
    fake.failNext = true;
    final controller = container.read(authControllerProvider.notifier);
    final ok = await controller.signIn('a@test.dev', 'wrong');
    expect(ok, isFalse);
    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error.toString(), 'Email or password is incorrect');
  });

  test('signUp trims the email before hitting the repository', () async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.signUp('  new@test.dev  ', 'password123');
    expect(fake.calls, contains('signUp:new@test.dev'));
  });

  test('confirmPasswordReset passes trimmed code through', () async {
    final controller = container.read(authControllerProvider.notifier);
    final ok = await controller.confirmPasswordReset(
      email: 'a@test.dev',
      code: ' 123456 ',
      newPassword: 'newpassword1',
    );
    expect(ok, isTrue);
    expect(fake.calls, contains('confirmReset:a@test.dev:123456'));
  });
}
