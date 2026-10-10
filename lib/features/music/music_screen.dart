import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/music_models.dart';
import '../../ui/widgets/glass_app_bar.dart';
import 'music_action_sheets.dart';
import 'music_providers.dart';
import 'now_playing_screen.dart';

/// Music browse screen — the "Music" tab
class MusicScreen extends ConsumerWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Music'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: _MusicContent(),
    );
  }

  void _openSearch(BuildContext context, [String? initialQuery]) {
    showSearch(context: context, delegate: _MusicSearchDelegate(initialQuery: initialQuery));
  }
}

class _MusicContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsAndSinglesProvider);
    final trendingAsync = ref.watch(trendingTracksProvider);
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final playlistsAsync = ref.watch(featuredPlaylistsProvider);
    final playerState = ref.watch(musicPlayerProvider);
    final selectedGenre = ref.watch(selectedGenreProvider);

    return ListView(
      padding: EdgeInsets.only(
        bottom: playerState.hasTrack ? 180 : 120,
      ),
      children: [
        const SizedBox(height: 8),

        // ── Genre / Category Pills (Frosted Glass & Interactive) ──
        const _GenreChipsRow(),
        const SizedBox(height: 16),

        // ── Now Playing Hero (if playing) ──
        if (playerState.hasTrack) ...[
          _NowPlayingHero(state: playerState),
          const SizedBox(height: 20),
        ],

        // ── Categorized Content by Selected Chip ──
        if (selectedGenre == 'All') ...[
          // Priority 1: User Playlists & Liked Songs Section
          const _UserPlaylistsSection(),
          const SizedBox(height: 24),

          // Priority 2: Albums & singles (Matching User Screenshot Layout)
          _SectionHeader(title: 'Albums & singles', icon: Icons.album),
          albumsAsync.when(
            data: (albums) => _AlbumsAndSinglesRow(albums: albums),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),

          // Priority 3: Trending Hits Section
          _SectionHeader(title: 'Trending Hits', icon: Icons.trending_up),
          trendingAsync.when(
            data: (tracks) => _HorizontalTrackList(tracks: tracks),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),

          // Priority 4: Featured Multi-Genre Playlists
          _SectionHeader(title: 'Featured Playlists', icon: Icons.queue_music),
          playlistsAsync.when(
            data: (playlists) => _PlaylistGrid(playlists: playlists),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),

          // Priority 5: Quick Picks / Worldwide Catalog
          _SectionHeader(title: 'Quick Picks', icon: Icons.bolt),
          recentAsync.when(
            data: (tracks) => _VerticalTrackList(tracks: tracks),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          const SizedBox(height: 24),

          // Hi-Res Audio Banner
          _AudioQualityBanner(),
        ] else if (selectedGenre == 'Playlists') ...[
          const _UserPlaylistsSection(),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Featured Playlists', icon: Icons.queue_music),
          playlistsAsync.when(
            data: (playlists) => _PlaylistGrid(playlists: playlists),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ] else if (selectedGenre == 'Trending') ...[
          _SectionHeader(title: 'Trending Hits Worldwide', icon: Icons.trending_up),
          trendingAsync.when(
            data: (tracks) => _VerticalTrackList(tracks: tracks),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ] else if (selectedGenre == 'Albums') ...[
          _SectionHeader(title: 'Albums & Singles Catalog', icon: Icons.album),
          albumsAsync.when(
            data: (albums) => _AlbumsAndSinglesRow(albums: albums),
            loading: () => const _SkeletonRow(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ] else ...[
          // Specific Genre Feed (Punjabi, Pop, Hip-Hop, Anime, Lo-Fi, Rock)
          _GenreFeedSection(genre: selectedGenre),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Category / Genre Chips Row (True Liquid Glass Styling)
// ═══════════════════════════════════════════════════════════════════

class _GenreChipsRow extends ConsumerWidget {
  const _GenreChipsRow();

  static const _genres = [
    'All',
    'Trending',
    'Albums',
    'Playlists',
    'Punjabi',
    'Pop',
    'Hip-Hop',
    'Anime',
    'Lo-Fi',
    'Rock',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGenreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = _genres[index];
          final isSelected = genre == selected;

          return GestureDetector(
            onTap: () {
              ref.read(selectedGenreProvider.notifier).state = genre;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                // Liquid glass pill when selected: subtle primary glow, NO solid white!
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.28)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10)),
                  width: isSelected ? 1.2 : 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  genre,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Albums & Singles Row (Matching Screenshot)
// ═══════════════════════════════════════════════════════════════════

class _AlbumsAndSinglesRow extends ConsumerWidget {
  final List<MusicAlbumItem> albums;
  const _AlbumsAndSinglesRow({required this.albums});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: albums.length,
        itemBuilder: (context, index) {
          final album = albums[index];
          return GestureDetector(
            onTap: () => _openAlbumDetails(context, ref, album),
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: album.thumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl: album.thumbnailUrl!,
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 150,
                                  height: 150,
                                  color: AppColors.cardDark,
                                  child: const Icon(Icons.album, size: 40),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 150,
                                  height: 150,
                                  color: AppColors.cardDark,
                                  child: const Icon(Icons.album, size: 40),
                                ),
                              )
                            : Container(
                                width: 150,
                                height: 150,
                                color: AppColors.cardDark,
                                child: const Icon(Icons.album, size: 40),
                              ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.7),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.play_arrow, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${album.artist} • ${album.type}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
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

  void _openAlbumDetails(BuildContext context, WidgetRef ref, MusicAlbumItem album) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        minChildSize: 0.35,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    if (album.thumbnailUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: album.thumbnailUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text('${album.artist} • ${album.type} • ${album.year ?? ''}'),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Play'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (album.tracks.isNotEmpty) {
                          ref.read(musicPlayerProvider.notifier).playTrack(album.tracks.first, queue: album.tracks);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: album.tracks.length,
                  itemBuilder: (_, i) {
                    final t = album.tracks[i];
                    return ListTile(
                      leading: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      title: Text(t.title),
                      subtitle: Text(t.artist),
                      trailing: const Icon(Icons.play_circle_outline),
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(musicPlayerProvider.notifier).playTrack(t, queue: album.tracks, index: i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Now Playing Hero
// ═══════════════════════════════════════════════════════════════════

class _NowPlayingHero extends ConsumerWidget {
  final NowPlayingState state;
  const _NowPlayingHero({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = state.currentTrack!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useGlass = ref.watch(liquidGlassProvider);
    final intensity = ref.watch(liquidGlassIntensityProvider);
    final opacity = ref.watch(liquidGlassOpacityProvider);

    final glassColor = isDark
        ? const Color(0xFF101014).withValues(alpha: opacity.clamp(0.15, 0.70))
        : Colors.white.withValues(alpha: (opacity * 1.3).clamp(0.20, 0.75));
    final solidColor = isDark ? const Color(0xFF18181C) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NowPlayingScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: useGlass ? intensity : 0.01,
              sigmaY: useGlass ? intensity : 0.01,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: useGlass ? glassColor : solidColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
                gradient: useGlass
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: isDark ? 0.20 : 0.25),
                          Colors.white.withValues(alpha: isDark ? 0.03 : 0.10),
                        ],
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Album art
                  Hero(
                    tag: 'now_playing_hero_art',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: track.albumArtUrl != null
                          ? CachedNetworkImage(
                              imageUrl: track.albumArtUrl!,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 58,
                                height: 58,
                                color: AppColors.cardDark,
                                child: const Icon(Icons.music_note, size: 28),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 58,
                                height: 58,
                                color: AppColors.cardDark,
                                child: const Icon(Icons.music_note, size: 28),
                              ),
                            )
                          : Container(
                              width: 58,
                              height: 58,
                              color: AppColors.cardDark,
                              child: const Icon(Icons.music_note, size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'NOW PLAYING',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    fontSize: 10,
                                  ),
                            ),
                            if (track.isLossless) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LOSSLESS',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          track.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          track.artist,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 12,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Hero Play/Pause button
                  IconButton(
                    icon: Icon(
                      state.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                    onPressed: () {
                      ref.read(musicPlayerProvider.notifier).togglePlayPause();
                    },
                  ),

                  // Hero 3-dots button (Workable)
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white60 : Colors.black54,
                      size: 22,
                    ),
                    onPressed: () => showTrackOptionsSheet(context, ref, track),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Dynamic Genre Feed Section
// ═══════════════════════════════════════════════════════════════════

class _GenreFeedSection extends ConsumerWidget {
  final String genre;
  const _GenreFeedSection({required this.genre});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genreAsync = ref.watch(genreTracksProvider(genre));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '$genre Hits',
          icon: Icons.music_note_rounded,
        ),
        genreAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No tracks found for this category'),
                ),
              );
            }
            return _VerticalTrackList(tracks: tracks);
          },
          loading: () => const _SkeletonRow(),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load $genre hits: $e'),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const _SectionHeader({required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Horizontal Track List (cards)
// ═══════════════════════════════════════════════════════════════════

class _HorizontalTrackList extends ConsumerWidget {
  final List<MusicTrack> tracks;
  const _HorizontalTrackList({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          return _TrackCard(
            track: tracks[index],
            allTracks: tracks,
            index: index,
          );
        },
      ),
    );
  }
}

class _TrackCard extends ConsumerWidget {
  final MusicTrack track;
  final List<MusicTrack> allTracks;
  final int index;

  const _TrackCard({
    required this.track,
    required this.allTracks,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(musicPlayerProvider.notifier).playTrack(
              track,
              queue: allTracks,
              index: index,
            );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art with quality badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: track.albumArtUrl != null
                      ? CachedNetworkImage(
                          imageUrl: track.albumArtUrl!,
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _artPlaceholder(),
                          errorWidget: (_, __, ___) => _artPlaceholder(),
                        )
                      : _artPlaceholder(),
                ),
                // Glass overlay with play icon on hover
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Colors.transparent, Color(0x66000000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Quality badge
                if (track.isLossless)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hd,
                            size: 12,
                            color: AppColors.primary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            track.codec ?? 'FLAC',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Play button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _artPlaceholder() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.music_note, size: 40, color: AppColors.primary),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Playlist Grid
// ═══════════════════════════════════════════════════════════════════

class _PlaylistGrid extends ConsumerWidget {
  final List<MusicPlaylist> playlists;
  const _PlaylistGrid({required this.playlists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final pl = playlists[index];
          return GestureDetector(
            onTap: () {
              if (pl.tracks.isNotEmpty) {
                ref.read(musicPlayerProvider.notifier).playTrack(
                      pl.tracks.first,
                      queue: pl.tracks,
                      index: 0,
                    );
              }
            },
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                border: Border.all(
                  color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  // Playlist art
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    child: pl.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: pl.thumbnailUrl!,
                            width: 100,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 100,
                              height: 120,
                              color: AppColors.cardDark,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 100,
                              height: 120,
                              color: AppColors.cardDark,
                              child: const Icon(Icons.queue_music, size: 32),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 120,
                            color: AppColors.cardDark,
                            child: const Icon(Icons.queue_music, size: 32),
                          ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pl.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pl.trackCount} tracks',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'PLAY ALL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

// ═══════════════════════════════════════════════════════════════════
// User Playlists Section (Music Only)
// ═══════════════════════════════════════════════════════════════════

class _UserPlaylistsSection extends ConsumerWidget {
  const _UserPlaylistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPlaylists = ref.watch(userPlaylistsProvider);
    final likedIds = ref.watch(likedSongsProvider);

    final favPlaylist = userPlaylists.firstWhere(
      (p) => p.id == 'fav_playlist',
      orElse: () => MusicPlaylist(
        id: 'fav_playlist',
        title: 'Liked Songs',
        description: 'Your favorite tracks',
        trackCount: likedIds.length,
        tracks: const [],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'My Playlists',
          icon: Icons.library_music_rounded,
          trailing: TextButton.icon(
            onPressed: () => _showCreatePlaylistDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
            label: const Text(
              'New',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 145,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Liked Songs Card
              _LikedSongsCard(
                count: favPlaylist.tracks.isNotEmpty ? favPlaylist.tracks.length : likedIds.length,
                onTap: () => _showPlaylistDetailSheet(context, ref, favPlaylist),
              ),

              // User Created Playlists
              ...userPlaylists.where((p) => p.id != 'fav_playlist').map((playlist) {
                return _PlaylistCard(
                  playlist: playlist,
                  onTap: () => _showPlaylistDetailSheet(context, ref, playlist),
                );
              }),

              // "+ Create Playlist" Card
              _CreatePlaylistCard(
                onTap: () => _showCreatePlaylistDialog(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LikedSongsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _LikedSongsCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE94057).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
            ),
            const Spacer(),
            const Text(
              'Liked Songs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$count ${count == 1 ? "track" : "tracks"}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final MusicPlaylist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: playlist.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: playlist.thumbnailUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 44,
                        height: 44,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(Icons.music_note, color: AppColors.primary, size: 20),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        child: const Icon(Icons.music_note, color: AppColors.primary, size: 20),
                      ),
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.queue_music_rounded, color: AppColors.primary, size: 22),
                    ),
            ),
            const Spacer(),
            Text(
              playlist.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${playlist.trackCount} ${playlist.trackCount == 1 ? "track" : "tracks"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylistCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreatePlaylistCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              'New Playlist',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showPlaylistDetailSheet(BuildContext context, WidgetRef ref, MusicPlaylist playlist) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final allUserPlaylists = ref.watch(userPlaylistsProvider);
        final livePlaylist = allUserPlaylists.firstWhere(
          (p) => p.id == playlist.id,
          orElse: () => playlist,
        );

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141418) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: livePlaylist.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: livePlaylist.thumbnailUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: AppColors.primary.withValues(alpha: 0.2),
                              child: const Icon(Icons.music_note, color: AppColors.primary, size: 36),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            livePlaylist.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            livePlaylist.description ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${livePlaylist.tracks.length} tracks',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: livePlaylist.tracks.isEmpty
                            ? null
                            : () {
                                ref.read(musicPlayerProvider.notifier).playTrack(
                                      livePlaylist.tracks.first,
                                      queue: livePlaylist.tracks,
                                      index: 0,
                                    );
                                Navigator.pop(ctx);
                              },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: livePlaylist.tracks.isEmpty
                            ? null
                            : () {
                                final shuffled = List<MusicTrack>.from(livePlaylist.tracks)..shuffle();
                                ref.read(musicPlayerProvider.notifier).playTrack(
                                      shuffled.first,
                                      queue: shuffled,
                                      index: 0,
                                    );
                                Navigator.pop(ctx);
                              },
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                if (livePlaylist.tracks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.playlist_remove_rounded, size: 54, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          const Text(
                            'No songs in this playlist yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the ⋯ options menu on any song to add it here.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...livePlaylist.tracks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final trk = entry.value;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: trk.albumArtUrl != null
                            ? CachedNetworkImage(
                                imageUrl: trk.albumArtUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: AppColors.cardDark,
                                child: const Icon(Icons.music_note, size: 20),
                              ),
                      ),
                      title: Text(
                        trk.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        trk.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        onPressed: () {
                          ref
                              .read(userPlaylistsProvider.notifier)
                              .removeTrackFromPlaylist(livePlaylist.id, trk.id);
                        },
                      ),
                      onTap: () {
                        ref.read(musicPlayerProvider.notifier).playTrack(
                              trk,
                              queue: livePlaylist.tracks,
                              index: idx,
                            );
                        Navigator.pop(ctx);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref, {MusicTrack? trackToAdd}) {
  final textController = TextEditingController();
  final descController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Create Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Playlist Name',
              hintText: 'e.g. Punjabi Hits, Chill Lo-Fi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final title = textController.text.trim();
            if (title.isNotEmpty) {
              ref.read(userPlaylistsProvider.notifier).createPlaylist(title, descController.text.trim());
              if (trackToAdd != null) {
                final updated = ref.read(userPlaylistsProvider);
                if (updated.isNotEmpty) {
                  ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist(updated.last.id, trackToAdd);
                }
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Created playlist "$title"')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

void _showAddToPlaylistSheet(BuildContext context, WidgetRef ref, MusicTrack track) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final playlists = ref.watch(userPlaylistsProvider);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Add to Playlist',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppColors.primary),
                  ),
                  title: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreatePlaylistDialog(context, ref, trackToAdd: track);
                  },
                ),
                ...playlists.map((pl) {
                  final containsTrack = pl.tracks.any((t) => t.id == track.id);
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: pl.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: pl.thumbnailUrl!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: const Icon(Icons.music_note, size: 20),
                            ),
                    ),
                    title: Text(pl.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${pl.trackCount} tracks', style: const TextStyle(fontSize: 12)),
                    trailing: containsTrack
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                        : null,
                    onTap: () {
                      if (containsTrack) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Already in ${pl.title}')),
                        );
                      } else {
                        ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist(pl.id, track);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added "${track.title}" to ${pl.title}')),
                        );
                      }
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// Vertical Track List
// ═══════════════════════════════════════════════════════════════════

class _VerticalTrackList extends ConsumerWidget {
  final List<MusicTrack> tracks;
  const _VerticalTrackList({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: tracks.asMap().entries.map((entry) {
        final index = entry.key;
        final track = entry.value;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.albumArtUrl != null
                ? CachedNetworkImage(
                    imageUrl: track.albumArtUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 50,
                      height: 50,
                      color: AppColors.cardDark,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: AppColors.cardDark,
                      child: const Icon(Icons.music_note),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: AppColors.cardDark,
                    child: const Icon(Icons.music_note),
                  ),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Row(
            children: [
              if (track.id.startsWith('yt_') || track.codec == 'YouTube Music') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'YT MUSIC',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ] else if (track.isLossless) ...[
                Icon(Icons.hd, size: 14, color: AppColors.primary.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '  ·  ${_formatDuration(track.duration)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () => _showTrackOptions(context, ref, track),
          ),
          onTap: () {
            ref.read(musicPlayerProvider.notifier).playTrack(
                  track,
                  queue: tracks,
                  index: index,
                );
          },
        );
      }).toList(),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showTrackOptions(BuildContext context, WidgetRef ref, MusicTrack track) {
    final isLiked = ref.read(likedSongsProvider).contains(track.id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? Colors.redAccent : null,
              ),
              title: Text(isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs'),
              onTap: () {
                ref.read(likedSongsProvider.notifier).toggleLike(track.id);
                if (isLiked) {
                  ref.read(userPlaylistsProvider.notifier).removeTrackFromPlaylist('fav_playlist', track.id);
                } else {
                  ref.read(userPlaylistsProvider.notifier).addTrackToPlaylist('fav_playlist', track);
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isLiked ? 'Removed "${track.title}" from Liked Songs' : 'Saved "${track.title}" to Liked Songs'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylistSheet(context, ref, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to Queue'),
              onTap: () {
                ref.read(musicPlayerProvider.notifier).addToQueue(track);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${track.title} added to queue')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download'),
              subtitle: Text(track.isLossless ? 'FLAC · ~35 MB' : 'Opus · ~8 MB'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading ${track.title}...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Audio Quality Banner
// ═══════════════════════════════════════════════════════════════════

class _AudioQualityBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark.withValues(alpha: 0.3),
            AppColors.accent.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.hd, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi-Res Lossless Audio',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'FLAC/ALAC streaming from configured sources',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Skeleton Loading Row
// ═══════════════════════════════════════════════════════════════════

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Music Search Delegate
// ═══════════════════════════════════════════════════════════════════

class _MusicSearchDelegate extends SearchDelegate<String> {
  final String? initialQuery;

  _MusicSearchDelegate({this.initialQuery}) {
    if (initialQuery != null) {
      query = initialQuery!;
    }
  }

  @override
  String get searchFieldLabel => 'Search any song, artist, YouTube Music...';

  static const _popularSearches = [
    'Karan Aujla',
    'Tame Impala',
    'The Weeknd',
    'Arijit Singh',
    'Travis Scott',
    'Taylor Swift',
    'Diljit Dosanjh',
    'YOASOBI',
    'Demon Slayer',
    'Lo-Fi Beats',
  ];

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Trending Searches',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.map((s) {
              return ActionChip(
                label: Text(s),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () {
                  query = s;
                  showResults(context);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.youtube_searched_for, size: 48, color: AppColors.primary.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(
                  'Search millions of tracks across YouTube Music & 320kbps catalog',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        if (query.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        final searchAsync = ref.watch(musicSearchProvider(query));
        return searchAsync.when(
          data: (tracks) {
            if (tracks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No results found for "$query". Try searching for artist, track or album.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _VerticalTrackList(tracks: tracks);
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
    );
  }
}
