import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/providers.dart';
import '../../data/models/library_entry.dart';
import '../../data/models/app_settings.dart';

/// Library screen displaying user's saved manga/anime/novels
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
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
          // Filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterSheet(context);
            },
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
        children: _tabs.map((tab) => _LibraryTabView(mediaType: tab.type)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to browse to add new content
          // context.go(AppRouter.browse);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
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

  const _LibraryTabView({this.mediaType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(libraryEntriesProvider);
    final displayMode = ref.watch(libraryDisplayModeProvider);

    return entriesAsync.when(
      data: (entries) {
        // Filter by media type if specified
        final filtered = mediaType == null
            ? entries
            : entries.where((e) => e.mediaType == mediaType).toList();

        if (filtered.isEmpty) {
          return _EmptyLibraryView(mediaType: mediaType);
        }

        return displayMode == LibraryDisplayMode.grid
            ? _LibraryGrid(entries: filtered)
            : _LibraryList(entries: filtered);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error loading library: $error'),
          ],
        ),
      ),
    );
  }
}

/// Empty state for library
class _EmptyLibraryView extends StatelessWidget {
  final MediaType? mediaType;

  const _EmptyLibraryView({this.mediaType});

  @override
  Widget build(BuildContext context) {
    final typeLabel = mediaType?.name ?? 'content';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Your library is empty',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding some $typeLabel from Browse',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to browse
            },
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
        childAspectRatio: 0.65,
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

/// Grid item for library entry
class _LibraryGridItem extends StatelessWidget {
  final LibraryEntry entry;

  const _LibraryGridItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to details
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
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
                  // Placeholder or actual image
                  if (entry.coverUrl != null)
                    Image.network(
                      entry.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  else
                    _buildPlaceholder(),
                  // Progress indicator
                  if (entry.totalCount != null && entry.totalCount! > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: entry.currentProgress / entry.totalCount!,
                        backgroundColor: Colors.black54,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 3,
                      ),
                    ),
                  // Unread badge
                  if (entry.totalCount != null &&
                      entry.currentProgress < entry.totalCount!)
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${entry.totalCount! - entry.currentProgress}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
      child: const Center(
        child: Icon(Icons.image, size: 32, color: AppColors.textTertiaryDark),
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

/// List item for library entry
class _LibraryListItem extends StatelessWidget {
  final LibraryEntry entry;

  const _LibraryListItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover image
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.surfaceDark,
                ),
                clipBehavior: Clip.antiAlias,
                child: entry.coverUrl != null
                    ? Image.network(entry.coverUrl!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.image, color: AppColors.textTertiaryDark),
                      ),
              ),
              const SizedBox(width: 12),
              // Info
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
                    Text(
                      '${entry.mediaType.name.toUpperCase()} • ${entry.currentProgress}/${entry.totalCount ?? '?'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
                    if (entry.totalCount != null && entry.totalCount! > 0)
                      LinearProgressIndicator(
                        value: entry.currentProgress / entry.totalCount!,
                        backgroundColor: AppColors.borderDark,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 4,
                      ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: Icon(
                  entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: entry.isFavorite ? AppColors.error : null,
                ),
                onPressed: () {
                  // Toggle favorite
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter bottom sheet
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortMode = ref.watch(librarySortModeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sort By',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LibrarySortMode.values.map((mode) {
              return FilterChip(
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
        ],
      ),
    );
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
