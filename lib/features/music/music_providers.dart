import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../core/services/settings_storage.dart';
import '../../data/models/music_models.dart';
import '../../data/sources/music_service.dart';

// ============================================================================
// Music Service Provider
// ============================================================================

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService();
});

// ============================================================================
// Music Player State Notifier (Real media_kit Player + Fallback)
// ============================================================================

class MusicPlayerNotifier extends StateNotifier<NowPlayingState> {
  final MusicService _service;
  final Ref _ref;
  Player? _player;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _bufferingSub;
  Timer? _fallbackTimer;

  static const _platformChannel = MethodChannel('com.aniwhere.music/notification');

  MusicPlayerNotifier(this._service, this._ref) : super(const NowPlayingState()) {
    _initPlayer();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _platformChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'play':
          resume();
          break;
        case 'pause':
          pause();
          break;
        case 'next':
          next();
          break;
        case 'previous':
          previous();
          break;
        case 'seek':
          if (call.arguments is Map) {
            final pos = (call.arguments['position'] as num?)?.toInt() ?? 0;
            seekTo(Duration(milliseconds: pos));
          }
          break;
      }
    });
  }

  void _updateNotification() {
    final track = state.currentTrack;
    if (track == null) return;
    try {
      _platformChannel.invokeMethod('updatePlaybackState', {
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'artUrl': track.albumArtUrl ?? '',
        'isPlaying': state.isPlaying,
        'position': state.position.inMilliseconds,
        'duration': track.duration.inMilliseconds,
      });
    } catch (_) {}
  }

  void _initPlayer() {
    try {
      _player = Player();
      _posSub = _player!.stream.position.listen((pos) {
        state = state.copyWith(position: pos);
      });
      _durSub = _player!.stream.duration.listen((dur) {
        if (dur > Duration.zero && state.currentTrack != null) {
          state = state.copyWith(
            currentTrack: state.currentTrack!.copyWith(duration: dur),
          );
        }
      });
      _playingSub = _player!.stream.playing.listen((isPlaying) {
        state = state.copyWith(isPlaying: isPlaying);
        _updateNotification();
      });
      _completedSub = _player!.stream.completed.listen((completed) {
        if (completed) {
          next();
        }
      });
      _bufferingSub = _player!.stream.buffering.listen((isBuffering) {
        state = state.copyWith(isLoading: isBuffering);
      });
    } catch (_) {
      _player = null;
    }
  }

  /// Play a track at a given index in the queue
  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? queue, int index = 0}) async {
    _fallbackTimer?.cancel();
    state = state.copyWith(
      currentTrack: track,
      queue: queue ?? [track],
      currentIndex: index,
      isPlaying: true,
      position: Duration.zero,
      isLoading: true,
    );

    // ALWAYS dynamically resolve unique streamUrl for each specific track with user's quality preference
    final quality = _ref.read(audioQualityWifiProvider);
    String streamUrl = track.streamUrl;
    if (streamUrl.isEmpty || !streamUrl.startsWith('http') || track.encryptedMediaUrl != null) {
      final resolved = await _service.resolveStreamUrl(track, quality: quality);
      if (resolved.isNotEmpty) {
        streamUrl = resolved;
        track = track.copyWith(streamUrl: streamUrl);
        state = state.copyWith(currentTrack: track);
      }
    }

    try {
      if (_player != null && streamUrl.isNotEmpty) {
        await _player!.open(Media(streamUrl), play: true);
        await _player!.setRate(state.playbackSpeed);
        await _player!.setVolume(state.volume * 100);
      } else {
        _startFallbackTimer();
      }
    } catch (_) {
      _startFallbackTimer();
    } finally {
      state = state.copyWith(isLoading: false);
      _updateNotification();
    }
  }

  /// Play/pause toggle
  void togglePlayPause() {
    if (state.currentTrack == null) return;
    if (_player != null) {
      _player!.playOrPause();
    } else {
      state = state.copyWith(isPlaying: !state.isPlaying);
      if (state.isPlaying) {
        _startFallbackTimer();
      } else {
        _fallbackTimer?.cancel();
      }
    }
  }

  /// Resume playback
  void resume() {
    if (state.currentTrack == null || state.isPlaying) return;
    if (_player != null) {
      _player!.play();
    } else {
      state = state.copyWith(isPlaying: true);
      _startFallbackTimer();
    }
  }

  /// Pause playback
  void pause() {
    if (state.currentTrack == null || !state.isPlaying) return;
    if (_player != null) {
      _player!.pause();
    } else {
      state = state.copyWith(isPlaying: false);
      _fallbackTimer?.cancel();
    }
  }

  /// Skip to next track
  void next() {
    if (state.queue.isEmpty) return;
    int nextIndex;
    if (state.isShuffled) {
      nextIndex = Random().nextInt(state.queue.length);
    } else if (state.repeatMode == MusicRepeatMode.one) {
      nextIndex = state.currentIndex;
    } else if (state.currentIndex < state.queue.length - 1) {
      nextIndex = state.currentIndex + 1;
    } else if (state.repeatMode == MusicRepeatMode.all) {
      nextIndex = 0;
    } else {
      return;
    }
    playTrack(state.queue[nextIndex], queue: state.queue, index: nextIndex);
  }

  /// Skip to previous track
  void previous() {
    if (state.queue.isEmpty) return;
    if (state.position.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }
    int prevIndex;
    if (state.currentIndex > 0) {
      prevIndex = state.currentIndex - 1;
    } else if (state.repeatMode == MusicRepeatMode.all) {
      prevIndex = state.queue.length - 1;
    } else {
      return;
    }
    playTrack(state.queue[prevIndex], queue: state.queue, index: prevIndex);
  }

  /// Seek to a position
  void seekTo(Duration position) {
    state = state.copyWith(position: position);
    _player?.seek(position);
  }

  /// Toggle shuffle
  void toggleShuffle() {
    state = state.copyWith(isShuffled: !state.isShuffled);
  }

  /// Cycle repeat mode: off → all → one → off
  void cycleRepeatMode() {
    final modes = MusicRepeatMode.values;
    final nextIndex = (modes.indexOf(state.repeatMode) + 1) % modes.length;
    state = state.copyWith(repeatMode: modes[nextIndex]);
  }

  /// Set volume
  void setVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: v);
    _player?.setVolume(v * 100);
  }

  /// Set playback speed
  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed);
    _player?.setRate(speed);
  }

  /// Add to queue
  void addToQueue(MusicTrack track) {
    final newQueue = List<MusicTrack>.from(state.queue)..add(track);
    state = state.copyWith(queue: newQueue);
  }

  /// Remove from queue
  void removeFromQueue(int index) {
    final newQueue = List<MusicTrack>.from(state.queue)..removeAt(index);
    int newIndex = state.currentIndex;
    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex) {
      if (newQueue.isNotEmpty) {
        newIndex = newIndex.clamp(0, newQueue.length - 1);
        playTrack(newQueue[newIndex], queue: newQueue, index: newIndex);
        return;
      } else {
        stop();
        return;
      }
    }
    state = state.copyWith(queue: newQueue, currentIndex: newIndex);
  }

  /// Reorder queue
  void reorderQueue(int oldIndex, int newIndex) {
    final newQueue = List<MusicTrack>.from(state.queue);
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, item);

    int currentIdx = state.currentIndex;
    if (oldIndex == currentIdx) {
      currentIdx = newIndex;
    } else if (oldIndex < currentIdx && newIndex >= currentIdx) {
      currentIdx--;
    } else if (oldIndex > currentIdx && newIndex <= currentIdx) {
      currentIdx++;
    }

    state = state.copyWith(queue: newQueue, currentIndex: currentIdx);
  }

  /// Clear queue and stop
  void stop() {
    _fallbackTimer?.cancel();
    _player?.stop();
    state = const NowPlayingState();
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!state.isPlaying || state.currentTrack == null) return;

      final newPos = state.position + Duration(milliseconds: (250 * state.playbackSpeed).round());
      if (newPos >= state.currentTrack!.duration) {
        next();
      } else {
        state = state.copyWith(
          position: newPos,
          bufferedPosition: Duration(
            milliseconds: min(
              newPos.inMilliseconds + 30000,
              state.currentTrack!.duration.inMilliseconds,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _bufferingSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}

final musicPlayerProvider =
    StateNotifierProvider<MusicPlayerNotifier, NowPlayingState>((ref) {
  final service = ref.read(musicServiceProvider);
  return MusicPlayerNotifier(service, ref);
});

// ============================================================================
// Music Data Providers
// ============================================================================

/// Trending tracks
final trendingTracksProvider = FutureProvider<List<MusicTrack>>((ref) {
  return ref.read(musicServiceProvider).getTrending();
});

/// Recently played tracks
final recentlyPlayedProvider = FutureProvider<List<MusicTrack>>((ref) {
  return ref.read(musicServiceProvider).getRecentlyPlayed();
});

/// Albums & singles (e.g. AUJLA SZN 1, Loser, Dracula)
final albumsAndSinglesProvider = FutureProvider<List<MusicAlbumItem>>((ref) {
  return ref.read(musicServiceProvider).getAlbumsAndSingles();
});

/// Featured playlists (Global Top 50, India's Biggest Hits, Punjabi Heat, etc.)
final featuredPlaylistsProvider = FutureProvider<List<MusicPlaylist>>((ref) {
  return ref.read(musicServiceProvider).getPlaylists();
});

/// Selected genre filter for browse
final selectedGenreProvider = StateProvider<String>((ref) => 'All');

/// Anime playlists (kept for backwards compatibility)
final animePlaylistsProvider = featuredPlaylistsProvider;

/// Music search results across YouTube Music and 320kbps catalog
final musicSearchProvider =
    FutureProvider.family<List<MusicTrack>, String>((ref, query) {
  return ref.read(musicServiceProvider).search(query);
});

/// Lyrics for current track
final lyricsProvider = FutureProvider.family<List<LyricLine>, MusicTrack>((ref, track) {
  return ref.read(musicServiceProvider).getLyrics(
    track.id,
    title: track.title,
    artist: track.artist,
  );
});

// ============================================================================
// Music Settings Notifiers & Providers (Backed by SettingsStorage)
// ============================================================================

class PersistentBoolNotifier extends StateNotifier<bool> {
  final String key;
  PersistentBoolNotifier(this.key, bool defaultValue)
      : super(SettingsStorage.getBool(key, defaultValue: defaultValue));

  @override
  set state(bool value) {
    super.state = value;
    SettingsStorage.setBool(key, value);
  }

  void set(bool value) => state = value;
  void toggle() => state = !state;
}

class PersistentDoubleNotifier extends StateNotifier<double> {
  final String key;
  PersistentDoubleNotifier(this.key, double defaultValue)
      : super(SettingsStorage.getDouble(key, defaultValue: defaultValue));

  @override
  set state(double value) {
    super.state = value;
    SettingsStorage.setDouble(key, value);
  }

  void set(double value) => state = value;
}

class PersistentIntNotifier extends StateNotifier<int> {
  final String key;
  PersistentIntNotifier(this.key, int defaultValue)
      : super(SettingsStorage.getInt(key, defaultValue: defaultValue));

  @override
  set state(int value) {
    super.state = value;
    SettingsStorage.setInt(key, value);
  }

  void set(int value) => state = value;
}

class PersistentEnumNotifier<T extends Enum> extends StateNotifier<T> {
  final String key;
  final List<T> values;
  PersistentEnumNotifier(this.key, T defaultValue, this.values)
      : super(_load(key, defaultValue, values));

  static T _load<T extends Enum>(String key, T defaultValue, List<T> values) {
    final name = SettingsStorage.getString(key, defaultValue: defaultValue.name);
    return values.firstWhere((v) => v.name == name, orElse: () => defaultValue);
  }

  @override
  set state(T value) {
    super.state = value;
    SettingsStorage.setString(key, value.name);
  }

  void set(T value) => state = value;
}

/// Audio quality for WiFi (persisted)
final audioQualityWifiProvider =
    StateNotifierProvider<PersistentEnumNotifier<AudioQuality>, AudioQuality>((ref) {
  return PersistentEnumNotifier('audio_quality_wifi', AudioQuality.lossless, AudioQuality.values);
});

/// Audio quality for cellular (persisted)
final audioQualityCellularProvider =
    StateNotifierProvider<PersistentEnumNotifier<AudioQuality>, AudioQuality>((ref) {
  return PersistentEnumNotifier('audio_quality_cellular', AudioQuality.high, AudioQuality.values);
});

/// Crossfade duration in seconds (persisted)
final crossfadeSecondsProvider =
    StateNotifierProvider<PersistentIntNotifier, int>((ref) {
  return PersistentIntNotifier('crossfade_seconds', 0);
});

/// Skip silence (persisted)
final skipSilenceProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('skip_silence', false);
});

/// Loudness normalization (persisted)
final loudnessNormalizationProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('loudness_norm', true);
});

