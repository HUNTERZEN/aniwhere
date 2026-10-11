import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/music_models.dart';
import 'music_providers.dart';

/// Shows complete options modal for any track (used by 3-dots buttons across the app)
void showTrackOptionsSheet(BuildContext context, WidgetRef ref, MusicTrack track) {
  final isLiked = ref.read(likedSongsProvider).contains(track.id);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final useGlass = ref.read(liquidGlassProvider);
  final intensity = ref.read(liquidGlassIntensityProvider);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: useGlass ? intensity : 0.01,
          sigmaY: useGlass ? intensity : 0.01,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xE6141418)
                : const Color(0xF2FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 40,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),

                // Track header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: track.albumArtUrl != null
                            ? CachedNetworkImage(
                                imageUrl: track.albumArtUrl!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _artFallback(isDark),
                              )
                            : _artFallback(isDark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (track.isLossless)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'LOSSLESS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 24),

                // Action items
                _ActionTile(
                  icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  iconColor: isLiked ? Colors.redAccent : null,
                  title: isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                  subtitle: isLiked ? 'In your library' : 'Add to your Favorites',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(likedSongsProvider.notifier).toggleLike(track.id);
                    if (isLiked) {
                      ref.read(userPlaylistsProvider.notifier).removeTrackFromPlaylist('fav_playlist', track.id);
                    } else {
                      ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist('fav_playlist', track);
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isLiked ? 'Removed from Liked Songs' : 'Saved to Liked Songs ❤️'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),

                _ActionTile(
                  icon: Icons.playlist_add_rounded,
                  title: 'Add to Playlist',
                  subtitle: 'Save to custom or new playlist',
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddToPlaylistSheet(context, ref, track);
                  },
                ),

                _ActionTile(
                  icon: Icons.queue_music_rounded,
                  title: 'Add to Queue',
                  subtitle: 'Play next in current session',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(musicPlayerProvider.notifier).addToQueue(track);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${track.title}" to queue'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),

                _ActionTile(
                  icon: Icons.high_quality_rounded,
                  title: 'Audio Quality',
                  subtitle: 'Current: ${ref.watch(audioQualityWifiProvider).name.toUpperCase()}',
                  onTap: () {
                    Navigator.pop(ctx);
                    showQualitySheet(context, ref);
                  },
                ),

                _ActionTile(
                  icon: Icons.bedtime_outlined,
                  title: 'Sleep Timer',
                  subtitle: ref.watch(sleepTimerProvider) != null
                      ? '${ref.watch(sleepTimerProvider)!.inMinutes} mins remaining'
                      : 'Stop audio after timer',
                  onTap: () {
                    Navigator.pop(ctx);
                    showSleepTimerSheet(context, ref);
                  },
                ),

                _ActionTile(
                  icon: Icons.share_rounded,
                  title: 'Share Track',
                  subtitle: 'Share link with friends',
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sharing "${track.title}" by ${track.artist}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Modal bottom sheet to add a track to user playlists
void showAddToPlaylistSheet(BuildContext context, WidgetRef ref, MusicTrack track) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final playlists = ref.watch(userPlaylistsProvider);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded, color: AppColors.primary, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Add to Playlist',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Create new playlist button
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
                  ),
                  title: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Create a new collection for this track'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showCreatePlaylistDialog(context, ref, trackToAdd: track);
                  },
                ),

                const Divider(indent: 16, endIndent: 16),

                // Existing playlists
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final pl = playlists[index];
                      final containsTrack = pl.tracks.any((t) => t.id == track.id);

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: pl.thumbnailUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: pl.thumbnailUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _artFallback(isDark),
                                )
                              : _artFallback(isDark),
                        ),
                        title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${pl.trackCount} tracks', style: const TextStyle(fontSize: 12)),
                        trailing: containsTrack
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24)
                            : null,
                        onTap: () {
                          if (containsTrack) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Already in "${pl.title}"'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist(pl.id, track);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added "${track.title}" to "${pl.title}"'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Dialog to create a new custom playlist
void showCreatePlaylistDialog(BuildContext context, WidgetRef ref, {MusicTrack? trackToAdd}) {
  final titleController = TextEditingController();
  final descController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist title',
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              hintText: 'Optional description',
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final title = titleController.text.trim();
            if (title.isNotEmpty) {
              ref.read(userPlaylistsProvider.notifier).createPlaylist(
                    title,
                    descController.text.trim(),
                  );
              if (trackToAdd != null) {
                final updated = ref.read(userPlaylistsProvider);
                if (updated.isNotEmpty) {
                  ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist(updated.last.id, trackToAdd);
                }
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Created playlist "$title"'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

/// Quality selector bottom sheet
void showQualitySheet(BuildContext context, WidgetRef ref) {
  final current = ref.watch(audioQualityWifiProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const Text(
              'Streaming Audio Quality',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ...AudioQuality.values.map((q) {
              final isSelected = q == current;
              String label;
              String sub;
              switch (q) {
                case AudioQuality.lossless:
                  label = 'Lossless (Hi-Res)';
                  sub = 'FLAC / 320 kbps CD quality';
                  break;
                case AudioQuality.high:
                  label = 'High Quality';
                  sub = 'AAC 160 kbps';
                  break;
                case AudioQuality.medium:
                  label = 'Standard Data Saver';
                  sub = 'Opus 96 kbps';
                  break;
                case AudioQuality.low:
                  label = 'Low / Data Saver';
                  sub = 'Opus 48 kbps';
                  break;
              }

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                selected: isSelected,
                selectedTileColor: AppColors.accent.withValues(alpha: 0.15),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                    : null,
                onTap: () {
                  ref.read(audioQualityWifiProvider.notifier).state = q;
                  ref.read(audioQualityCellularProvider.notifier).state = q;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Audio quality updated to $label'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    ),
  );
}

/// Sleep timer modal sheet
void showSleepTimerSheet(BuildContext context, WidgetRef ref) {
  final current = ref.watch(sleepTimerProvider);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final durations = [
    const Duration(minutes: 15),
    const Duration(minutes: 30),
    const Duration(minutes: 45),
    const Duration(minutes: 60),
    const Duration(minutes: 90),
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.bedtime_outlined, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Sleep Timer',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const Spacer(),
                if (current != null)
                  TextButton(
                    onPressed: () {
                      ref.read(sleepTimerProvider.notifier).cancel();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sleep timer turned off'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Turn Off', style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: durations.map((d) {
                final isSelected = current == d;
                return GestureDetector(
                  onTap: () {
                    ref.read(sleepTimerProvider.notifier).setTimer(d);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Music will pause in ${d.inMinutes} minutes 🌙'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : (isDark ? AppColors.bgDark : AppColors.bgLight),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.6)
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      boxShadow: isSelected
                          ? [
                              ...AppColors.neumorphPressed(isDark, blur: 4, offset: 2),
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ]
                          : AppColors.neumorphRaised(isDark, blur: 5, offset: 2),
                    ),
                    child: Text(
                      '${d.inMinutes} minutes',
                      style: TextStyle(
                        color: isSelected ? AppColors.accentLight : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dedicated Playlist details sheet allowing viewing all tracks, playing, shuffling, and deleting
void showPlaylistDetailSheet(BuildContext context, WidgetRef ref, MusicPlaylist playlist) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        // Watch updated playlist from state
        final allPlaylists = ref.watch(userPlaylistsProvider);
        final currentPl = allPlaylists.firstWhere(
          (p) => p.id == playlist.id,
          orElse: () => playlist,
        );

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141418) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),

                // Playlist Hero Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: currentPl.thumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl: currentPl.thumbnailUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _artFallback(isDark, size: 80),
                              )
                            : _artFallback(isDark, size: 80),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPl.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentPl.trackCount} songs · ${currentPl.description ?? "Playlist"}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentPl.id != 'fav_playlist')
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () {
                            ref.read(userPlaylistsProvider.notifier).deletePlaylist(currentPl.id);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted playlist "${currentPl.title}"'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Play All & Shuffle Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                          onPressed: currentPl.tracks.isEmpty
                              ? null
                              : () {
                                  ref.read(musicPlayerProvider.notifier).playTrack(
                                        currentPl.tracks.first,
                                        queue: currentPl.tracks,
                                        index: 0,
                                      );
                                  Navigator.pop(ctx);
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('Shuffle'),
                          onPressed: currentPl.tracks.isEmpty
                              ? null
                              : () {
                                  final shuffled = List<MusicTrack>.from(currentPl.tracks)..shuffle();
                                  ref.read(musicPlayerProvider.notifier).playTrack(
                                        shuffled.first,
                                        queue: shuffled,
                                        index: 0,
                                      );
                                  Navigator.pop(ctx);
                                },
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Track list
                Expanded(
                  child: currentPl.tracks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.music_note_outlined,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No songs in this playlist yet',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Use the 3-dots menu on any song to add it here',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: currentPl.tracks.length,
                          itemBuilder: (context, index) {
                            final track = currentPl.tracks[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: track.albumArtUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: track.albumArtUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => _artFallback(isDark),
                                      )
                                    : _artFallback(isDark),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white38, size: 20),
                                    onPressed: () {
                                      ref.read(userPlaylistsProvider.notifier).removeTrackFromPlaylist(
                                            currentPl.id,
                                            track.id,
                                          );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onPressed: () => showTrackOptionsSheet(context, ref, track),
                                  ),
                                ],
                              ),
                              onTap: () {
                                ref.read(musicPlayerProvider.notifier).playTrack(
                                      track,
                                      queue: currentPl.tracks,
                                      index: index,
                                    );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget _artFallback(bool isDark, {double size = 44}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF222228) : const Color(0xFFE5E5EA),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.music_note, color: isDark ? Colors.white38 : Colors.black38, size: size * 0.5),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
