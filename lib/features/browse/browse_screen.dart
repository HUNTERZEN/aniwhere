import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

/// Browse screen for discovering new manga/anime from sources
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            onPressed: () {
              // Navigate to extension manager
            },
            tooltip: 'Extensions',
          ),
        ],
      ),
      body: const _BrowseBody(),
    );
  }
}

class _BrowseBody extends StatelessWidget {
  const _BrowseBody();

  @override
  Widget build(BuildContext context) {
    // Placeholder for Phase 2 implementation
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.explore,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Browse Sources',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming in Phase 2',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'MangaDex, Gogoanime, and custom extensions',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Preview of what sources will look like
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SourcePreviewItem(
                    name: 'MangaDex',
                    language: 'Multi',
                    icon: Icons.menu_book,
                    color: AppColors.manga,
                  ),
                  const Divider(),
                  _SourcePreviewItem(
                    name: 'Gogoanime',
                    language: 'EN',
                    icon: Icons.play_circle,
                    color: AppColors.anime,
                  ),
                  const Divider(),
                  _SourcePreviewItem(
                    name: 'Custom Extension',
                    language: 'Multi',
                    icon: Icons.extension,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePreviewItem extends StatelessWidget {
  final String name;
  final String language;
  final IconData icon;
  final Color color;

  const _SourcePreviewItem({
    required this.name,
    required this.language,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withOpacity(0.2),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  language,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiaryDark,
          ),
        ],
      ),
    );
  }
}
