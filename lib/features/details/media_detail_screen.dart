import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../data/sources/source.dart';
import '../../data/models/library_entry.dart';
import '../../core/utils/providers.dart';
import '../reader/reader_providers.dart';
import '../player/player_providers.dart';
import 'tracker_status_sheet.dart';

/// Provider for media details
final mediaDetailsProvider = FutureProvider.family<SourceMedia, (Source, String)>(
  (ref, params) async {
    final (source, id) = params;
    return source.getDetails(id);
  },
);

/// Provider for chapters/episodes
final chaptersProvider = FutureProvider.family<List<SourceChapter>, (Source, String)>(
  (ref, params) async {
    final (source, mediaId) = params;
    return source.getChapters(mediaId);
  },
);

/// Screen showing details of a manga/anime with chapter list
class MediaDetailScreen extends ConsumerStatefulWidget {
  final String mediaId;
  final Source source;
  final SourceMedia? initialMedia;

  const MediaDetailScreen({
    super.key,
    required this.mediaId,
    required this.source,
    this.initialMedia,
  });

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  bool _isInLibrary = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkLibraryStatus();
  }

  Future<void> _checkLibraryStatus() async {
    final repo = ref.read(libraryRepositoryProvider);
    final inLibrary = await repo.isInLibrary('${widget.source.id}:${widget.mediaId}');
    if (mounted) {
      setState(() => _isInLibrary = inLibrary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(mediaDetailsProvider((widget.source, widget.mediaId)));
    final chaptersAsync = ref.watch(chaptersProvider((widget.source, widget.mediaId)));

    // Update totalCount when chapters are loaded
    chaptersAsync.whenData((chapters) async {
      if (chapters.isNotEmpty) {
        final repo = ref.read(libraryRepositoryProvider);
        final entry = await repo.getBySourceId('${widget.source.id}:${widget.mediaId}');
        if (entry != null && entry.totalCount != chapters.length) {
          entry.totalCount = chapters.length;
          await repo.updateEntry(entry);
        }
      }
    });

    // Use initial media while loading full details
    final media = detailsAsync.valueOrNull ?? widget.initialMedia;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with cover image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  if (media?.coverUrl != null)
                    CachedNetworkImage(
                      imageUrl: media!.coverUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: _getImageHeaders(media.coverUrl!),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surfaceDark,
                      ),
                    )
                  else
                    Container(color: AppColors.surfaceDark),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.darkOverlay,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // Share functionality
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    media?.title ?? 'Loading...',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),

                  // Metadata row
                  if (media != null) _buildMetadataRow(media),
                  const SizedBox(height: 16),

                  // Action buttons
                  _buildActionButtons(media),
                  const SizedBox(height: 16),

                  // Description
                  if (media?.description != null) ...[
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Text(
                        media!.description!,
                        maxLines: _isExpanded ? null : 4,
                        overflow: _isExpanded ? null : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ),
                    if (!_isExpanded && (media.description?.length ?? 0) > 200)
                      TextButton(
                        onPressed: () => setState(() => _isExpanded = true),
                        child: const Text('Show more'),
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Genres
                  if (media?.genres.isNotEmpty ?? false) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: media!.genres.map((genre) {
                        return Chip(
                          label: Text(genre),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Chapters/Episodes header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.source.contentType == SourceContentType.anime
                            ? 'Episodes'
                            : 'Chapters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      chaptersAsync.when(
                        data: (chapters) => Text(
                          '${chapters.length} total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Chapters/Episodes list
          chaptersAsync.when(
            data: (chapters) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ChapterTile(
                  chapter: chapters[index],
                  source: widget.source,
                  mediaId: widget.mediaId,
                  chapters: chapters,
                  chapterIndex: index,
                ),
                childCount: chapters.length,
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Failed to load: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(chaptersProvider((widget.source, widget.mediaId))),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(SourceMedia media) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (media.author != null)
          _MetadataChip(
            icon: Icons.person,
            label: media.author!,
          ),
        if (media.status != null)
          _MetadataChip(
            icon: Icons.info_outline,
            label: media.status!.toUpperCase(),
          ),
        _MetadataChip(
          icon: widget.source.contentType == SourceContentType.anime
              ? Icons.play_circle
              : Icons.menu_book,
          label: widget.source.name,
        ),
      ],
    );
  }

  Widget _buildActionButtons(SourceMedia? media) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: media != null ? () => _addToLibrary(media) : null,
            icon: Icon(_isInLibrary ? Icons.check : Icons.add),
            label: Text(_isInLibrary ? 'In Library' : 'Add to Library'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isInLibrary ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: media != null ? () {
            _showTrackingSheet(media.title);
          } : null,
          icon: const Icon(Icons.bookmark_border),
          label: const Text('Track'),
        ),
      ],
    );
  }

  Future<void> _addToLibrary(SourceMedia media) async {
    if (_isInLibrary) {
      // Remove from library
      final repo = ref.read(libraryRepositoryProvider);
      await repo.deleteBySourceId('${widget.source.id}:${media.id}');
      setState(() => _isInLibrary = false);
      ref.invalidate(libraryEntriesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from library')),
        );
      }
    } else {
      // Add to library
      final entry = LibraryEntry()
        ..sourceId = '${widget.source.id}:${media.id}'
        ..mediaId = media.id
        ..sourceName = widget.source.id
        ..title = media.title
        ..coverUrl = media.coverUrl
        ..description = media.description
        ..authors = media.author != null ? [media.author!] : []
        ..artists = media.artist != null ? [media.artist!] : []
        ..genres = media.genres
        ..publicationStatus = _mapStatus(media.status)
        ..mediaType = _mapContentType(widget.source.contentType)
        ..status = widget.source.contentType == SourceContentType.anime 
            ? MediaStatus.planToWatch 
            : MediaStatus.planToRead;

      final repo = ref.read(libraryRepositoryProvider);
      await repo.saveEntry(entry);
      setState(() => _isInLibrary = true);
      ref.invalidate(libraryEntriesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to library')),
        );
      }
    }
  }

  MediaType _mapContentType(SourceContentType type) {
    switch (type) {
      case SourceContentType.manga:
        return MediaType.manga;
      case SourceContentType.anime:
        return MediaType.anime;
      case SourceContentType.novel:
        return MediaType.novel;
    }
  }

  PublicationStatus _mapStatus(String? status) {
    if (status == null) return PublicationStatus.unknown;
    switch (status.toLowerCase()) {
      case 'ongoing':
        return PublicationStatus.ongoing;
      case 'completed':
        return PublicationStatus.completed;
      case 'hiatus':
        return PublicationStatus.hiatus;
      case 'cancelled':
        return PublicationStatus.cancelled;
      default:
        return PublicationStatus.unknown;
    }
  }

  void _showTrackingSheet(String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => TrackerStatusSheet(title: title),
    );
  }

  /// Get appropriate headers for image loading based on URL
  Map<String, String> _getImageHeaders(String url) {
    if (url.contains('mangapill') || url.contains('readdetectiveconan')) {
      return {'Referer': 'https://mangapill.com/'};
    }
    return {};
  }
}

