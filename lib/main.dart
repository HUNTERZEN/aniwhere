import 'package:flutter/material.dart' as material show ThemeMode;
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:media_kit/media_kit.dart'; // Uncomment when media_kit is enabled

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/utils/providers.dart';
import 'data/models/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit for video playback (uncomment when enabled)
  // MediaKit.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: AniwhereApp(),
    ),
  );
}

/// Root application widget for Aniwhere
class AniwhereApp extends ConsumerWidget {
  const AniwhereApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);

    return MaterialApp.router(
      title: 'Aniwhere',
      debugShowCheckedModeBanner: false,
      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _mapThemeMode(themeMode),
      // Router configuration
      routerConfig: AppRouter.router,
    );
  }

  /// Map our custom ThemeMode to Flutter's ThemeMode
  material.ThemeMode _mapThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return material.ThemeMode.light;
      case ThemeMode.dark:
        return material.ThemeMode.dark;
      case ThemeMode.system:
        return material.ThemeMode.system;
    }
  }
}
