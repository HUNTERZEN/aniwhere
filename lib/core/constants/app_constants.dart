/// Application-wide constants for Aniwhere

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Aniwhere';
  static const String appTagline = 'Watch and read anime, manga, anywhere.';
  static const String appVersion = '1.0.0';

  // API Endpoints
  static const String mangaDexBaseUrl = 'https://api.mangadex.org';
  static const String aniListBaseUrl = 'https://graphql.anilist.co';
  static const String malBaseUrl = 'https://api.myanimelist.net/v2';
  static const String kitsuBaseUrl = 'https://kitsu.io/api/edge';

  // Cache & Storage
  static const int maxCacheSize = 100; // MB
  static const Duration cacheExpiry = Duration(days: 7);

  // UI
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Reader Defaults
  static const double defaultZoom = 1.0;
  static const double minZoom = 0.5;
  static const double maxZoom = 3.0;

  // Player Defaults
  static const double defaultPlaybackSpeed = 1.0;
  static const int skipIntroSeconds = 85;
  static const int skipOutroSeconds = 90;
}
