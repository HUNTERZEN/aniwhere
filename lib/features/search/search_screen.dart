import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/providers.dart';
import '../../data/sources/source.dart';
import 'search_providers.dart';
import '../../ui/widgets/glass_app_bar.dart';

/// Global search screen for searching across all sources
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(searchFilterProvider);

    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Search'),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear History',
              onPressed: () {
                ref.read(searchHistoryRepositoryProvider).clearHistory();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search manga, anime, novels...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                // To avoid hammering sources on every keystroke, require pressing enter, 
                // OR we just dispatch state if we have debouncing in the provider logic.
                // For simplicity, we delay dispatching to search until submission, 
                // but the current text allows clearing. 
              },
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SearchFilterChip(
                  label: 'All',
                  isSelected: filter == null,
                  onTap: () => ref.read(searchFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                _SearchFilterChip(
                  label: 'Manga',
                  isSelected: filter == SourceContentType.manga,
                  onTap: () => ref.read(searchFilterProvider.notifier).state = SourceContentType.manga,
                ),
                const SizedBox(width: 8),
                _SearchFilterChip(
                  label: 'Anime',
                  isSelected: filter == SourceContentType.anime,
                  onTap: () => ref.read(searchFilterProvider.notifier).state = SourceContentType.anime,
                ),
                const SizedBox(width: 8),
                _SearchFilterChip(
                  label: 'Novel',
                  isSelected: filter == SourceContentType.novel,
                  onTap: () => ref.read(searchFilterProvider.notifier).state = SourceContentType.novel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Content Area
          Expanded(
            child: query.isEmpty
                ? _buildEmptyState(context)
                : _buildSearchResults(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final recentSearchesAsync = ref.watch(recentSearchesProvider);

    return recentSearchesAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 80,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Search across all sources',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find manga, anime, and novels',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: history.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Searches',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(searchHistoryRepositoryProvider).clearHistory();
                      },
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              );
            }

            final entry = history[index - 1];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(entry.query),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  ref.read(searchHistoryRepositoryProvider).deleteQuery(entry.query);
                },
              ),
              onTap: () {
                _searchController.text = entry.query;
                ref.read(searchQueryProvider.notifier).state = entry.query;
                // Move cursor to end
                _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchController.text.length));
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Failed to load history: $err')),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final searchAsync = ref.watch(globalSearchProvider);

    return searchAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: AppColors.textTertiaryDark),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final sourceResult = results[index];
            final items = sourceResult.result.items;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.source, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        sourceResult.source.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          items.length.toString(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, itemIndex) {
                      final item = items[itemIndex];
                      return SizedBox(
                        width: 120, // Fixed width for horizontal scroller cards
                        child: _SearchMediaCard(
                          media: item,
                          source: sourceResult.source,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text('Searching all sources...'),
          ],
        ),
      ),
      error: (err, _) => Center(child: Text('Search failed: $err')),
    );
  }
}

/// A compact media card for horizontal scroll views within the global search screen
class _SearchMediaCard extends StatelessWidget {
  final SourceMedia media;
  final Source source;

  const _SearchMediaCard({
    required this.media,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final encodedId = Uri.encodeComponent(media.id);
        context.push(
          '/details/search/$encodedId',
          extra: {
            'source': source,
            'initialMedia': media,
          },
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? AppColors.cardDark : Colors.white,
                    border: Border.all(
                      color: isDark
                          ? AppColors.glassBorderDark
                          : AppColors.glassBorderLight,
                      width: 0.5,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: media.coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: media.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          httpHeaders: _getImageHeaders(media.coverUrl!),
                          placeholder: (_, __) => Container(
                            color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
                        )
                      : _buildPlaceholder(isDark),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            media.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Get appropriate headers for image loading based on URL
  Map<String, String> _getImageHeaders(String url) {
    if (url.contains('mangapill') || url.contains('readdetectiveconan')) {
      return {'Referer': 'https://mangapill.com/'};
    }
    return {};
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.surfaceDark : Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.image,
          size: 32,
          color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
        ),
      ),
    );
  }
}

/// Styled search filter chip with frosted glass borders and explicit light/dark labels
class _SearchFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.12) : primary)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : primary)
                : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
            width: 0.5,
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