/// Metadata chip widget
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryDark),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}

/// Chapter/Episode list tile
class _ChapterTile extends StatelessWidget {
  final SourceChapter chapter;
  final Source source;
  final String mediaId;
  final List<SourceChapter> chapters;
  final int chapterIndex;

  const _ChapterTile({
    required this.chapter,
    required this.source,
    required this.mediaId,
    required this.chapters,
    required this.chapterIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        chapter.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          if (chapter.scanlator != null) ...[
            Text(
              chapter.scanlator!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
          ],
          if (chapter.dateUpload != null)
            Text(
              _formatDate(chapter.dateUpload!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _openContent(context);
      },
    );
  }

  void _openContent(BuildContext context) {
    if (source.contentType == SourceContentType.anime) {
      // Navigate to the player with full episode context
      final params = PlayerParams(
        source: source,
        mediaId: mediaId,
        episodeId: chapter.id,
        episodes: chapters,
        initialEpisodeIndex: chapterIndex,
      );
      final encodedId = Uri.encodeComponent(chapter.id);
      context.push(
        AppRouter.player.replaceFirst(':id', encodedId),
        extra: params,
      );
    } else {
      // Navigate to the reader with full chapter context
      final params = ReaderParams(
        source: source,
        mediaId: mediaId,
        chapterId: chapter.id,
        chapters: chapters,
        initialChapterIndex: chapterIndex,
      );
      final encodedId = Uri.encodeComponent(chapter.id);
      context.push(
        AppRouter.reader.replaceFirst(':id', encodedId),
        extra: params,
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else if (diff.inDays < 365) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }
}