/// Liquid glass effect on nav bar (persisted)
final liquidGlassProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('liquid_glass_enabled', true);
});

/// Liquid glass blur intensity (persisted, 5.0 to 45.0)
final liquidGlassIntensityProvider =
    StateNotifierProvider<PersistentDoubleNotifier, double>((ref) {
  return PersistentDoubleNotifier('liquid_glass_intensity', 25.0);
});

/// Liquid glass surface opacity (persisted, 0.15 to 0.70)
final liquidGlassOpacityProvider =
    StateNotifierProvider<PersistentDoubleNotifier, double>((ref) {
  return PersistentDoubleNotifier('liquid_glass_opacity', 0.35);
});

/// Docked bottom capsule mode on scroll down (Apple Music iOS style)
final isDockedCapsuleProvider = StateProvider<bool>((ref) => false);

/// In-app dynamic island floating music capsule toggle
final dynamicIslandEnabledProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('dynamic_island_enabled', false);
});

/// Lyrics blur effect (persisted)
final lyricsBlurProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('lyrics_blur', true);
});

/// Reduce animations (persisted)
final reduceAnimationProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('reduce_animations', false);
});

/// Show codec/bitrate/sample-rate stats on player (persisted)
final showNerdStatsProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('show_nerd_stats', false);
});

