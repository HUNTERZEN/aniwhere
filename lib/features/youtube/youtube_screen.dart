import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/services/settings_storage.dart';
import '../auth/auth_service.dart';
import '../auth/sign_in_screen.dart';
import '../music/music_providers.dart';
import 'youtube_service.dart';
import 'youtube_stream_proxy.dart';

// ============================================================================
// Global YouTube State Providers
// ============================================================================

final youtubeServiceProvider = Provider<YouTubeService>((ref) {
  return YouTubeService();
});

final selectedYouTubeCategoryProvider = StateProvider<String>((ref) => 'All');

final youtubeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Currently active video in the YouTube player overlay (`null` when closed).
final activeYouTubeVideoProvider = StateProvider<YouTubeVideoItem?>((ref) => null);

/// `true` when the YouTube overlay is expanded (fullscreen), `false` when minimized to the floating PiP MiniPlayer.
final isYouTubePlayerExpandedProvider = StateProvider<bool>((ref) => true);

/// Continuous expansion progress (`0.0` = floating PiP MiniPlayer, `1.0` = full player).
final ytExpandProgressProvider = StateProvider<double>((ref) => 0.0);

/// Subscribed channel names persisted locally.
final subscribedChannelsProvider =
    StateNotifierProvider<SubscribedChannelsNotifier, Set<String>>((ref) {
  return SubscribedChannelsNotifier();
});

class SubscribedChannelsNotifier extends StateNotifier<Set<String>> {
  static const _kKey = 'yt_subscribed_channels';
  SubscribedChannelsNotifier() : super(_load());

  static Set<String> _load() {
    final raw = SettingsStorage.getString(_kKey);
    if (raw.isEmpty) return {};
    return raw.split('|').where((s) => s.isNotEmpty).toSet();
  }

  void toggle(String channelName) {
    final next = Set<String>.from(state);
    if (!next.remove(channelName)) {
      next.add(channelName);
    }
    state = next;
    SettingsStorage.setString(_kKey, next.join('|'));
  }
}

/// Liked YouTube video IDs persisted locally.
final likedYouTubeVideosProvider =
    StateNotifierProvider<LikedYouTubeVideosNotifier, Set<String>>((ref) {
  return LikedYouTubeVideosNotifier();
});

class LikedYouTubeVideosNotifier extends StateNotifier<Set<String>> {
  static const _kKey = 'yt_liked_video_ids';
  LikedYouTubeVideosNotifier() : super(_load());

  static Set<String> _load() {
    final raw = SettingsStorage.getString(_kKey);
    if (raw.isEmpty) return {};
    return raw.split('|').where((s) => s.isNotEmpty).toSet();
  }

  void toggle(String videoId) {
    final next = Set<String>.from(state);
    if (!next.remove(videoId)) {
      next.add(videoId);
    }
    state = next;
    SettingsStorage.setString(_kKey, next.join('|'));
  }
}

/// Saved / Watch Later YouTube video IDs.
final savedYouTubeVideosProvider =
    StateNotifierProvider<SavedYouTubeVideosNotifier, Set<String>>((ref) {
  return SavedYouTubeVideosNotifier();
});

class SavedYouTubeVideosNotifier extends StateNotifier<Set<String>> {
  static const _kKey = 'yt_saved_video_ids';
  SavedYouTubeVideosNotifier() : super(_load());

  static Set<String> _load() {
    final raw = SettingsStorage.getString(_kKey);
    if (raw.isEmpty) return {};
    return raw.split('|').where((s) => s.isNotEmpty).toSet();
  }

  void toggle(String videoId) {
    final next = Set<String>.from(state);
    if (!next.remove(videoId)) {
      next.add(videoId);
    }
    state = next;
    SettingsStorage.setString(_kKey, next.join('|'));
  }
}

// ============================================================================
// Reusable Frosted Glass UI Components (Matching Screenshot 1 & Screenshot 3)
// ============================================================================

