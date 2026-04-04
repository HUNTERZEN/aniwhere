import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source.dart';
import 'mangadex_source.dart';
import 'mangapill_source.dart';
import 'gogoanime_source.dart';

/// Registry of all available sources
class SourceRegistry {
  final Map<String, Source> _sources = {};

  SourceRegistry() {
    // Register built-in sources
    _registerBuiltInSources();
  }

  void _registerBuiltInSources() {
    // MangaDex - Manga source (English translations)
    register(MangaDexSource());
    
    // MangaPill - Manga source (English)
    register(MangaPillSource());
    
    // Gogoanime - Anime source
    register(GogoanimeSource());
  }

  /// Register a new source
  void register(Source source) {
    _sources[source.id] = source;
  }

  /// Unregister a source
  void unregister(String sourceId) {
    _sources.remove(sourceId);
  }

  /// Get a source by ID
  Source? getSource(String id) => _sources[id];

  /// Get all registered sources
  List<Source> get allSources => _sources.values.toList();

  /// Get sources by content type
  List<Source> getSourcesByType(SourceContentType type) {
    return _sources.values.where((s) => s.contentType == type).toList();
  }

  /// Get manga sources
  List<Source> get mangaSources => getSourcesByType(SourceContentType.manga);

  /// Get anime sources
  List<Source> get animeSources => getSourcesByType(SourceContentType.anime);

  /// Get novel sources
  List<Source> get novelSources => getSourcesByType(SourceContentType.novel);
}

/// Provider for the source registry
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  return SourceRegistry();
});

/// Provider for all sources
final allSourcesProvider = Provider<List<Source>>((ref) {
  return ref.watch(sourceRegistryProvider).allSources;
});

/// Provider for manga sources
final mangaSourcesProvider = Provider<List<Source>>((ref) {
  return ref.watch(sourceRegistryProvider).mangaSources;
});

/// Provider for anime sources
final animeSourcesProvider = Provider<List<Source>>((ref) {
  return ref.watch(sourceRegistryProvider).animeSources;
});

/// Provider for a specific source by ID
final sourceByIdProvider = Provider.family<Source?, String>((ref, id) {
  return ref.watch(sourceRegistryProvider).getSource(id);
});
