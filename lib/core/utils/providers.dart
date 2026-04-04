import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../data/sources/database_service.dart';

// ============================================================================
// Database Providers
// ============================================================================

/// Provides the Isar database instance
final databaseProvider = FutureProvider<Isar>((ref) async {
  return DatabaseService.instance;
});

// ============================================================================
// Repository Providers
// ============================================================================

/// Provides the library repository
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

/// Provides the settings repository
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Provides the category repository
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

/// Provides the chapter repository
final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  final libraryRepo = ref.read(libraryRepositoryProvider);
  
  return ChapterRepository(
    onSync: (entrySourceId, progress, isConsumed) async {
      // Update the library entry's progress when chapters are read
      await libraryRepo.updateProgress(entrySourceId, progress, null);
    },
  );
});

/// Provides the search history repository
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((ref) {
  return SearchHistoryRepository();
});

/// Provides the backup repository
final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository();
});

// ============================================================================
// Library Providers
// ============================================================================

/// Provides all library entries as a stream
final libraryEntriesProvider = StreamProvider<List<LibraryEntry>>((ref) {
  final repository = ref.watch(libraryRepositoryProvider);
  return repository.watchAll();
});

/// Provides library entries filtered by category
final libraryByCategoryProvider =
    FutureProvider.family<List<LibraryEntry>, String?>((ref, category) async {
  final entries = await ref.watch(libraryEntriesProvider.future);
  if (category == null || category.isEmpty) {
    return entries;
  }
  return entries.where((e) => e.categories.contains(category)).toList();
});

/// Provides favorite entries only
final favoritesProvider = FutureProvider<List<LibraryEntry>>((ref) async {
  final repository = ref.watch(libraryRepositoryProvider);
  return repository.getFavorites();
});

// ============================================================================
// Settings Providers
// ============================================================================

/// Provides app settings as a stream
final settingsProvider = StreamProvider<AppSettings?>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.watchSettings();
});

/// Provides the current theme mode
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.when(
    data: (settings) => settings?.themeMode ?? ThemeMode.system,
    loading: () => ThemeMode.system,
    error: (_, __) => ThemeMode.system,
  );
});

/// Notifier for managing theme state
class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _repository;

  ThemeNotifier(this._repository) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settings = await _repository.getSettings();
    state = settings.themeMode;
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await _repository.updateSetting((s) => s.themeMode = mode);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }
}

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return ThemeNotifier(repository);
});

// ============================================================================
// Navigation Providers
// ============================================================================

/// Current navigation index for bottom nav
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// ============================================================================
// Search Providers
// ============================================================================

/// Search query state
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search results for library
final librarySearchProvider =
    FutureProvider.family<List<LibraryEntry>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(libraryRepositoryProvider);
  return repository.search(query);
});

// ============================================================================
// Library Display Providers
// ============================================================================

/// Current library display mode (grid/list)
final libraryDisplayModeProvider = StateProvider<LibraryDisplayMode>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.when(
    data: (settings) => settings?.libraryDisplayMode ?? LibraryDisplayMode.grid,
    loading: () => LibraryDisplayMode.grid,
    error: (_, __) => LibraryDisplayMode.grid,
  );
});

/// Current library sort mode
final librarySortModeProvider = StateProvider<LibrarySortMode>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.when(
    data: (settings) => settings?.librarySortMode ?? LibrarySortMode.alphabetical,
    loading: () => LibrarySortMode.alphabetical,
    error: (_, __) => LibrarySortMode.alphabetical,
  );
});

// ============================================================================
// Category Providers
// ============================================================================

/// Provides all categories as a stream
final categoriesProvider = StreamProvider<List<LibraryCategory>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.watchAll();
});

/// Provides a single category by ID
final categoryByIdProvider = FutureProvider.family<LibraryCategory?, int>((ref, id) async {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.getCategoryById(id);
});

/// Current selected category for filtering
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
