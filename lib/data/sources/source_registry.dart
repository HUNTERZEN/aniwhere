import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source.dart';
import 'mangapill_source.dart';
import 'aniwatch_source.dart';
import '../extensions/extension_model.dart';
import '../extensions/extension_source.dart';
import '../extensions/extension_repository.dart';

/// Registry of all available sources
class SourceRegistry {
  final Map<String, Source> _sources = {};
  final Map<String, ExtensionSource> _extensionSources = {};
  final ExtensionRepository _extensionRepo;

  SourceRegistry(this._extensionRepo) {
    // Register built-in sources
    _registerBuiltInSources();
  }

  void _registerBuiltInSources() {
    // MangaPill - Default manga source (English)
    register(MangaPillSource());
    
    // Aniwatch - Default anime source with English subtitles
    register(AniwatchSource());
  }

  /// Load extensions from storage
  Future<void> loadExtensions() async {
    final extensions = await _extensionRepo.getInstalledExtensions();
    for (final ext in extensions) {
      if (ext.isEnabled) {
        await registerExtension(ext);
      }
    }
  }

  /// Register a new source
  void register(Source source) {
    _sources[source.id] = source;
  }

  /// Register an extension source
  Future<void> registerExtension(LoadedExtension extension) async {
    final source = ExtensionSource(extension);
    try {
      await source.initialize();
      _extensionSources[extension.metadata.id] = source;
      _sources[extension.metadata.id] = source;
    } catch (e) {
      // Extension failed to load, skip it
      source.dispose();
    }
  }

  /// Unregister a source
  void unregister(String sourceId) {
    _sources.remove(sourceId);
    final extSource = _extensionSources.remove(sourceId);
    extSource?.dispose();
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

  /// Get built-in sources only
  List<Source> get builtInSources {
    return _sources.values
        .where((s) => !_extensionSources.containsKey(s.id))
        .toList();
  }

  /// Get extension sources only
  List<ExtensionSource> get extensionSources => _extensionSources.values.toList();

  /// Check if source is an extension
  bool isExtension(String sourceId) => _extensionSources.containsKey(sourceId);
}

/// Provider for the source registry
final sourceRegistryProvider = Provider<SourceRegistry>((ref) {
  final extensionRepo = ref.watch(extensionRepositoryProvider);
  final registry = SourceRegistry(extensionRepo);
  // Load extensions asynchronously
  registry.loadExtensions();
  return registry;
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

/// Provider for default manga source (MangaPill)
final defaultMangaSourceProvider = Provider<Source?>((ref) {
  final sources = ref.watch(mangaSourcesProvider);
  return sources.isNotEmpty ? sources.first : null;
});

/// Provider for default anime source (AniWatch)
final defaultAnimeSourceProvider = Provider<Source?>((ref) {
  final sources = ref.watch(animeSourcesProvider);
  return sources.isNotEmpty ? sources.first : null;
});
