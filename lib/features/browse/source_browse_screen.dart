import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sources/source.dart';
import '../details/media_detail_screen.dart';

/// Provider for popular content from a source
final popularContentProvider = FutureProvider.family<SourcePaginatedResult<SourceMedia>, (Source, int)>(
  (ref, params) async {
    final (source, page) = params;
    return source.getPopular(page);
  },
);

/// Provider for latest content from a source
final latestContentProvider = FutureProvider.family<SourcePaginatedResult<SourceMedia>, (Source, int)>(
  (ref, params) async {
    final (source, page) = params;
    return source.getLatest(page);
  },
);

/// Provider for search results from a source
final searchContentProvider = FutureProvider.family<SourcePaginatedResult<SourceMedia>, (Source, String, int)>(
  (ref, params) async {
    final (source, query, page) = params;
    return source.search(query, page);
  },
);

/// Screen for browsing content from a specific source
class SourceBrowseScreen extends ConsumerStatefulWidget {
  final Source source;

  const SourceBrowseScreen({super.key, required this.source});

  @override
  ConsumerState<SourceBrowseScreen> createState() => _SourceBrowseScreenState();
}

class _SourceBrowseScreenState extends ConsumerState<SourceBrowseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.source.supportsLatest ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.source.name}...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Text(widget.source.name),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
        bottom: _isSearching
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                tabs: [
                  const Tab(text: 'Popular'),
                  if (widget.source.supportsLatest) const Tab(text: 'Latest'),
                ],
              ),
      ),
      body: _isSearching && _searchQuery.isNotEmpty
          ? _SearchResults(source: widget.source, query: _searchQuery)
          : _isSearching
              ? _buildSearchPlaceholder()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _ContentGrid(
                      source: widget.source,
                      type: _ContentType.popular,
                    ),
                    if (widget.source.supportsLatest)
                      _ContentGrid(
                        source: widget.source,
                        type: _ContentType.latest,
                      ),
                  ],
                ),
    );
  }

  Widget _buildSearchPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search ${widget.source.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a title to search',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ContentType { popular, latest }

/// Grid of content from a source
class _ContentGrid extends ConsumerStatefulWidget {
  final Source source;
  final _ContentType type;

  const _ContentGrid({
    required this.source,
    required this.type,
  });

  @override
  ConsumerState<_ContentGrid> createState() => _ContentGridState();
}

class _ContentGridState extends ConsumerState<_ContentGrid> {
  final _scrollController = ScrollController();
  final List<SourceMedia> _items = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadPage(int page) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = widget.type == _ContentType.popular
          ? await widget.source.getPopular(page)
          : await widget.source.getLatest(page);

      setState(() {
        if (page == 1) {
          _items.clear();
        }
        _items.addAll(result.items);
        _hasMore = result.hasNextPage;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadNextPage() {
    if (!_isLoading && _hasMore) {
      _loadPage(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return _ErrorView(
        error: _error!,
        onRetry: () => _loadPage(1),
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No content found',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(1),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _MediaCard(
            media: _items[index],
            source: widget.source,
          );
        },
      ),
    );
  }
}

/// Search results view
class _SearchResults extends ConsumerStatefulWidget {
  final Source source;
  final String query;

  const _SearchResults({
    required this.source,
    required this.query,
  });

  @override
  ConsumerState<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<_SearchResults> {
  final _scrollController = ScrollController();
  final List<SourceMedia> _items = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _items.clear();
      _currentPage = 1;
      _hasMore = true;
      _loadPage(1);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadPage(int page) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.source.search(widget.query, page);

      setState(() {
        if (page == 1) {
          _items.clear();
        }
        _items.addAll(result.items);
        _hasMore = result.hasNextPage;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadNextPage() {
    if (!_isLoading && _hasMore) {
      _loadPage(_currentPage + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return _ErrorView(
        error: _error!,
        onRetry: () => _loadPage(1),
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textTertiaryDark),
            const SizedBox(height: 16),
            Text(
              'No results for "${widget.query}"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _MediaCard(
          media: _items[index],
          source: widget.source,
        );
      },
    );
  }
}

/// Media card for grid display
class _MediaCard extends StatelessWidget {
  final SourceMedia media;
  final Source source;

  const _MediaCard({
    required this.media,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/details/browse/${media.id}',
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
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.cardDark,
              ),
              clipBehavior: Clip.antiAlias,
              child: media.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: media.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) => Container(
                        color: AppColors.surfaceDark,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceDark,
      child: const Center(
        child: Icon(Icons.image, size: 32, color: AppColors.textTertiaryDark),
      ),
    );
  }
}

/// Error view with retry button
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load content',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
