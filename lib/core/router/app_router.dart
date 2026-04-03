import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/library_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/reader/reader_providers.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../ui/screens/home_screen.dart';

/// Application router configuration using go_router
class AppRouter {
  AppRouter._();

  // Navigation keys for nested navigation
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  // Route paths
  static const String home = '/';
  static const String library = '/library';
  static const String browse = '/browse';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String reader = '/reader/:id';
  static const String player = '/player/:id';
  static const String details = '/details/:type/:id';

  // Router configuration
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: home,
    debugLogDiagnostics: true,
    routes: [
      // Shell route for bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: home,
            name: 'library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: browse,
            name: 'browse',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BrowseScreen(),
            ),
          ),
          GoRoute(
            path: search,
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: settings,
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      // Full-screen routes (outside shell)
      GoRoute(
        path: reader,
        name: 'reader',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          // ReaderParams must be passed via state.extra
          final params = state.extra as ReaderParams?;
          if (params == null) {
            return const Scaffold(
              body: Center(child: Text('Error: No reader params provided')),
            );
          }
          return ReaderScreen(params: params);
        },
      ),
      GoRoute(
        path: player,
        name: 'player',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          // TODO: Implement PlayerScreen in Phase 5
          return Scaffold(
            appBar: AppBar(title: Text('Player: $id')),
            body: const Center(child: Text('Player coming in Phase 5')),
          );
        },
      ),
      GoRoute(
        path: details,
        name: 'details',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final type = state.pathParameters['type']!;
          final id = state.pathParameters['id']!;
          // TODO: Implement DetailsScreen
          return Scaffold(
            appBar: AppBar(title: Text('$type: $id')),
            body: const Center(child: Text('Details screen')),
          );
        },
      ),
    ],
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
