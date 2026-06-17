import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../data/sources/source.dart';
import '../../data/sources/source_registry.dart';
import '../extensions/extension_manager_screen.dart';
import '../../ui/widgets/glass_app_bar.dart';

/// Browse screen for discovering new manga/anime from sources
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mangaSources = ref.watch(mangaSourcesProvider);
    final animeSources = ref.watch(animeSourcesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(
          'Browse',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.glassBorderDark
                    : AppColors.glassBorderLight,
                width: 0.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.extension, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExtensionManagerScreen(),
                  ),
                );
              },
              tooltip: 'Extensions',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _BrowseSegmentedControl(
            controller: _tabController,
            onTap: (index) {
              _tabController.animateTo(index);
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Manga tab
          _BrowseContentTab(
            source: mangaSources.isNotEmpty ? mangaSources.first : null,
          ),
          // Anime tab
          _BrowseContentTab(
            source: animeSources.isNotEmpty ? animeSources.first : null,
          ),
        ],
      ),
    );
  }
}

/// A single tab that shows search + Popular/Latest filter + content grid
class _BrowseContentTab extends ConsumerStatefulWidget {
  final Source? source;

  const _BrowseContentTab({required this.source});

  @override
  ConsumerState<_BrowseContentTab> createState() => _BrowseContentTabState();
}

class _BrowseContentTabState extends ConsumerState<_BrowseContentTab>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  _ContentFilter _selectedFilter = _ContentFilter.popular;
  String _searchQuery = '';

  // Content data
  final List<SourceMedia> _items = [];
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.source != null) {
      _loadPage(1);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    if (_isLoading || widget.source == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final SourcePaginatedResult<SourceMedia> result;
      if (_searchQuery.isNotEmpty) {
        result = await widget.source!.search(_searchQuery, page);
      } else if (_selectedFilter == _ContentFilter.latest) {
        result = await widget.source!.getLatest(page);
      } else {
        result = await widget.source!.getPopular(page);
      }

      if (!mounted) return;
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
      if (!mounted) return;
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

  void _onFilterChanged(_ContentFilter filter) {
    if (filter == _selectedFilter) return;
    setState(() {
      _selectedFilter = filter;
      _searchQuery = '';
      _searchController.clear();
      _items.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    _loadPage(1);
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _items.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.source == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No sources available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add extensions to browse content',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: _onSearch,
          ),
        ),

        // Popular / Latest filter toggle
        if (_searchQuery.isEmpty)
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FilterChip(
                    label: 'Popular',
                    isSelected: _selectedFilter == _ContentFilter.popular,
                    onTap: () => _onFilterChanged(_ContentFilter.popular),
                  ),
                  if (widget.source!.supportsLatest) ...[
                    const SizedBox(width: 4),
                    _FilterChip(
                      label: 'Latest',
                      isSelected: _selectedFilter == _ContentFilter.latest,
                      onTap: () => _onFilterChanged(_ContentFilter.latest),
                    ),
                  ],
                ],
              ),
            ),
          ),

        const SizedBox(height: 4),

        // Content grid
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_error != null && _items.isEmpty) {
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
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadPage(1),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textTertiaryDark),
            const SizedBox(height: 16),
            Text(
              'No results for "$_searchQuery"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
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
          childAspectRatio: 0.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return _MediaCard(
            media: _items[index],
            source: widget.source!,
          );
        },
      ),
    );
  }
}

enum _ContentFilter { popular, latest }

/// Filter chip toggle (Popular / Latest)
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            width: 0.5,
          ),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                ? (isDark ? Colors.white : primary)
                : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.4)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
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
        // URL-encode the media ID to handle IDs with slashes (e.g., "2/one-piece")
        final encodedId = Uri.encodeComponent(media.id);
        context.push(
          '/details/browse/$encodedId',
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
                        color: AppColors.surfaceDark,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surfaceDark,
      child: const Center(
        child: Icon(Icons.image, size: 32, color: AppColors.textTertiaryDark),
      ),
    );
  }
}

/// Custom compact sliding segmented control for Browse (Manga/Anime) with smooth active pill animation
class _BrowseSegmentedControl extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int> onTap;

  const _BrowseSegmentedControl({
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final tabWidth = totalWidth / 2;

          return AnimatedBuilder(
            animation: controller.animation!,
            builder: (context, child) {
              final value = controller.animation?.value ?? controller.index.toDouble();

              return Stack(
                children: [
                  // Sliding indicator pill
                  Positioned(
                    left: value * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Tab labels row (Manga and Anime inline)
                  Row(
                    children: [
                      _buildTab(context, 0, Icons.menu_book, 'Manga', value),
                      _buildTab(context, 1, Icons.play_circle, 'Anime', value),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index, IconData icon, String label, double value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final distance = (value - index).abs();
    final double t = (1.0 - distance).clamp(0.0, 1.0);
    final selectedColor = isDark ? Colors.white : AppColors.primary;
    final unselectedColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.4);
    final activeColor = Color.lerp(unselectedColor, selectedColor, t)!;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: activeColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: t > 0.5 ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
