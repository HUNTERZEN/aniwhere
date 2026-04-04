import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/providers.dart';
import '../../data/models/library_entry.dart';
import '../../data/models/app_settings.dart';
import '../../data/sources/source_registry.dart';
import '../details/media_detail_screen.dart';

/// Provider for filtered and sorted library entries
final filteredLibraryProvider = Provider<List<LibraryEntry>>((ref) {
  final entriesAsync = ref.watch(libraryEntriesProvider);
  final sortMode = ref.watch(librarySortModeProvider);
  final statusFilter = ref.watch(libraryStatusFilterProvider);
  
  return entriesAsync.when(
    data: (entries) {
      var filtered = entries.toList();
      
      // Apply status filter
      if (statusFilter != null) {
        filtered = filtered.where((e) => e.status == statusFilter).toList();
      }
      
      // Apply sorting
      switch (sortMode) {
        case LibrarySortMode.alphabetical:
          filtered.sort((a, b) => a.title.compareTo(b.title));
          break;
        case LibrarySortMode.lastRead:
          filtered.sort((a, b) => (b.lastProgress ?? DateTime(1970))
              .compareTo(a.lastProgress ?? DateTime(1970)));
          break;
        case LibrarySortMode.lastUpdated:
          filtered.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
          break;
        case LibrarySortMode.dateAdded:
          filtered.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
          break;
        case LibrarySortMode.unreadCount:
          filtered.sort((a, b) {
            final aUnread = (a.totalCount ?? 0) - a.currentProgress;
            final bUnread = (b.totalCount ?? 0) - b.currentProgress;
            return bUnread.compareTo(aUnread);
          });
          break;
        case LibrarySortMode.totalChapters:
          filtered.sort((a, b) => 
              (b.totalCount ?? 0).compareTo(a.totalCount ?? 0));
          break;
      }
      
      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Provider for status filter
final libraryStatusFilterProvider = StateProvider<MediaStatus?>((ref) => null);

/// Library screen displaying user's saved manga/anime/novels
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  final List<_LibraryTab> _tabs = [
    const _LibraryTab('All', null),
    const _LibraryTab('Manga', MediaType.manga),
    const _LibraryTab('Anime', MediaType.anime),
    const _LibraryTab('Novels', MediaType.novel),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayMode = ref.watch(libraryDisplayModeProvider);
    final statusFilter = ref.watch(libraryStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search library...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('Library'),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          // Display mode toggle
          IconButton(
            icon: Icon(
              displayMode == LibraryDisplayMode.grid
                  ? Icons.view_list
                  : Icons.grid_view,
            ),
            onPressed: () {
              ref.read(libraryDisplayModeProvider.notifier).state =
                  displayMode == LibraryDisplayMode.grid
                      ? LibraryDisplayMode.list
                      : LibraryDisplayMode.grid;
            },
          ),
          // Filter/Sort button
          IconButton(
            icon: Badge(
              isLabelVisible: statusFilter != null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _LibraryTabView(
          mediaType: tab.type,
          searchQuery: _searchQuery,
        )).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(AppRouter.browse),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _FilterSheet(),
    );
  }
}

class _LibraryTab {
  final String label;
  final MediaType? type;

  const _LibraryTab(this.label, this.type);
}

/// Tab view showing filtered library entries
class _LibraryTabView extends ConsumerWidget {
  final MediaType? mediaType;
  final String searchQuery;

  const _LibraryTabView({this.mediaType, this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(filteredLibraryProvider);
    final displayMode = ref.watch(libraryDisplayModeProvider);

    // Filter by media type and search query
    var filtered = mediaType == null
        ? entries
        : entries.where((e) => e.mediaType == mediaType).toList();
    
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((e) => e.title.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    if (filtered.isEmpty) {
      return _EmptyLibraryView(
        mediaType: mediaType,
        hasFilter: searchQuery.isNotEmpty || ref.watch(libraryStatusFilterProvider) != null,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(libraryEntriesProvider);
      },
      child: displayMode == LibraryDisplayMode.grid
          ? _LibraryGrid(entries: filtered)
          : _LibraryList(entries: filtered),
    );
  }
}

/// Empty state for library
class _EmptyLibraryView extends StatelessWidget {
  final MediaType? mediaType;
  final bool hasFilter;

  const _EmptyLibraryView({this.mediaType, this.hasFilter = false});

  @override
  Widget build(BuildContext context) {
    final typeLabel = mediaType?.name ?? 'content';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilter ? Icons.filter_list_off : Icons.collections_bookmark_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            hasFilter ? 'No results found' : 'Your library is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter 
                ? 'Try adjusting your filters'
                : 'Start by adding some $typeLabel from Browse',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (!hasFilter)
            ElevatedButton.icon(
              onPressed: () => context.go(AppRouter.browse),
              icon: const Icon(Icons.explore),
              label: const Text('Browse'),
            ),
        ],
      ),
    );
  }
}

/// Grid view for library entries
class _LibraryGrid extends StatelessWidget {
  final List<LibraryEntry> entries;

  const _LibraryGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _LibraryGridItem(entry: entries[index]);
      },
    );
  }
}

