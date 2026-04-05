import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/providers.dart';

/// Home screen with bottom navigation shell
class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == AppRouter.home || location == AppRouter.library) {
      return 0;
    }
    if (location == AppRouter.browse) return 1;
    if (location == AppRouter.search) return 2;
    if (location == AppRouter.settings) return 3;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    // Close any open bottom sheets or dialogs on the shell navigator
    final shellNavigator = AppRouter.shellNavigatorKey.currentState;
    if (shellNavigator != null && shellNavigator.canPop()) {
      shellNavigator.pop();
    }

    switch (index) {
      case 0:
        context.go(AppRouter.home);
        break;
      case 1:
        context.go(AppRouter.browse);
        break;
      case 2:
        context.go(AppRouter.search);
        break;
      case 3:
        context.go(AppRouter.settings);
        break;
    }
  }
}
