import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// M0 navigation shell: five tabs matching the Constitution's MVP
/// surfaces. Each placeholder answers exactly one question — even
/// the placeholders follow the design philosophy.
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _HyperShell(shell: shell),
      branches: [
        _tab('/home', 'Home', 'What should I check out today?'),
        _tab('/search', 'Search', 'Find any game, fast.'),
        _tab('/deals', 'Deals', 'What is worth buying right now?'),
        _tab('/wishlist', 'Wishlist', 'Is anything I want on sale?'),
        _tab('/profile', 'Profile', 'My tastes, my alerts, my account.'),
      ],
    ),
  ],
);

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