/// Grid item for library entry with progress indicators
class _LibraryGridItem extends ConsumerWidget {
  final LibraryEntry entry;

  const _LibraryGridItem({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _calculateProgress();
    final unreadCount = _calculateUnread();

    return GestureDetector(
      onTap: () {
        final source = ref.read(sourceByIdProvider(entry.sourceName));
        if (source != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MediaDetailScreen(
                mediaId: entry.mediaId,
                source: source,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Source "${entry.sourceName}" not found')),
          );
        }
      },
      onLongPress: () => _showEntryActions(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with overlays
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.cardDark,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  if (entry.coverUrl != null)
                    CachedNetworkImage(
                      imageUrl: entry.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildPlaceholder(),
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  else
                    _buildPlaceholder(),
                  // Status indicator (top left)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black38, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Unread badge (top right)
                  if (unreadCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Progress bar at bottom
                  if (entry.totalCount != null && entry.totalCount! > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        color: Colors.black.withValues(alpha: 0.5),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(color: AppColors.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            entry.title,
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
      child: Center(
        child: Text(
          entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiaryDark,
          ),
        ),
      ),
    );
  }

  double _calculateProgress() {
    if (entry.totalCount == null || entry.totalCount == 0) return 0;
    return (entry.currentProgress / entry.totalCount!).clamp(0.0, 1.0);
  }

  int _calculateUnread() {
    if (entry.totalCount == null) return 0;
    return (entry.totalCount! - entry.currentProgress).clamp(0, entry.totalCount!);
  }

  Color _getStatusColor() {
    switch (entry.status) {
      case MediaStatus.reading:
      case MediaStatus.watching:
        return AppColors.primary;
      case MediaStatus.completed:
        return Colors.green;
      case MediaStatus.onHold:
        return Colors.orange;
      case MediaStatus.dropped:
        return Colors.red;
      case MediaStatus.planToRead:
      case MediaStatus.planToWatch:
        return Colors.grey;
    }
  }

  void _showEntryActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _EntryActionSheet(entry: entry),
    );
  }
}

/// Placeholder cover widget
class _PlaceholderCover extends StatelessWidget {
  final LibraryEntry entry;

  const _PlaceholderCover({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceDark,
      child: Center(
        child: Text(
          entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiaryDark,
          ),
        ),
      ),
    );
  }
}

/// List view for library entries
class _LibraryList extends StatelessWidget {
  final List<LibraryEntry> entries;

  const _LibraryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _LibraryListItem(entry: entries[index]);
      },
    );
  }
}

/// List item for library entry with full details
class _LibraryListItem extends ConsumerWidget {
  final LibraryEntry entry;