/// Animated canvas (motion artwork) (persisted)
final animatedCanvasProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('animated_canvas', true);
});

/// Full bleed artwork on player (persisted)
final fullBleedArtworkProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('full_bleed_artwork', true);
});

/// Equalizer enabled (persisted)
final equalizerEnabledProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('equalizer_enabled', false);
});

/// Spatial audio widening (persisted)
final spatialAudioProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('spatial_audio', false);
});

/// Output PCM mode (persisted)
final outputPcmModeProvider =
    StateNotifierProvider<PersistentEnumNotifier<OutputPcmMode>, OutputPcmMode>((ref) {
  return PersistentEnumNotifier('output_pcm_mode', OutputPcmMode.pcm16, OutputPcmMode.values);
});

/// Synced lyrics enabled (persisted)
final syncedLyricsProvider =
    StateNotifierProvider<PersistentBoolNotifier, bool>((ref) {
  return PersistentBoolNotifier('synced_lyrics', true);
});

/// Download quality (persisted)
final downloadQualityProvider =
    StateNotifierProvider<PersistentEnumNotifier<DownloadQuality>, DownloadQuality>((ref) {
  return PersistentEnumNotifier('download_quality', DownloadQuality.lossless, DownloadQuality.values);
});

/// Bottom navigation bar & mini player visibility on user scroll
final isBottomBarVisibleProvider = StateProvider<bool>((ref) => true);

