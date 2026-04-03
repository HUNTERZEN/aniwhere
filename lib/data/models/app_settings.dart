import 'package:isar/isar.dart';

part 'app_settings.g.dart';

/// Application settings stored in Isar
@collection
class AppSettings {
  Id id = 0; // Single settings instance

  // Theme Settings
  @Enumerated(EnumType.name)
  ThemeMode themeMode = ThemeMode.system;

  bool usePureBlack = true;

  // Reader Settings
  @Enumerated(EnumType.name)
  ReadingDirection readingDirection = ReadingDirection.leftToRight;

  @Enumerated(EnumType.name)
  ReaderMode readerMode = ReaderMode.paged;

  bool showPageNumber = true;
  bool keepScreenOn = true;
  double defaultZoom = 1.0;
  int pageGap = 0;

  @Enumerated(EnumType.name)
  ReaderBackground readerBackground = ReaderBackground.black;

  // Player Settings
  double defaultPlaybackSpeed = 1.0;
  bool autoPlayNext = true;
  int skipIntroSeconds = 85;
  int skipOutroSeconds = 90;
  bool rememberPlaybackSpeed = true;
  bool hardwareAcceleration = true;

  // Library Settings
  @Enumerated(EnumType.name)
  LibraryDisplayMode libraryDisplayMode = LibraryDisplayMode.grid;

  @Enumerated(EnumType.name)
  LibrarySortMode librarySortMode = LibrarySortMode.alphabetical;

  bool librarySortDescending = false;
  bool showUnreadBadge = true;
  bool showDownloadBadge = true;

  // Browse/API Settings
  bool showNsfwContent = false;
  List<String> enabledSources = [];
  
  @Enumerated(EnumType.name)
  AnimeAudioPreference animeAudioPreference = AnimeAudioPreference.sub;
  
  String consumetApiUrl = 'https://consumet-api-clone.vercel.app/anime/gogoanime';

  // Download Settings
  String? downloadPath;
  int maxConcurrentDownloads = 3;
  bool downloadOnlyOnWifi = true;

  // Tracker Settings
  bool syncProgressAutomatically = true;
  
  // Notification Settings
  bool notifyOnUpdate = true;
  bool notifyOnDownloadComplete = true;

  // Cache Settings
  int imageCacheSizeMb = 100;
  int clearCacheAfterDays = 7;
}

enum ThemeMode {
  system,
  light,
  dark,
}

enum ReadingDirection {
  leftToRight,
  rightToLeft,
  vertical,
  webtoon,
}

enum ReaderMode {
  paged,
  continuous,
  webtoon,
}

enum ReaderBackground {
  white,
  black,
  gray,
  sepia,
}

enum LibraryDisplayMode {
  grid,
  list,
  compactGrid,
}

enum LibrarySortMode {
  alphabetical,
  lastRead,
  lastUpdated,
  dateAdded,
  unreadCount,
  totalChapters,
}

enum AnimeAudioPreference {
  sub,
  dub,
}
