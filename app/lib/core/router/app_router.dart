import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/onboarding/presentation/taste_setup_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// Auth-aware router (M1 spec §4). Unauthenticated users can only reach
/// Welcome and /auth/*; authenticated users can never navigate back to
/// them. Onboarding is offered once after sign-up — never a locked gate.
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<bool>(
    ref.read(authRepositoryProvider).currentUser != null,
  );
  ref
    ..onDispose(authListenable.dispose)
    ..listen(authStateChangesProvider, (_, next) {
      authListenable.value = next.valueOrNull != null;
    });

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final loggedIn = authListenable.value;
      final location = state.matchedLocation;
      final onAuthSurface =
          location == '/welcome' || location.startsWith('/auth');

      if (!loggedIn && !onAuthSurface) return '/welcome';
      if (loggedIn && onAuthSurface) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/auth/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const TasteSetupScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const TasteSetupScreen(isEditing: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HyperShell(shell: shell),
        branches: [
          _tab('/home', 'Home', 'What should I check out today?'),
          _tab('/search', 'Search', 'Find any game, fast.'),
          _tab('/deals', 'Deals', 'What is worth buying right now?'),
          _tab('/wishlist', 'Wishlist', 'Is anything I want on sale?'),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

StatefulShellBranch _tab(String path, String title, String question) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) =>
            _PlaceholderScreen(title: title, question: question),
      ),
    ],
  );
}

class _HyperShell extends StatelessWidget {
  const _HyperShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            label: 'Deals',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.question});
  final String title;
  final String question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            question,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
