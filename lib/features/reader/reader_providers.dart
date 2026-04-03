import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/chapter.dart';
import '../../data/repositories/chapter_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/sources/source.dart';
import '../../core/utils/providers.dart';

// ============================================================================
// Reader Data Providers
// ============================================================================

/// Parameters needed to open the reader
class ReaderParams {
  final Source source;
  final String mediaId;
  final String chapterId;
  final List<SourceChapter> chapters;
  final int initialChapterIndex;

  const ReaderParams({
    required this.source,
    required this.mediaId,
    required this.chapterId,
    required this.chapters,
    required this.initialChapterIndex,
  });

  /// The source ID used for Isar storage: "sourceName:mediaId"
  String get entrySourceId => '${source.id}:$mediaId';
}

/// Provides pages for a given chapter from the source
final readerPagesProvider = FutureProvider.family<List<SourcePage>, (Source, String)>(
  (ref, params) async {
    final (source, chapterId) = params;
    if (source is ReadableSource) {
      return source.getPages(chapterId);
    }
    throw Exception('Source ${source.id} is not a readable source');
  },
);

/// Provides stored chapter progress from Isar
final chapterProgressProvider = FutureProvider.family<Chapter?, (String, String)>(
  (ref, params) async {
    final (entrySourceId, chapterId) = params;
    final repo = ref.watch(chapterRepositoryProvider);
    return repo.getChapter(entrySourceId, chapterId);
  },
);

/// Provides current reader settings from AppSettings
final readerSettingsProvider = Provider<ReaderSettings>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.when(
    data: (settings) {
      if (settings == null) return const ReaderSettings();
      return ReaderSettings(
        readingDirection: settings.readingDirection,
        readerMode: settings.readerMode,
        showPageNumber: settings.showPageNumber,
        keepScreenOn: settings.keepScreenOn,
        defaultZoom: settings.defaultZoom,
        pageGap: settings.pageGap,
        readerBackground: settings.readerBackground,
      );
    },
    loading: () => const ReaderSettings(),
    error: (_, __) => const ReaderSettings(),
  );
});

/// Immutable reader settings snapshot
class ReaderSettings {
  final ReadingDirection readingDirection;
  final ReaderMode readerMode;
  final bool showPageNumber;
  final bool keepScreenOn;
  final double defaultZoom;
  final int pageGap;
  final ReaderBackground readerBackground;

  const ReaderSettings({
    this.readingDirection = ReadingDirection.leftToRight,
    this.readerMode = ReaderMode.paged,
    this.showPageNumber = true,
    this.keepScreenOn = true,
    this.defaultZoom = 1.0,
    this.pageGap = 0,
    this.readerBackground = ReaderBackground.black,
  });
}

// ============================================================================
// Reader State Notifier
// ============================================================================

/// In-memory state for the active reading session
class ReaderState {
  final int currentPage;
  final int totalPages;
  final bool showControls;
  final bool isLoading;
  final String? error;
  final int currentChapterIndex;
  final ReadingDirection readingDirection;
  final ReaderMode readerMode;
  final ReaderBackground background;
  final int pageGap;
  final double zoom;
  final bool showPageNumber;

  const ReaderState({
    this.currentPage = 0,
    this.totalPages = 0,
    this.showControls = true,
    this.isLoading = true,
    this.error,
    this.currentChapterIndex = 0,
    this.readingDirection = ReadingDirection.leftToRight,
    this.readerMode = ReaderMode.paged,
    this.background = ReaderBackground.black,
    this.pageGap = 0,
    this.zoom = 1.0,
    this.showPageNumber = true,
  });

  ReaderState copyWith({
    int? currentPage,
    int? totalPages,
    bool? showControls,
    bool? isLoading,
    String? error,
    int? currentChapterIndex,
    ReadingDirection? readingDirection,
    ReaderMode? readerMode,
    ReaderBackground? background,
    int? pageGap,
    double? zoom,
    bool? showPageNumber,
  }) {
    return ReaderState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      showControls: showControls ?? this.showControls,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      readingDirection: readingDirection ?? this.readingDirection,
      readerMode: readerMode ?? this.readerMode,
      background: background ?? this.background,
      pageGap: pageGap ?? this.pageGap,
      zoom: zoom ?? this.zoom,
      showPageNumber: showPageNumber ?? this.showPageNumber,
    );
  }
}

/// State notifier for the reader
class ReaderStateNotifier extends StateNotifier<ReaderState> {
  final ChapterRepository _chapterRepo;
  final SettingsRepository _settingsRepo;
  final ReaderParams params;

