import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'player_providers.dart';

class EpisodeSidebar extends ConsumerWidget {
  final PlayerStateNotifier notifier;
  final PlayerState state;

  const EpisodeSidebar({
    super.key,
    required this.notifier,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.isSidebarOpen) {
      return const SizedBox.shrink();
    }

    final episodes = notifier.params.episodes;

    return Container(
      width: 300,
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
      child: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Episodes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: notifier.toggleSidebar,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Episode List
          Expanded(
            child: ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final episode = episodes[index];
                final isCurrent = index == state.currentEpisodeIndex;
                
                // We could also watch chapterProgressProvider here to show
                // watched status, but keeping it simple for now as it would
                // require a Consumer widget per item.

                return ListTile(
                  title: Text(
                    episode.title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppColors.primary : null,
                    ),
                  ),
                  subtitle: episode.number != null
                      ? Text('Episode ${episode.number?.toStringAsFixed(0)}')
                      : null,
                  tileColor: isCurrent ? AppColors.primary.withOpacity(0.1) : null,
                  onTap: () {
                    if (!isCurrent) {
                      notifier.switchEpisode(index);
                    }
                    notifier.toggleSidebar();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
