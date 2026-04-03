import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/source.dart';
import '../../data/sources/source_registry.dart';
import '../../data/models/search_history.dart';
import '../../core/utils/providers.dart';

/// Provider for search filter constraint
final searchFilterProvider = StateProvider<SourceContentType?>((ref) => null);

/// Represents a combined search result spanning multiple sources
class GlobalSearchResult {
  final Source source;
  final SourcePaginatedResult<SourceMedia> result;

  const GlobalSearchResult({
    required this.source,
    required this.result,
  });
}

/// Provider that performs the global search across all active sources
final globalSearchProvider = FutureProvider.autoDispose<List<GlobalSearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final filter = ref.watch(searchFilterProvider);
  
  if (query.isEmpty) {
    return [];
  }

  // Get all sources, constrained by the filter if one is active
  final sourceRegistry = ref.watch(sourceRegistryProvider);
  final sources = filter != null 
      ? sourceRegistry.getSourcesByType(filter)
      : sourceRegistry.allSources;

  if (sources.isEmpty) {
    return [];
  }

  // Save successful query to history
  ref.read(searchHistoryRepositoryProvider).addQuery(query);

  // Dispatch search to all sources concurrently
  // Use Future.wait to parallelize network I/O
  final results = await Future.wait(
    sources.map((source) async {
      try {
        final result = await source.search(query, 1); // Only fetch first page for global search
        if (result.items.isNotEmpty) {
          return GlobalSearchResult(source: source, result: result);
        }
      } catch (e) {
        // Silently ignore individual source failures during global search
        print('Error searching on ${source.name}: $e');
      }
      return null;
    }),
  );

  // Filter out nulls and empty results
  return results.whereType<GlobalSearchResult>().toList();
});

/// Provider indicating if global search is currently loading
final isGlobalSearchLoadingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(globalSearchProvider).isLoading;
});

/// Stream provider for recent searches
final recentSearchesProvider = StreamProvider.autoDispose<List<SearchHistoryEntry>>((ref) {
  final repository = ref.watch(searchHistoryRepositoryProvider);
  return repository.watchRecentSearches();
});