  ReaderStateNotifier({
    required this.params,
    required ChapterRepository chapterRepo,
    required SettingsRepository settingsRepo,
    required ReaderSettings initialSettings,
  })  : _chapterRepo = chapterRepo,
        _settingsRepo = settingsRepo,
        super(ReaderState(
          currentChapterIndex: params.initialChapterIndex,
          readingDirection: initialSettings.readingDirection,
          readerMode: initialSettings.readerMode,
          background: initialSettings.readerBackground,
          pageGap: initialSettings.pageGap,
          zoom: initialSettings.defaultZoom,
          showPageNumber: initialSettings.showPageNumber,
        ));

  /// Public accessor for the current reader state
  ReaderState get currentState => state;


  /// Set the page count once pages are loaded
  void setPagesLoaded(int totalPages) {
    state = state.copyWith(totalPages: totalPages, isLoading: false);
  }

  /// Set a loading error
  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Navigate to a specific page
  void goToPage(int page) {
    if (page < 0 || page >= state.totalPages) return;
    state = state.copyWith(currentPage: page);
    _saveProgress();
  }

  /// Toggle controls visibility
  void toggleControls() {
    final show = !state.showControls;
    state = state.copyWith(showControls: show);
    // Toggle system UI overlays
    if (show) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// Show controls explicitly
  void showControls() {
    if (!state.showControls) {
      state = state.copyWith(showControls: true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Update reading direction
  void setReadingDirection(ReadingDirection direction) {
    state = state.copyWith(readingDirection: direction);
    _persistSetting((s) => s.readingDirection = direction);
  }

  /// Update reader mode
  void setReaderMode(ReaderMode mode) {
    state = state.copyWith(readerMode: mode);
    _persistSetting((s) => s.readerMode = mode);
  }

  /// Update background color
  void setBackground(ReaderBackground bg) {
    state = state.copyWith(background: bg);
    _persistSetting((s) => s.readerBackground = bg);
  }

  /// Update page gap
  void setPageGap(int gap) {
    state = state.copyWith(pageGap: gap);
    _persistSetting((s) => s.pageGap = gap);
  }

  /// Update zoom level
  void setZoom(double zoom) {
    state = state.copyWith(zoom: zoom);
    _persistSetting((s) => s.defaultZoom = zoom);
  }

  /// Toggle page number display
  void togglePageNumber() {
    final show = !state.showPageNumber;
    state = state.copyWith(showPageNumber: show);
    _persistSetting((s) => s.showPageNumber = show);
  }

  /// Move to next chapter
  bool canGoNextChapter() {
    return state.currentChapterIndex > 0;
  }

  /// Move to previous chapter
  bool canGoPrevChapter() {
    return state.currentChapterIndex < params.chapters.length - 1;
  }

  /// Get the next chapter (chapters are in descending order, so going
  /// "forward" in reading means decreasing index)
  SourceChapter? getNextChapter() {
    if (!canGoNextChapter()) return null;
    return params.chapters[state.currentChapterIndex - 1];
  }

  /// Get the previous chapter
  SourceChapter? getPrevChapter() {
    if (!canGoPrevChapter()) return null;
    return params.chapters[state.currentChapterIndex + 1];
  }

  /// Start loading a new chapter (resets page state)
  void switchChapter(int newIndex) {
    state = state.copyWith(
      currentChapterIndex: newIndex,
      currentPage: 0,
      totalPages: 0,
      isLoading: true,
      error: null,
    );
  }

  /// Restore saved progress for current chapter
  Future<void> restoreProgress() async {
    final currentChapter = params.chapters[state.currentChapterIndex];
    final stored = await _chapterRepo.getChapter(
      params.entrySourceId,
      currentChapter.id,
    );
    if (stored != null && stored.progress > 0) {
      state = state.copyWith(currentPage: stored.progress);
    }
  }

  /// Save current reading progress to Isar
  Future<void> _saveProgress() async {
    if (state.totalPages == 0) return;
    final currentChapter = params.chapters[state.currentChapterIndex];
    try {
      await _chapterRepo.saveProgress(
        entrySourceId: params.entrySourceId,
        chapterId: currentChapter.id,
        currentPage: state.currentPage,
        totalPages: state.totalPages,
        title: currentChapter.title,
        number: currentChapter.number,
      );
    } catch (e) {
      // Silently fail — don't disrupt reading experience
    }
  }

  /// Force-save progress (e.g. on dispose)
  Future<void> saveProgressNow() async {
    await _saveProgress();
  }

  /// Persist a reader setting to Isar
  Future<void> _persistSetting(void Function(AppSettings) updater) async {
    try {
      await _settingsRepo.updateSetting(updater);
    } catch (e) {
      // Silently fail
    }
  }
}

/// Provider for the reader state notifier, scoped per reader session
final readerStateProvider =
    StateNotifierProvider.autoDispose<ReaderStateNotifier, ReaderState>(
  (ref) {
    // This provider must be overridden with proper params when used
    throw UnimplementedError(
      'readerStateProvider must be overridden with ReaderParams',
    );
  },
);
