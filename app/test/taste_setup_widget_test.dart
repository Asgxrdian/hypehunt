import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hyperhunt/features/onboarding/presentation/taste_setup_screen.dart';
import 'package:hyperhunt/features/profile/data/supabase_profile_repository.dart';

import 'fakes.dart';

void main() {
  late FakeProfileRepository fake;

  Widget harness() {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const TasteSetupScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('HOME', key: ValueKey('home'))),
        ),
      ],
    );
    return ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  setUp(() => fake = FakeProfileRepository());

  testWidgets('chips toggle on and off', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final actionChip = find.byKey(const ValueKey('chip-action'));
    expect(tester.widget<FilterChip>(actionChip).selected, isFalse);

    await tester.tap(actionChip);
    await tester.pump();
    expect(tester.widget<FilterChip>(actionChip).selected, isTrue);

    await tester.tap(actionChip);
    await tester.pump();
    expect(tester.widget<FilterChip>(actionChip).selected, isFalse);
  });

  testWidgets('skip navigates home without writing preferences',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('skip-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home')), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('finish saves exactly the tapped slugs then navigates home',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chip-action')));
    await tester.tap(find.byKey(const ValueKey('chip-indie')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('primary-button'))); // Continue
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chip-pc')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('primary-button'))); // Finish
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home')), findsOneWidget);
    expect(fake.calls, hasLength(1));
    expect(fake.calls.single, contains('action'));
    expect(fake.calls.single, contains('indie'));
    expect(fake.calls.single, contains('pc'));
  });
}