/// Circular frosted glass button used on the video player overlay and sheet headers (Screenshot 1 & 3).
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.38),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass bottom sheet wrapper matching Screenshot 3 ("Playback Settings" & 3-dot pop-out menus).
Future<T?> showFrostedGlassBottomSheet<T>({
  required BuildContext context,
  required String title,
  Widget? headerSubtitle,
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final maxH = MediaQuery.of(ctx).size.height * 0.82;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.62)
                    : Colors.white.withValues(alpha: 0.82),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.10),
                    width: 1.0,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    // Top drag handle pill
                    Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.black26,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sheet Header + Circular Frosted Close Button (matching Screenshot 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (headerSubtitle != null) ...[
                                  const SizedBox(height: 2),
                                  headerSubtitle,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.07),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: children,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Individual frosted glass option pill button inside a pop-out bottom sheet (Screenshot 3).
class _GlassSheetOptionPill extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassSheetOptionPill({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const lavenderAccent = Color(0xFFB39DDB);
    final effectiveIconColor = iconColor ?? lavenderAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? effectiveIconColor.withValues(alpha: isDark ? 0.18 : 0.14)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? effectiveIconColor.withValues(alpha: 0.45)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.07)),
                width: 0.9,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: effectiveIconColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailingText!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: effectiveIconColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Main Ad-Free YouTube Home Screen (Tab 0 - Matching Screenshot 2)
// ============================================================================

class YouTubeScreen extends ConsumerStatefulWidget {
  const YouTubeScreen({super.key});

  @override
  ConsumerState<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends ConsumerState<YouTubeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  bool _isLoading = true;
  List<YouTubeVideoItem> _videos = YouTubeService.fallbackVideos;
  List<String> _suggestions = [];
  Timer? _debounce;

  static const List<String> _categories = [
    'All',
    'Today',
    'Videos',
    'Subscribed',
    'Watched',
    'Liked',
    'Music',
    'Anime',
    'Gaming',
    '4K UHD',
  ];

  @override
  void initState() {
    super.initState();
    _loadFeed('All');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadFeed(String category) async {
    setState(() => _isLoading = true);
    final service = ref.read(youtubeServiceProvider);
    final items = await service.getCategoryFeed(category);
    if (!mounted) return;
    setState(() {
      _videos = items.isNotEmpty ? items : YouTubeService.fallbackVideos;
      _isLoading = false;
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _suggestions = []);
      _loadFeed(ref.read(selectedYouTubeCategoryProvider));
      return;
    }
    setState(() {
      _isLoading = true;
      _suggestions = [];
    });
    final service = ref.read(youtubeServiceProvider);
    final results = await service.searchVideos(trimmed);
    if (!mounted) return;
    setState(() {
      _videos = results.isNotEmpty ? results : YouTubeService.fallbackVideos;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () async {
      if (!mounted) return;
      if (val.trim().isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final s = await ref.read(youtubeServiceProvider).getSearchSuggestions(val);
      if (mounted && _isSearching) {
        setState(() => _suggestions = s);
      }
    });
  }

  void _openVideo(YouTubeVideoItem video, {bool startInMiniPlayer = false}) {
    HapticFeedback.lightImpact();
    // Pause music player when opening a YouTube video
    ref.read(musicPlayerProvider.notifier).pause();
    ref.read(activeYouTubeVideoProvider.notifier).state = video;
    ref.read(isYouTubePlayerExpandedProvider.notifier).state = !startInMiniPlayer;
    ref.read(ytExpandProgressProvider.notifier).state = startInMiniPlayer ? 0.0 : 1.0;
  }

  Future<void> _openGoogleSignIn() async {
    final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const YtMusicSignInScreen()),
    );
    if (ok == true && mounted) {
      await ref.read(youtubeServiceProvider).ensureFreshCookies();
      _loadFeed(ref.read(selectedYouTubeCategoryProvider));
    }
  }

  void _showAccountSheet() {
    final auth = ref.read(ytMusicAuthProvider);
    final isSignedIn = auth.isSignedIn || ref.read(youtubeServiceProvider).isSignedIn;
    final accountName = auth.account?.name ?? (isSignedIn ? 'Google Account' : 'Not Signed In');
    final accountHandle =
        auth.account?.handle ?? (isSignedIn ? 'Synced with YouTube & Music' : 'Sign in to load your subscriptions & watch history');

    showFrostedGlassBottomSheet(
      context: context,
      title: 'YouTube Account',
      children: [
        _GlassSheetOptionPill(
          icon: isSignedIn ? Icons.verified_user_rounded : Icons.account_circle_outlined,
          iconColor: isSignedIn ? Colors.greenAccent : null,
          title: accountName,
          subtitle: accountHandle,
          trailingText: isSignedIn ? 'Active' : 'Sign In',
          onTap: () {
            Navigator.pop(context);
            if (!isSignedIn) {
              _openGoogleSignIn();
            }
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.subscriptions_rounded,
          title: 'Your Subscriptions',
          subtitle: 'Load latest uploads from channels you subscribe to',
          onTap: () {
            Navigator.pop(context);
            ref.read(selectedYouTubeCategoryProvider.notifier).state = 'Subscribed';
            _loadFeed('Subscribed');
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.history_rounded,
          title: 'Watched History',
          subtitle: 'Videos your Google account has watched',
          onTap: () {
            Navigator.pop(context);
            ref.read(selectedYouTubeCategoryProvider.notifier).state = 'Watched';
            _loadFeed('Watched');
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.thumb_up_alt_rounded,
          title: 'Liked Videos',
          subtitle: 'Videos liked on your Google account',
          onTap: () {
            Navigator.pop(context);
            ref.read(selectedYouTubeCategoryProvider.notifier).state = 'Liked';
            _loadFeed('Liked');
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.sync_rounded,
          title: isSignedIn ? 'Refresh Account Feed' : 'Sign in with Google',
          subtitle: isSignedIn
              ? 'Re-sync subscriptions, history & playlists'
              : 'Sync your Google account across YouTube & Music',
          onTap: () async {
            Navigator.pop(context);
            if (isSignedIn) {
              await ref.read(youtubeServiceProvider).ensureFreshCookies();
              _loadFeed(ref.read(selectedYouTubeCategoryProvider));
            } else {
              _openGoogleSignIn();
            }
          },
        ),
      ],
    );
  }

  void _showVideoThreeDotSheet(YouTubeVideoItem video) {
    final isSaved = ref.read(savedYouTubeVideosProvider).contains(video.videoId);
    final isLiked = ref.read(likedYouTubeVideosProvider).contains(video.videoId);
    final isSubbed = ref.read(subscribedChannelsProvider).contains(video.channelName);

    showFrostedGlassBottomSheet(
      context: context,
      title: video.title,
      headerSubtitle: Text(
        '${video.channelName} · ${video.viewCountText}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: Colors.white60),
      ),
      children: [
        _GlassSheetOptionPill(
          icon: Icons.play_circle_fill_rounded,
          title: 'Play Video (Up to 4K UHD)',
          subtitle: 'Open in ad-free fullscreen player',
          onTap: () {
            Navigator.pop(context);
            _openVideo(video);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.picture_in_picture_alt_rounded,
          title: 'Play in Floating MiniPlayer',
          subtitle: 'Keep browsing while watching in corner window',
          onTap: () {
            Navigator.pop(context);
            _openVideo(video, startInMiniPlayer: true);
          },
        ),
        _GlassSheetOptionPill(
          icon: isSaved ? Icons.watch_later_rounded : Icons.watch_later_outlined,
          title: isSaved ? 'Remove from Watch Later' : 'Save to Watch Later',
          subtitle: 'Bookmark this video in your library',
          trailingText: isSaved ? 'Saved' : null,
          onTap: () {
            ref.read(savedYouTubeVideosProvider.notifier).toggle(video.videoId);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isSaved ? 'Removed from Watch Later' : 'Saved to Watch Later',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        _GlassSheetOptionPill(
          icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
          title: isLiked ? 'Liked Video' : 'Like Video',
          subtitle: 'Add to your liked videos',
          onTap: () {
            ref.read(likedYouTubeVideosProvider.notifier).toggle(video.videoId);
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: isSubbed
              ? Icons.notifications_active_rounded
              : Icons.person_add_alt_1_rounded,
          title: isSubbed
              ? 'Subscribed to ${video.channelName}'
              : 'Subscribe to ${video.channelName}',
          subtitle: 'Follow channel uploads',
          onTap: () {
            ref.read(subscribedChannelsProvider.notifier).toggle(video.channelName);
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.share_rounded,
          title: 'Share Video',
          subtitle: 'Copy https://youtu.be/${video.videoId}',
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: 'https://youtu.be/${video.videoId}'),
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video link copied to clipboard'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCategory = ref.watch(selectedYouTubeCategoryProvider);
    final auth = ref.watch(ytMusicAuthProvider);
    final isSignedIn = auth.isSignedIn || ref.read(youtubeServiceProvider).isSignedIn;

    // Reload automatically when Google sign-in state changes
    ref.listen<YtMusicAuthState>(ytMusicAuthProvider, (prev, next) {
      if (prev?.cookie != next.cookie) {
        _loadFeed(ref.read(selectedYouTubeCategoryProvider));
      }
    });

    final bgColor = isDark ? Colors.black : const Color(0xFFF7F7FA);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top AppBar matching Screenshot 2 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _isSearching
                  ? _buildSearchBar(isDark, textColor)
                  : Row(
                      children: [
                        // Red rounded-square YouTube play badge + Bold Title (Screenshot 2)
                        Container(
                          width: 36,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE52D27),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'YouTube',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        // Circular dark glass Search button (Screenshot 2)
                        GestureDetector(
                          onTap: () {
                            setState(() => _isSearching = true);
                            Future.microtask(() => _searchFocus.requestFocus());
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            child: Icon(
                              Icons.search_rounded,
                              color: textColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Circular Google Account Avatar button (Screenshot 2)
                        GestureDetector(
                          onTap: _showAccountSheet,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSignedIn
                                  ? const Color(0xFF264653)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.08)),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.black.withValues(alpha: 0.12),
                                width: 1.4,
                              ),
                            ),
                            child: ClipOval(
                              child: auth.account?.photoUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: auth.account!.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Center(
                                        child: Text(
                                          (auth.account?.name ?? 'G')[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        isSignedIn
                                            ? (auth.account?.name ?? 'G')[0].toUpperCase()
                                            : 'G',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // ── Category Filter Chips matching Screenshot 2 (`All`, `Today`, `Videos`, `Subscribed`, ...) ──
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == selectedCategory && !_isSearching;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedYouTubeCategoryProvider.notifier).state = cat;
                      if (_isSearching) {
                        setState(() {
                          _isSearching = false;
                          _suggestions = [];
                        });
                      }
                      _loadFeed(cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                ? const Color(0xFF1E1E22)
                                : Colors.black.withValues(alpha: 0.07)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Live Autocomplete Suggestions or Video Feed ──
            if (_isSearching && _suggestions.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final s = _suggestions[index];
                    return ListTile(
                      leading: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      title: Text(
                        s,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Icons.north_west_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      onTap: () {
                        _searchController.text = s;
                        _searchFocus.unfocus();
                        _performSearch(s);
                      },
                    );
                  },
                ),
              )
            else
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE52D27),
                          strokeWidth: 2.8,
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFFE52D27),
                        onRefresh: () => _isSearching &&
                                _searchController.text.trim().isNotEmpty
                            ? _performSearch(_searchController.text)
                            : _loadFeed(selectedCategory),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 150),
                          itemCount: _videos.length,
                          itemBuilder: (context, index) {
                            final video = _videos[index];
                            return _YouTubeFeedCard(
                              video: video,
                              isDark: isDark,
                              onTap: () => _openVideo(video),
                              onMoreTap: () => _showVideoThreeDotSheet(video),
                            );
                          },
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color textColor) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _suggestions = [];
              _searchController.clear();
            });
            _loadFeed(ref.read(selectedYouTubeCategoryProvider));
          },
        ),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(21),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(color: textColor, fontSize: 15),
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search YouTube (4K, channels, songs)...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14.5,
                ),
                border: InputBorder.none,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Edge-to-Edge YouTube Feed Video Card matching Screenshot 2.
class _YouTubeFeedCard extends StatelessWidget {
  final YouTubeVideoItem video;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _YouTubeFeedCard({
    required this.video,
    required this.isDark,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.white60 : Colors.black54;

    final metaParts = <String>[
      video.channelName,
      if (video.viewCountText.isNotEmpty) video.viewCountText,
      if (video.publishedTimeText.isNotEmpty) video.publishedTimeText,
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Edge-to-Edge 16:9 Thumbnail with Duration Badge (Screenshot 2)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: isDark ? const Color(0xFF141418) : Colors.black12,
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: isDark ? const Color(0xFF141418) : Colors.black12,
                      child: const Icon(
                        Icons.play_circle_outline_rounded,
                        color: Colors.white38,
                        size: 42,
                      ),
                    ),
                  ),
                  if (video.durationText.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: video.isLive
                              ? const Color(0xFFE52D27)
                              : Colors.black.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          video.durationText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Metadata Row + 3-Dot Button (Screenshot 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel Avatar
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    backgroundImage: video.channelAvatarUrl != null
                        ? CachedNetworkImageProvider(video.channelAvatarUrl!)
                        : null,
                    child: video.channelAvatarUrl == null
                        ? Text(
                            video.channelName.isNotEmpty
                                ? video.channelName[0].toUpperCase()
                                : 'Y',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    onPressed: onMoreTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Seamless Draggable YouTube Player Overlay (Fullscreen <-> Floating PiP Corner Window)
// ============================================================================

class YouTubeDraggablePlayerOverlay extends ConsumerStatefulWidget {
  final double bottomNavOffset;

  const YouTubeDraggablePlayerOverlay({
    super.key,
    required this.bottomNavOffset,
  });

  @override
  ConsumerState<YouTubeDraggablePlayerOverlay> createState() =>
      _YouTubeDraggablePlayerOverlayState();
}

class _YouTubeDraggablePlayerOverlayState
    extends ConsumerState<YouTubeDraggablePlayerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expandController;

  // Single media_kit Player instance (prevents multi-Player AudioTrack/MediaCodec contention!)
  Player? _videoPlayer;
  VideoController? _videoController;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;

  YouTubeVideoItem? _loadedVideo;
  YouTubeResolvedVideo? _resolvedData;
  YouTubeWatchNextData? _watchNextData;
  YouTubeQualityStream? _selectedQuality;

  bool _isResolving = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isLooping = false;
  bool _autoplayNext = true;
  bool _captionsEnabled = false;
  BoxFit _videoFit = BoxFit.contain;
  double _videoZoom = 1.0;
  double _playbackSpeed = 1.0;

  Duration _position = Duration.zero;
  Duration _duration = const Duration(minutes: 3);
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    )..addListener(() {
        setState(() {});
        final v = _expandController.value.clamp(0.0, 1.0);
        if ((ref.read(ytExpandProgressProvider) - v).abs() > 0.04 ||
            v == 0.0 ||
            v == 1.0) {
          Future.microtask(() {
            if (mounted) {
              ref.read(ytExpandProgressProvider.notifier).state = v;
            }
          });
        }
      });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _disposePlayer();
    _expandController.dispose();
    super.dispose();
  }

  void _ensurePlayerInitialized() {
    if (_videoPlayer != null) return;
    _videoPlayer = Player();
    _videoController = VideoController(_videoPlayer!);

    _posSub = _videoPlayer!.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _videoPlayer!.stream.duration.listen((dur) {
      if (mounted && dur.inSeconds > 0) setState(() => _duration = dur);
    });
    _playingSub = _videoPlayer!.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _bufferingSub = _videoPlayer!.stream.buffering.listen((buf) {
      if (mounted) setState(() => _isBuffering = buf);
    });
    _completedSub = _videoPlayer!.stream.completed.listen((done) {
      if (done && mounted) {
        if (_isLooping) {
          _videoPlayer?.seek(Duration.zero);
          _videoPlayer?.play();
        } else if (_autoplayNext &&
            _resolvedData != null &&
            _resolvedData!.relatedVideos.isNotEmpty) {
          final nextVid = _resolvedData!.relatedVideos.first;
          ref.read(activeYouTubeVideoProvider.notifier).state = nextVid;
        }
      }
    });
  }

  void _disposePlayer() {
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
  }

  Future<void> _loadAndPlayVideo(YouTubeVideoItem video) async {
    _ensurePlayerInitialized();
    _loadedVideo = video;
    setState(() {
      _isResolving = true;
      _hasError = false;
      _resolvedData = null;
      _watchNextData = null;
      _selectedQuality = null;
      _position = Duration.zero;
      _duration = Duration(seconds: video.estimatedDurationSeconds);
    });

    await _videoPlayer?.stop();

    final service = ref.read(youtubeServiceProvider);

    // Fetch comments and recommendations in background without delaying video start
    service.fetchWatchNextAndComments(
      videoId: video.videoId,
      channelName: video.channelName,
      title: video.title,
    ).then((data) {
      if (mounted && _loadedVideo?.videoId == video.videoId) {
        setState(() => _watchNextData = data);
      }
    });

    final resolved = await service.resolveVideo(video);
    if (!mounted || _loadedVideo?.videoId != video.videoId) return;

    if (resolved.qualities.isEmpty) {
      setState(() {
        _isResolving = false;
        _hasError = true;
      });
      return;
    }

    // Pick fast direct muxed stream first for instant sub-second start, or 1080p/720p adaptive
    YouTubeQualityStream initialStream = resolved.qualities.firstWhere(
      (q) => q.isMuxed && !q.isHls,
      orElse: () => resolved.qualities.firstWhere(
        (q) => q.height <= 1080,
        orElse: () => resolved.qualities.first,
      ),
    );

    setState(() {
      _resolvedData = resolved;
      _selectedQuality = initialStream;
      _isResolving = false;
    });

    await _openQualityStream(initialStream);
    _scheduleHideControls();
  }

  Future<void> _openQualityStream(
    YouTubeQualityStream stream, {
    Duration? resumeAt,
  }) async {
    if (_videoPlayer == null) return;
    try {
      setState(() {
        _selectedQuality = stream;
        _isBuffering = true;
        _hasError = false;
      });

      String playUrl = stream.videoUrl;
      // Route through local chunking proxy for iOS/adaptive streams to avoid HTTP 403 Forbidden
      if (!stream.isMuxed) {
        playUrl = await YouTubeStreamProxy().getProxyUrl(
          remoteUrl: stream.videoUrl,
          userAgent: stream.userAgent,
          totalLength: stream.contentLength,
          mimeType: stream.mimeType,
        );
      }

      await _videoPlayer!.open(
        Media(
          playUrl,
          httpHeaders: {
            'User-Agent': stream.userAgent,
          },
        ),
        play: true,
      );

      // Bind audio track for adaptive streams (1080p, 1440p 2K, 2160p 4K)
      if (!stream.isMuxed &&
          stream.audioUrl != null &&
          stream.audioUrl!.isNotEmpty) {
        await _videoPlayer!.setAudioTrack(AudioTrack.uri(stream.audioUrl!));
      } else {
        await _videoPlayer!.setAudioTrack(AudioTrack.auto());
      }

      await _videoPlayer!.setRate(_playbackSpeed);

      if (resumeAt != null && resumeAt.inSeconds > 1) {
        await Future.delayed(const Duration(milliseconds: 220));
        await _videoPlayer?.seek(resumeAt);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isBuffering = false;
        });
      }
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _minimizeToMiniPlayer() {
    if (_isFullscreen) {
      _exitFullscreen();
    }
    ref.read(isYouTubePlayerExpandedProvider.notifier).state = false;
    _expandController.animateTo(0.0, curve: Curves.easeOutCubic);
  }

  void _expandToFullPlayer() {
    ref.read(isYouTubePlayerExpandedProvider.notifier).state = true;
    _expandController.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _closePlayer() {
    if (_isFullscreen) {
      _exitFullscreen();
    }
    _videoPlayer?.stop();
    _loadedVideo = null;
    ref.read(activeYouTubeVideoProvider.notifier).state = null;
    ref.read(ytExpandProgressProvider.notifier).state = 0.0;
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      setState(() => _isFullscreen = true);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _cycleAspectFit() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  String get _aspectFitLabel {
    if (_videoFit == BoxFit.cover) return 'Zoom to fill';
    if (_videoFit == BoxFit.fill) return 'Stretch';
    return 'Fit to screen';
  }

  /// Shows the Frosted Glass "Playback Settings" Bottom Sheet matching Screenshot 3!
  void _showPlaybackSettingsSheet() {
    final currentQualityBadge = _selectedQuality?.badge ?? 'Auto';
    final formatSummary = _selectedQuality?.formatSummary ?? '1080p · VP9 · Direct';

    showFrostedGlassBottomSheet(
      context: context,
      title: 'Playback Settings',
      children: [
        _GlassSheetOptionPill(
          icon: Icons.hd_rounded,
          title: 'Quality',
          trailingText: currentQualityBadge,
          onTap: () {
            Navigator.pop(context);
            _showQualityPickerSheet();
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.speed_rounded,
          title: 'Playback speed',
          trailingText: _playbackSpeed == 1.0
              ? 'Normal (1.0×)'
              : '$_playbackSpeed×',
          onTap: () {
            Navigator.pop(context);
            _showSpeedPickerSheet();
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.headphones_rounded,
          title: 'Audio track',
          trailingText: 'Original',
          onTap: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Playing original high-bitrate audio track'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.subtitles_rounded,
          title: 'Captions',
          trailingText: _captionsEnabled ? 'English (Auto)' : 'Off',
          onTap: () {
            setState(() => _captionsEnabled = !_captionsEnabled);
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.repeat_rounded,
          title: 'Loop video',
          trailingText: _isLooping ? 'On' : 'Off',
          onTap: () {
            setState(() => _isLooping = !_isLooping);
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.play_circle_filled_rounded,
          title: 'Autoplay',
          trailingText: _autoplayNext ? 'On' : 'Off',
          onTap: () {
            setState(() => _autoplayNext = !_autoplayNext);
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.crop_free_rounded,
          title: 'Video aspect',
          trailingText: _aspectFitLabel,
          onTap: () {
            _cycleAspectFit();
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.zoom_in_rounded,
          title: 'Video zoom',
          trailingText: '${_videoZoom.toStringAsFixed(1)}×',
          onTap: () {
            Navigator.pop(context);
            _showZoomPickerSheet();
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.info_rounded,
          title: 'Video format',
          trailingText: formatSummary,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  void _showQualityPickerSheet() {
    final qualities = _resolvedData?.qualities ?? [];
    showFrostedGlassBottomSheet(
      context: context,
      title: 'Video Quality (Up to 4K)',
      children: [
        if (qualities.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Resolving available qualities...',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ...qualities.map((q) {
            final isSel = _selectedQuality?.label == q.label &&
                _selectedQuality?.isMuxed == q.isMuxed;
            return _GlassSheetOptionPill(
              icon: q.height >= 2160
                  ? Icons.four_k_rounded
                  : (q.height >= 1080 ? Icons.hd_rounded : Icons.sd_rounded),
              title: q.label,
              subtitle: q.formatSummary,
              trailingText: q.badge,
              isSelected: isSel,
              onTap: () {
                Navigator.pop(context);
                _openQualityStream(q, resumeAt: _position);
              },
            );
          }),
      ],
    );
  }

  void _showSpeedPickerSheet() {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showFrostedGlassBottomSheet(
      context: context,
      title: 'Playback Speed',
      children: speeds.map((s) {
        final isSel = (_playbackSpeed - s).abs() < 0.01;
        return _GlassSheetOptionPill(
          icon: Icons.speed_rounded,
          title: s == 1.0 ? 'Normal (1.0×)' : '$s×',
          isSelected: isSel,
          onTap: () {
            setState(() => _playbackSpeed = s);
            _videoPlayer?.setRate(s);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  void _showZoomPickerSheet() {
    const zooms = [1.0, 1.1, 1.25, 1.5, 1.75, 2.0];
    showFrostedGlassBottomSheet(
      context: context,
      title: 'Video Zoom',
      children: zooms.map((z) {
        final isSel = (_videoZoom - z).abs() < 0.01;
        return _GlassSheetOptionPill(
          icon: Icons.zoom_in_rounded,
          title: '${z.toStringAsFixed(2)}×',
          isSelected: isSel,
          onTap: () {
            setState(() => _videoZoom = z);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    final comments = _watchNextData?.comments ?? [];
    final countText = _watchNextData?.commentCountText.isNotEmpty == true
        ? _watchNextData!.commentCountText
        : (comments.isNotEmpty ? '${comments.length}' : '');

    showFrostedGlassBottomSheet(
      context: context,
      title: countText.isNotEmpty ? 'Comments · $countText' : 'Comments',
      children: [
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Text(
                'Loading or no comments available for this video.',
                style: TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
            ),
          )
        else
          ...comments.map((c) => _CommentTile(comment: c)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final totalSecs = d.inSeconds;
    if (totalSecs <= 0) return '0:00';
    final hrs = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    final secs = totalSecs % 60;
    if (hrs > 0) {
      return '$hrs:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final activeVideo = ref.watch(activeYouTubeVideoProvider);

    // Listen for video changes
    ref.listen<YouTubeVideoItem?>(activeYouTubeVideoProvider, (prev, next) {
      if (next != null && next.videoId != _loadedVideo?.videoId) {
        final shouldExpand = ref.read(isYouTubePlayerExpandedProvider);
        _expandController.value = shouldExpand ? 1.0 : 0.0;
        _loadAndPlayVideo(next);
      } else if (next == null) {
        _videoPlayer?.stop();
        _loadedVideo = null;
      }
    });

    // Listen for expand/minimize state changes
    ref.listen<bool>(isYouTubePlayerExpandedProvider, (prev, next) {
      if (next) {
        _expandController.animateTo(1.0, curve: Curves.easeOutCubic);
      } else {
        _expandController.animateTo(0.0, curve: Curves.easeOutCubic);
      }
    });

    // If activeVideo was set before first build, start loading it
    if (activeVideo != null && _loadedVideo?.videoId != activeVideo.videoId && !_isResolving) {
      Future.microtask(() {
        if (mounted && ref.read(activeYouTubeVideoProvider)?.videoId == activeVideo.videoId) {
          final shouldExpand = ref.read(isYouTubePlayerExpandedProvider);
          _expandController.value = shouldExpand ? 1.0 : 0.0;
          _loadAndPlayVideo(activeVideo);
        }
      });
    }

    if (activeVideo == null) {
      return const SizedBox.shrink();
    }

    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    final topPad = mq.padding.top;
    final t = _expandController.value.clamp(0.0, 1.0);

    // Floating PiP MiniPlayer geometry (bottom-right corner above bottom bar, matching Screenshot 2!)
    const miniW = 192.0;
    const miniH = 108.0;
    final miniLeft = screenW - miniW - 12.0;
    const miniRight = 12.0;
    final miniBottom = widget.bottomNavOffset + 4.0;
    final miniTop = screenH - miniBottom - miniH;

    final left = _isFullscreen ? 0.0 : lerpDouble(miniLeft, 0.0, t)!;
    final right = _isFullscreen ? 0.0 : lerpDouble(miniRight, 0.0, t)!;
    final top = _isFullscreen ? 0.0 : lerpDouble(miniTop, 0.0, t)!;
    final bottom = _isFullscreen ? 0.0 : lerpDouble(miniBottom, 0.0, t)!;
    final radius = _isFullscreen ? 0.0 : lerpDouble(16.0, 0.0, t)!;

    // IMPORTANT: Positioned MUST be the direct outermost widget returned inside HomeScreen's Stack!
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: PopScope(
        canPop: _expandController.value < 0.2 && !_isFullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_isFullscreen) {
            _exitFullscreen();
          } else if (_expandController.value >= 0.2) {
            _minimizeToMiniPlayer();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: t < 0.95
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.black,
            child: t < 0.28
                ? _buildFloatingPiPMiniPlayer(activeVideo)
                : _buildFullPlayerLayout(activeVideo, screenW, screenH, topPad, t),
          ),
        ),
      ),
    );
  }

  /// Floating Corner PiP MiniPlayer matching Screenshot 2:
  /// - Rounded video frame in the bottom-right corner above the bottom bar
  /// - Red progress bar along the bottom edge
  /// - Tap or swipe up to expand back to the full YouTube player!
  /// - Swipe down/right or tap `✕` to close.
  Widget _buildFloatingPiPMiniPlayer(YouTubeVideoItem video) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _expandToFullPlayer,
      onVerticalDragUpdate: (d) {
        final screenH = MediaQuery.of(context).size.height;
        _expandController.value =
            (_expandController.value - d.primaryDelta! / (screenH * 0.55))
                .clamp(0.0, 1.0);
      },
      onVerticalDragEnd: (d) {
        final vy = d.primaryVelocity ?? 0;
        if (vy < -240 || _expandController.value > 0.25) {
          _expandToFullPlayer();
        } else if (vy > 600) {
          _closePlayer();
        } else {
          _minimizeToMiniPlayer();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoController != null && !_hasError)
            Video(
              controller: _videoController!,
              fit: BoxFit.cover,
              controls: NoVideoControls,
            )
          else
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
            ),

          // Subtle top-right close & bottom-left pause buttons on mini window
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: _closePlayer,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => _videoPlayer?.playOrPause(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Red progress line along bottom edge (matching Screenshot 2)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3.0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE52D27)),
            ),
          ),
        ],
      ),
    );
  }

  /// Full YouTube Player Layout matching Screenshot 1!
  Widget _buildFullPlayerLayout(
    YouTubeVideoItem video,
    double screenW,
    double screenH,
    double topPad,
    double expandFactor,
  ) {
    if (_isFullscreen) {
      return _buildVideoSurfaceWithGlassControls(video, isLandscapeFull: true);
    }

    return Column(
      children: [
        SizedBox(height: topPad * expandFactor),
        // ── 16:9 Draggable Video Surface + Frosted Glass Controls (Screenshot 1) ──
        GestureDetector(
          onVerticalDragUpdate: (d) {
            _expandController.value =
                (_expandController.value - d.primaryDelta! / (screenH * 0.65))
                    .clamp(0.0, 1.0);
          },
          onVerticalDragEnd: (d) {
            final vy = d.primaryVelocity ?? 0;
            if (vy > 380 || _expandController.value < 0.62) {
              _minimizeToMiniPlayer();
            } else {
              _expandToFullPlayer();
            }
          },
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildVideoSurfaceWithGlassControls(video, isLandscapeFull: false),
          ),
        ),

        // ── Scrollable Video Metadata, Channel, Actions, Comments & More Videos (Screenshot 1) ──
        Expanded(
          child: Opacity(
            opacity: ((expandFactor - 0.35) / 0.65).clamp(0.0, 1.0),
            child: _buildBelowVideoDetails(video),
          ),
        ),
      ],
    );
  }

  /// Video surface + Circular Frosted Glass Overlay Buttons + Bottom-edge Red Seekbar (Screenshot 1).
  Widget _buildVideoSurfaceWithGlassControls(
    YouTubeVideoItem video, {
    required bool isLandscapeFull,
  }) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onDoubleTapDown: (details) {
        final w = MediaQuery.of(context).size.width;
        if (details.localPosition.dx < w / 2) {
          final target = _position - const Duration(seconds: 10);
          _videoPlayer?.seek(target < Duration.zero ? Duration.zero : target);
        } else {
          final target = _position + const Duration(seconds: 10);
          _videoPlayer?.seek(target > _duration ? _duration : target);
        }
        _scheduleHideControls();
      },
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        _videoPlayer?.setRate(2.0);
      },
      onLongPressEnd: (_) {
        _videoPlayer?.setRate(_playbackSpeed);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Frame
          Container(
            color: Colors.black,
            child: _videoController != null && !_hasError
                ? Transform.scale(
                    scale: _videoZoom,
                    child: Video(
                      controller: _videoController!,
                      fit: _videoFit,
                      controls: NoVideoControls,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
          ),

          // Loading / Buffering spinner
          if (_isResolving || _isBuffering)
            const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.8,
                ),
              ),
            ),

          // Error Retry state
          if (_hasError && !_isResolving)
            Container(
              color: Colors.black.withValues(alpha: 0.78),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE52D27),
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stream interrupted. Tap Retry to reload.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _GlassCircleButton(
                    icon: Icons.refresh_rounded,
                    size: 44,
                    onTap: () => _loadAndPlayVideo(video),
                  ),
                ],
              ),
            ),

          // ── Frosted Glass Overlay Controls matching Screenshot 1 ──
          if (_showControls && !_hasError)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                color: Colors.black.withValues(alpha: 0.28),
                child: Stack(
                  children: [
                    // Top Row: Minimize button on left; Crop, PiP MiniPlayer, Settings gear on right (Screenshot 1)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          _GlassCircleButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            size: 38,
                            iconSize: 24,
                            onTap: _minimizeToMiniPlayer,
                          ),
                          const Spacer(),
                          _GlassCircleButton(
                            icon: Icons.crop_free_rounded,
                            size: 38,
                            iconSize: 19,
                            onTap: _cycleAspectFit,
                          ),
                          const SizedBox(width: 8),
                          _GlassCircleButton(
                            icon: Icons.picture_in_picture_alt_rounded,
                            size: 38,
                            iconSize: 19,
                            onTap: _minimizeToMiniPlayer,
                          ),
                          const SizedBox(width: 8),
                          _GlassCircleButton(
                            icon: Icons.settings_rounded,
                            size: 38,
                            iconSize: 19,
                            onTap: _showPlaybackSettingsSheet,
                          ),
                        ],
                      ),
                    ),

                    // Center Row: Replay 10s, Play/Pause, Forward 10s in Frosted Glass Circles (Screenshot 1)
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlassCircleButton(
                            icon: Icons.replay_10_rounded,
                            size: 48,
                            iconSize: 24,
                            onTap: () {
                              final t = _position - const Duration(seconds: 10);
                              _videoPlayer?.seek(t < Duration.zero ? Duration.zero : t);
                              _scheduleHideControls();
                            },
                          ),
                          const SizedBox(width: 28),
                          _GlassCircleButton(
                            icon: _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 66,
                            iconSize: 34,
                            onTap: () {
                              _videoPlayer?.playOrPause();
                              _scheduleHideControls();
                            },
                          ),
                          const SizedBox(width: 28),
                          _GlassCircleButton(
                            icon: Icons.forward_10_rounded,
                            size: 48,
                            iconSize: 24,
                            onTap: () {
                              final t = _position + const Duration(seconds: 10);
                              _videoPlayer?.seek(t > _duration ? _duration : t);
                              _scheduleHideControls();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Bottom Row: Timestamp on left; Speed, HQ, Fullscreen glass buttons on right (Screenshot 1)
                    Positioned(
                      left: 14,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        children: [
                          Text(
                            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _GlassCircleButton(
                            icon: Icons.speed_rounded,
                            size: 36,
                            iconSize: 18,
                            onTap: _showSpeedPickerSheet,
                          ),
                          const SizedBox(width: 8),
                          _GlassCircleButton(
                            icon: Icons.hd_outlined,
                            size: 36,
                            iconSize: 18,
                            onTap: _showQualityPickerSheet,
                          ),
                          const SizedBox(width: 8),
                          _GlassCircleButton(
                            icon: _isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            size: 36,
                            iconSize: 20,
                            onTap: _toggleFullscreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom-edge Red Seek Slider with Red Thumb (matching Screenshot 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 16,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.8,
                activeTrackColor: const Color(0xFFE52D27),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFE52D27),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) {
                  final target = Duration(
                    milliseconds: (v * _duration.inMilliseconds).round(),
                  );
                  setState(() => _position = target);
                  _videoPlayer?.seek(target);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Below-video details, channel row, action pills, comments card, and compact horizontal `More videos` list (Screenshot 1).
  Widget _buildBelowVideoDetails(YouTubeVideoItem video) {
    final title = _resolvedData?.title.isNotEmpty == true
        ? _resolvedData!.title
        : video.title;
    final channel = _resolvedData?.channelName.isNotEmpty == true
        ? _resolvedData!.channelName
        : video.channelName;
    final views = _resolvedData?.viewCountText.isNotEmpty == true
        ? _resolvedData!.viewCountText
        : video.viewCountText;
    final related = _resolvedData?.relatedVideos ?? const <YouTubeVideoItem>[];

    final isLiked = ref.watch(likedYouTubeVideosProvider).contains(video.videoId);
    final isSaved = ref.watch(savedYouTubeVideosProvider).contains(video.videoId);
    final isSubbed = ref.watch(subscribedChannelsProvider).contains(channel);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
      children: [
        // 1. Title & Metadata (Screenshot 1)
        GestureDetector(
          onTap: () {
            showFrostedGlassBottomSheet(
              context: context,
              title: 'Description',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Text(
                    _resolvedData?.description.isNotEmpty == true
                        ? _resolvedData!.description
                        : '$title\n\nChannel: $channel\n$views · ${video.publishedTimeText}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$views · ${video.publishedTimeText.isNotEmpty ? video.publishedTimeText : 'Recently'}  ...more',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Channel Avatar + Name + Subscribe Pill (Screenshot 1)
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white12,
              backgroundImage: video.channelAvatarUrl != null
                  ? CachedNetworkImageProvider(video.channelAvatarUrl!)
                  : null,
              child: video.channelAvatarUrl == null
                  ? Text(
                      channel.isNotEmpty ? channel[0].toUpperCase() : 'Y',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Official Channel',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(subscribedChannelsProvider.notifier).toggle(channel);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: isSubbed
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  isSubbed ? 'Subscribed' : 'Subscribe',
                  style: TextStyle(
                    color: isSubbed ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 3. Action Pills Row matching Screenshot 1 (Like | Dislike, Save, Download, Share)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Combined Like | Dislike pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(likedYouTubeVideosProvider.notifier).toggle(video.videoId);
                      },
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                            size: 18,
                            color: isLiked ? Colors.white : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLiked ? 'Liked' : 'Like',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white24,
                    ),
                    const Icon(
                      Icons.thumb_down_outlined,
                      size: 17,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildActionPill(
                icon: isSaved ? Icons.watch_later_rounded : Icons.access_time_rounded,
                label: isSaved ? 'Saved' : 'Save',
                onTap: () {
                  ref.read(savedYouTubeVideosProvider.notifier).toggle(video.videoId);
                },
              ),
              const SizedBox(width: 8),
              _buildActionPill(
                icon: Icons.download_rounded,
                label: 'Download',
                onTap: _showQualityPickerSheet,
              ),
              const SizedBox(width: 8),
              _buildActionPill(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: 'https://youtu.be/${video.videoId}'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Video link copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. Comments Preview Card (interactive, opens full real comments sheet)
        GestureDetector(
          onTap: () => _showCommentsSheet(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _watchNextData?.commentCountText.isNotEmpty == true
                          ? _watchNextData!.commentCountText
                          : 'Top',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_watchNextData != null &&
                        _watchNextData!.comments.isNotEmpty &&
                        _watchNextData!.comments.first.authorAvatarUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _watchNextData!.comments.first.authorAvatarUrl!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF2A5C4D),
                            child: Text(
                              _watchNextData!.comments.first.authorName.isNotEmpty
                                  ? _watchNextData!.comments.first.authorName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF2A5C4D),
                        child: Text(
                          channel.isNotEmpty ? channel[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (_watchNextData != null && _watchNextData!.comments.isNotEmpty)
                            ? _watchNextData!.comments.first.text
                            : 'Tap to view all comments on this video...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // 5. "More videos" Section with Compact Horizontal Cards (matching Screenshot 1!)
        const Text(
          'More videos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),

        if (related.isEmpty && _isResolving)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE52D27),
                strokeWidth: 2.4,
              ),
            ),
          )
        else
          ...related.map(
            (item) => _MoreVideosHorizontalRow(
              video: item,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(activeYouTubeVideoProvider.notifier).state = item;
              },
              onMoreTap: () => _showMoreVideoOptions(item),
            ),
          ),
      ],
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreVideoOptions(YouTubeVideoItem item) {
    final isSaved = ref.read(savedYouTubeVideosProvider).contains(item.videoId);
    showFrostedGlassBottomSheet(
      context: context,
      title: item.title,
      children: [
        _GlassSheetOptionPill(
          icon: Icons.play_arrow_rounded,
          title: 'Play Next Now',
          onTap: () {
            Navigator.pop(context);
            ref.read(activeYouTubeVideoProvider.notifier).state = item;
          },
        ),
        _GlassSheetOptionPill(
          icon: isSaved ? Icons.watch_later_rounded : Icons.watch_later_outlined,
          title: isSaved ? 'Remove from Watch Later' : 'Save to Watch Later',
          onTap: () {
            ref.read(savedYouTubeVideosProvider.notifier).toggle(item.videoId);
            Navigator.pop(context);
          },
        ),
        _GlassSheetOptionPill(
          icon: Icons.share_rounded,
          title: 'Share Video Link',
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: 'https://youtu.be/${item.videoId}'),
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

/// Compact Horizontal Video Card used in "More videos" inside the player (matching Screenshot 1!).
class _MoreVideosHorizontalRow extends StatelessWidget {
  final YouTubeVideoItem video;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _MoreVideosHorizontalRow({
    required this.video,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 160x90 Rounded Thumbnail with Duration Badge (Screenshot 1)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 156,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: const Color(0xFF18181C)),
                      errorWidget: (_, _, _) => Container(color: const Color(0xFF18181C)),
                    ),
                    if (video.durationText.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.durationText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${video.channelName} · ${video.viewCountText}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white54,
                size: 18,
              ),
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Rich Frosted Glass Comment Tile displaying real YouTube user comments
class _CommentTile extends StatelessWidget {
  final YouTubeCommentItem comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (comment.authorAvatarUrl != null && comment.authorAvatarUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: comment.authorAvatarUrl!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarFallback(),
                  ),
                )
              else
                _avatarFallback(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  comment.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (comment.publishedTime.isNotEmpty)
                Text(
                  comment.publishedTime,
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            comment.text,
            style: TextStyle(
              color: isDark ? Colors.white.withValues(alpha: 0.90) : Colors.black87,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (comment.likeCount.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.thumb_up_alt_rounded,
                  size: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 5),
                Text(
                  comment.likeCount,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFF2A5C4D),
      child: Text(
        comment.authorName.isNotEmpty ? comment.authorName[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