  const _LibraryListItem({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _calculateProgress();
    final unreadCount = _calculateUnread();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final source = ref.read(sourceByIdProvider(entry.sourceName));
          if (source != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaDetailScreen(
                  mediaId: entry.mediaId,
                  source: source,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Source "${entry.sourceName}" not found')),
            );
          }
        },
        onLongPress: () => _showEntryActions(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover image with status
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.surfaceDark,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: entry.coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: entry.coverUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (_, __, ___) => _PlaceholderCover(entry: entry),
                          )
                        : _PlaceholderCover(entry: entry),
                  ),
                  // Status dot
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black38, width: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          entry.mediaType.name.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.currentProgress}/${entry.totalCount ?? '?'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$unreadCount new',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusLabel(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    if (entry.totalCount != null && entry.totalCount! > 0)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.borderDark,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 4,
                        ),
                      ),
                  ],
                ),
              ),
              // Actions column
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: entry.isFavorite ? AppColors.error : null,
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(ref),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _showEntryActions(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateProgress() {
    if (entry.totalCount == null || entry.totalCount == 0) return 0;
    return (entry.currentProgress / entry.totalCount!).clamp(0.0, 1.0);
  }

  int _calculateUnread() {
    if (entry.totalCount == null) return 0;
    return (entry.totalCount! - entry.currentProgress).clamp(0, entry.totalCount!);
  }

  Color _getStatusColor() {
    switch (entry.status) {
      case MediaStatus.reading:
      case MediaStatus.watching:
        return AppColors.primary;
      case MediaStatus.completed:
        return Colors.green;
      case MediaStatus.onHold:
        return Colors.orange;
      case MediaStatus.dropped:
        return Colors.red;
      case MediaStatus.planToRead:
      case MediaStatus.planToWatch:
        return Colors.grey;
    }
  }

  String _getStatusLabel() {
    switch (entry.status) {
      case MediaStatus.reading:
        return 'Reading';
      case MediaStatus.watching:
        return 'Watching';
      case MediaStatus.completed:
        return 'Completed';
      case MediaStatus.onHold:
        return 'On Hold';
      case MediaStatus.dropped:
        return 'Dropped';
      case MediaStatus.planToRead:
        return 'Plan to Read';
      case MediaStatus.planToWatch:
        return 'Plan to Watch';
    }
  }

  void _toggleFavorite(WidgetRef ref) async {
    final repo = ref.read(libraryRepositoryProvider);
    final updatedEntry = entry..isFavorite = !entry.isFavorite;
    await repo.updateEntry(updatedEntry);
    ref.invalidate(libraryEntriesProvider);
  }

  void _showEntryActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _EntryActionSheet(entry: entry),
    );
  }
}

