import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/library/library_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/reader/reader_providers.dart';
import '../../features/player/player_screen.dart';
import '../../features/player/player_providers.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/tracker_settings_screen.dart';
import '../../ui/screens/home_screen.dart';
import '../../data/sources/source.dart';
import '../../features/browse/source_browse_screen.dart';
import '../../features/details/media_detail_screen.dart';

/// Application router configuration using go_router
class AppRouter {
  AppRouter._();

  // Navigation keys for nested navigation
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'shell');

  // Route paths
  static const String home = '/';
  static const String library = '/library';
  static const String browse = '/browse';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String trackerSettings = '/settings/trackers';
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
        navigatorKey: shellNavigatorKey,
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
          final params = state.extra as PlayerParams?;
          if (params == null) {
            return const Scaffold(
              body: Center(child: Text('Error: No player params provided')),
            );
          }
          return PlayerScreen(params: params);
        },
      ),
      GoRoute(
        path: trackerSettings,
        name: 'tracker_settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TrackerSettingsScreen(),
      ),
      GoRoute(
        path: '/source_browse/:id',
        name: 'source_browse',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final source = state.extra as Source?;
          if (source == null) {
            return const Scaffold(body: Center(child: Text('Error: No source provided')));
          }
          return SourceBrowseScreen(source: source);
        },
      ),
      GoRoute(
        path: details,
        name: 'details',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          // Decode the media ID (may be URL-encoded if it contains slashes)
          final encodedId = state.pathParameters['id']!;
          final mediaId = Uri.decodeComponent(encodedId);
          Source? source;
          SourceMedia? initialMedia;
          
          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra as Map<String, dynamic>;
            source = extra['source'] as Source?;
            initialMedia = extra['initialMedia'] as SourceMedia?;
          } else if (state.extra is Source) {
            source = state.extra as Source?;
          }
          
          if (source == null) {
            return const Scaffold(body: Center(child: Text('Error: No source provided')));
          }
          return MediaDetailScreen(
            mediaId: mediaId,
            source: source,
            initialMedia: initialMedia,
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