// ============================================================================
// Music-Only User Playlists & Favorites (Persisted in SettingsStorage)
// ============================================================================

class UserPlaylistsNotifier extends StateNotifier<List<MusicPlaylist>> {
  UserPlaylistsNotifier() : super(_loadInitial());

  static List<MusicPlaylist> _loadInitial() {
    final rawJson = SettingsStorage.getString('user_playlists_json', defaultValue: '');
    if (rawJson.isNotEmpty) {
      try {
        final list = jsonDecode(rawJson) as List;
        return list
            .map((item) => MusicPlaylist.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [
      const MusicPlaylist(
        id: 'fav_playlist',
        title: 'Liked Songs',
        description: 'Favorite tracks saved to library',
        trackCount: 0,
        tracks: [],
      ),
      const MusicPlaylist(
        id: 'my_hits',
        title: 'My Heavy Rotation',
        description: 'Personal playlist',
        trackCount: 0,
        tracks: [],
      ),
    ];
  }

  void _persist() {
    try {
      final jsonList = state.map((p) => p.toJson()).toList();
      SettingsStorage.setString('user_playlists_json', jsonEncode(jsonList));
    } catch (_) {}
  }

  void createPlaylist(String title, String description) {
    if (title.trim().isEmpty) return;
    final newPl = MusicPlaylist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      description: description.trim().isNotEmpty ? description.trim() : 'Custom playlist',
      trackCount: 0,
      tracks: const [],
    );
    state = [...state, newPl];
    _persist();
  }

  void addTrackToPlaylist(String playlistId, MusicTrack track) {
    state = state.map((pl) {
      if (pl.id == playlistId) {
        if (pl.tracks.any((t) => t.id == track.id)) return pl;
        final updatedTracks = [...pl.tracks, track];
        return MusicPlaylist(
          id: pl.id,
          title: pl.title,
          description: pl.description,
          thumbnailUrl: pl.thumbnailUrl ?? track.albumArtUrl,
          tracks: updatedTracks,
          trackCount: updatedTracks.length,
        );
      }
      return pl;
    }).toList();
    _persist();
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    state = state.map((pl) {
      if (pl.id == playlistId) {
        final updatedTracks = pl.tracks.where((t) => t.id != trackId).toList();
        return MusicPlaylist(
          id: pl.id,
          title: pl.title,
          description: pl.description,
          thumbnailUrl: updatedTracks.isNotEmpty ? updatedTracks.first.albumArtUrl : null,
          tracks: updatedTracks,
          trackCount: updatedTracks.length,
        );
      }
      return pl;
    }).toList();
    _persist();
  }

  void deletePlaylist(String playlistId) {
    if (playlistId == 'fav_playlist') return; // Keep Liked Songs
    state = state.where((pl) => pl.id != playlistId).toList();
    _persist();
  }
}

final userPlaylistsProvider =
    StateNotifierProvider<UserPlaylistsNotifier, List<MusicPlaylist>>((ref) {
  return UserPlaylistsNotifier();
});

class LikedSongsNotifier extends StateNotifier<Set<String>> {
  LikedSongsNotifier()
      : super(SettingsStorage.getStringList('liked_songs', defaultValue: []).toSet());

  void toggleLike(String trackId) {
    final next = Set<String>.from(state);
    if (next.contains(trackId)) {
      next.remove(trackId);
    } else {
      next.add(trackId);
    }
    state = next;
    SettingsStorage.setStringList('liked_songs', next.toList());
  }

  bool isLiked(String trackId) => state.contains(trackId);
}

final likedSongsProvider =
    StateNotifierProvider<LikedSongsNotifier, Set<String>>((ref) {
  return LikedSongsNotifier();
});

// ============================================================================
// Sleep Timer Notifier
// ============================================================================

class SleepTimerNotifier extends StateNotifier<Duration?> {
  final Ref _ref;
  Timer? _timer;

  SleepTimerNotifier(this._ref) : super(null);

  void setTimer(Duration? duration) {
    _timer?.cancel();
    state = duration;
    if (duration == null || duration <= Duration.zero) {
      state = null;
      return;
    }

    _timer = Timer(duration, () {
      _ref.read(musicPlayerProvider.notifier).pause();
      state = null;
    });
  }

  void cancel() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, Duration?>((ref) {
  return SleepTimerNotifier(ref);
});

// ============================================================================
// Genre Tracks Provider (For interactive Category Pills)
// ============================================================================

final genreTracksProvider =
    FutureProvider.family<List<MusicTrack>, String>((ref, genre) async {
  final service = ref.watch(musicServiceProvider);
  String query = genre;
  if (genre.toLowerCase() == 'punjabi') {
    query = 'punjabi top hits';
  } else if (genre.toLowerCase() == 'pop') {
    query = 'pop hits';
  } else if (genre.toLowerCase() == 'hip-hop') {
    query = 'hip hop rap';
  } else if (genre.toLowerCase() == 'anime') {
    query = 'anime ost hits';
  } else if (genre.toLowerCase() == 'lo-fi') {
    query = 'lofi chill beats';
  } else if (genre.toLowerCase() == 'rock') {
    query = 'rock classic hits';
  }
  return service.search(query);
});