/// Filter and sort bottom sheet
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortMode = ref.watch(librarySortModeProvider);
    final statusFilter = ref.watch(libraryStatusFilterProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Status Filter Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (statusFilter != null)
                    TextButton(
                      onPressed: () {
                        ref.read(libraryStatusFilterProvider.notifier).state = null;
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MediaStatus.values.map((status) {
                  return FilterChip(
                    label: Text(_getStatusLabel(status)),
                    avatar: Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: statusFilter == status 
                          ? Colors.white 
                          : _getStatusColor(status),
                    ),
                    selected: statusFilter == status,
                    selectedColor: _getStatusColor(status),
                    onSelected: (selected) {
                      ref.read(libraryStatusFilterProvider.notifier).state = 
                          selected ? status : null;
                    },
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Sort Section
              Text(
                'Sort By',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LibrarySortMode.values.map((mode) {
                  return ChoiceChip(
                    label: Text(_getSortLabel(mode)),
                    selected: sortMode == mode,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(librarySortModeProvider.notifier).state = mode;
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusLabel(MediaStatus status) {
    switch (status) {
      case MediaStatus.reading:
        return 'Reading';
      case MediaStatus.watching:
        return 'Watching';
      case MediaStatus.completed:
        return 'Completed';
      case MediaStatus.onHold:
        return 'On Hold';
      case MediaStatus.dropped:
        return 'Dropped';
      case MediaStatus.planToRead:
        return 'Plan to Read';
      case MediaStatus.planToWatch:
        return 'Plan to Watch';
    }
  }

  IconData _getStatusIcon(MediaStatus status) {
    switch (status) {
      case MediaStatus.reading:
      case MediaStatus.watching:
        return Icons.play_arrow;
      case MediaStatus.completed:
        return Icons.check_circle;
      case MediaStatus.onHold:
        return Icons.pause_circle;
      case MediaStatus.dropped:
        return Icons.cancel;
      case MediaStatus.planToRead:
      case MediaStatus.planToWatch:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(MediaStatus status) {
    switch (status) {
      case MediaStatus.reading:
      case MediaStatus.watching:
        return AppColors.primary;
      case MediaStatus.completed:
        return Colors.green;
      case MediaStatus.onHold:
        return Colors.orange;
      case MediaStatus.dropped:
        return Colors.red;
      case MediaStatus.planToRead:
      case MediaStatus.planToWatch:
        return Colors.grey;
    }
  }

  String _getSortLabel(LibrarySortMode mode) {
    switch (mode) {
      case LibrarySortMode.alphabetical:
        return 'Alphabetical';
      case LibrarySortMode.lastRead:
        return 'Last Read';
      case LibrarySortMode.lastUpdated:
        return 'Last Updated';
      case LibrarySortMode.dateAdded:
        return 'Date Added';
      case LibrarySortMode.unreadCount:
        return 'Unread Count';
      case LibrarySortMode.totalChapters:
        return 'Total Chapters';
    }
  }
}

/// Entry action bottom sheet for managing library entries
class _EntryActionSheet extends ConsumerWidget {
  final LibraryEntry entry;

  const _EntryActionSheet({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              entry.title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          
          // Status change
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('Change Status'),
            subtitle: Text(_getStatusLabel(entry.status)),
            onTap: () {
              Navigator.pop(context);
              _showStatusPicker(context, ref);
            },
          ),
          
          // Toggle favorite
          ListTile(
            leading: Icon(
              entry.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: entry.isFavorite ? AppColors.error : null,
            ),
            title: Text(entry.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
            onTap: () async {
              final repo = ref.read(libraryRepositoryProvider);
              final updatedEntry = entry..isFavorite = !entry.isFavorite;
              await repo.updateEntry(updatedEntry);
              ref.invalidate(libraryEntriesProvider);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          
          // Mark all as read
          ListTile(
            leading: const Icon(Icons.done_all),
            title: const Text('Mark All as Read'),
            onTap: () async {
              final repo = ref.read(libraryRepositoryProvider);
              final updatedEntry = entry
                ..currentProgress = entry.totalCount ?? entry.currentProgress
                ..status = MediaStatus.completed;
              await repo.updateEntry(updatedEntry);
              ref.invalidate(libraryEntriesProvider);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          
          // Edit progress
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Progress'),
            subtitle: Text('${entry.currentProgress}/${entry.totalCount ?? '?'}'),
            onTap: () {
              Navigator.pop(context);
              _showProgressEditor(context, ref);
            },
          ),
          
          const Divider(),
          
          // Remove from library
          ListTile(
            leading: const Icon(Icons.delete, color: AppColors.error),
            title: const Text('Remove from Library', 
              style: TextStyle(color: AppColors.error)),
            onTap: () => _confirmRemove(context, ref),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(MediaStatus status) {
    switch (status) {
      case MediaStatus.reading:
        return 'Reading';
      case MediaStatus.watching:
        return 'Watching';
      case MediaStatus.completed:
        return 'Completed';
      case MediaStatus.onHold:
        return 'On Hold';
      case MediaStatus.dropped:
        return 'Dropped';
      case MediaStatus.planToRead:
        return 'Plan to Read';
      case MediaStatus.planToWatch:
        return 'Plan to Watch';
    }
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MediaStatus.values.map((status) {
            return RadioListTile<MediaStatus>(
              title: Text(_getStatusLabel(status)),
              value: status,
              groupValue: entry.status,
              onChanged: (value) async {
                if (value != null) {
                  final repo = ref.read(libraryRepositoryProvider);
                  final updatedEntry = entry..status = value;
                  await repo.updateEntry(updatedEntry);
                  ref.invalidate(libraryEntriesProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showProgressEditor(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: entry.currentProgress.toString(),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Progress'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Current Progress',
            suffixText: '/ ${entry.totalCount ?? '?'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final progress = int.tryParse(controller.text) ?? entry.currentProgress;
              final repo = ref.read(libraryRepositoryProvider);
              final updatedEntry = entry..currentProgress = progress;
              await repo.updateEntry(updatedEntry);
              ref.invalidate(libraryEntriesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Library?'),
        content: Text('Are you sure you want to remove "${entry.title}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () async {
              final repo = ref.read(libraryRepositoryProvider);
              await repo.deleteEntry(entry.id);
              ref.invalidate(libraryEntriesProvider);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close action sheet
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
