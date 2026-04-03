import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sources/source.dart';
import '../../data/sources/source_registry.dart';
import 'source_browse_screen.dart';

/// Browse screen for discovering new manga/anime from sources
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSources = ref.watch(allSourcesProvider);
    final mangaSources = ref.watch(mangaSourcesProvider);
    final animeSources = ref.watch(animeSourcesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          actions: [
            IconButton(
              icon: const Icon(Icons.extension),
              onPressed: () {
                // Navigate to extension manager
                _showExtensionInfo(context);
              },
              tooltip: 'Extensions',
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Manga'),
              Tab(text: 'Anime'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SourceList(sources: allSources),
            _SourceList(sources: mangaSources),
            _SourceList(sources: animeSources),
          ],
        ),
      ),
    );
  }

  void _showExtensionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extensions'),
        content: const Text(
          'Custom JavaScript extensions will be available in a future update.\n\n'
          'For now, enjoy the built-in MangaDex and Gogoanime sources!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// List of available sources
class _SourceList extends StatelessWidget {
  final List<Source> sources;

  const _SourceList({required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
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
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return _SourceTile(source: source);
      },
    );
  }
}

/// Individual source tile
class _SourceTile extends StatelessWidget {
  final Source source;

  const _SourceTile({required this.source});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _getSourceColor().withValues(alpha: 0.2),
        ),
        child: source.iconUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: source.iconUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildIcon(),
                ),
              )
            : _buildIcon(),
      ),
      title: Text(source.name),
      subtitle: Text(
        '${source.language.toUpperCase()} • ${_getContentTypeLabel()}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SourceBrowseScreen(source: source),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    return Icon(
      _getSourceIcon(),
      color: _getSourceColor(),
      size: 24,
    );
  }

  IconData _getSourceIcon() {
    switch (source.contentType) {
      case SourceContentType.manga:
        return Icons.menu_book;
      case SourceContentType.anime:
        return Icons.play_circle;
      case SourceContentType.novel:
        return Icons.auto_stories;
    }
  }

  Color _getSourceColor() {
    switch (source.contentType) {
      case SourceContentType.manga:
        return AppColors.manga;
      case SourceContentType.anime:
        return AppColors.anime;
      case SourceContentType.novel:
        return AppColors.novel;
    }
  }

  String _getContentTypeLabel() {
    switch (source.contentType) {
      case SourceContentType.manga:
        return 'Manga';
      case SourceContentType.anime:
        return 'Anime';
      case SourceContentType.novel:
        return 'Novel';
    }
  }
}
