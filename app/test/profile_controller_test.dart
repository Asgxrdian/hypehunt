import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperhunt/features/profile/data/supabase_profile_repository.dart';
import 'package:hyperhunt/features/profile/presentation/profile_controller.dart';

import 'fakes.dart';

void main() {
  late FakeProfileRepository fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeProfileRepository();
    container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  test('build loads profile and preferences together', () async {
    final data = await container.read(profileControllerProvider.future);
    expect(data.profile.email, 'a@test.dev');
    expect(data.preferences.isEmpty, isTrue);
  });

  test('savePreferences writes exactly the selected slugs', () async {
    await container.read(profileControllerProvider.future);
    final ok = await container
        .read(profileControllerProvider.notifier)
        .savePreferences(
      favoriteGenres: ['action', 'indie'],
      favoritePlatforms: ['pc'],
    );
    expect(ok, isTrue);
    expect(fake.calls, contains('updatePreferences:action,indie|pc'));
    final state = container.read(profileControllerProvider).value!;
    expect(state.preferences.favoriteGenres, ['action', 'indie']);
  });

  test('savePreferences failure restores previous data (no stranding)',
      () async {
    await container.read(profileControllerProvider.future);
    fake.failNext = true;
    final ok = await container
        .read(profileControllerProvider.notifier)
        .savePreferences(favoriteGenres: ['action'], favoritePlatforms: []);
    expect(ok, isFalse);
    final state = container.read(profileControllerProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.preferences.isEmpty, isTrue);
  });

  test('saveUsername returns null on success and updates state', () async {
    await container.read(profileControllerProvider.future);
    final error = await container
        .read(profileControllerProvider.notifier)
        .saveUsername('phype');
    expect(error, isNull);
    expect(
      container.read(profileControllerProvider).value!.profile.username,
      'phype',
    );
  });
}
