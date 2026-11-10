import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/services/native_bridge.dart';
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
  bool _crossfading = false;

  static const _platformChannel = MethodChannel('com.aniwhere.music/notification');

  MusicPlayerNotifier(this._service, this._ref) : super(const NowPlayingState()) {
    _initPlayer();
    _setupMethodChannel();
    _listenAudioSettings();
  }

  void _listenAudioSettings() {
    for (final p in [
      loudnessNormalizationProvider,
      skipSilenceProvider,
      equalizerEnabledProvider,
      spatialAudioProvider,
    ]) {
      _ref.listen<bool>(p, (_, _) => applyAudioProcessing());
    }
    _ref.listen<OutputPcmMode>(outputPcmModeProvider, (_, _) => applyAudioProcessing());
  }

  /// Applies equalizer, spatial audio, loudness normalization, skip-silence,
  /// and PCM format settings to the underlying mpv audio pipeline.
  Future<void> applyAudioProcessing() async {
    final p = _player;
    if (p == null) return;
    final platform = p.platform as dynamic;
    try {
      final pcm = _ref.read(outputPcmModeProvider);
      await platform.setProperty(
        'audio-format',
        pcm == OutputPcmMode.float32 ? 'float' : 's16',
      );
    } catch (_) {}

    final filters = <String>[];
    if (_ref.read(loudnessNormalizationProvider)) {
      filters.add('dynaudnorm=f=150:g=15');
    }
    if (_ref.read(skipSilenceProvider)) {
      filters.add('silenceremove=stop_periods=-1:stop_duration=0.6:stop_threshold=-45dB');
    }
    if (_ref.read(equalizerEnabledProvider)) {
      filters.add('superequalizer=1b=1.4:2b=1.3:3b=1.1:14b=1.2:16b=1.3:18b=1.4');
    }
    if (_ref.read(spatialAudioProvider)) {
      filters.add('extrastereo=m=1.5');
    }
    try {
      await platform.setProperty('af', filters.join(','));
    } catch (_) {}
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
        _checkCrossfade(pos);
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
      applyAudioProcessing();
    } catch (_) {
      _player = null;
    }
  }

  void _checkCrossfade(Duration pos) {
    final cfSec = _ref.read(crossfadeSecondsProvider);
    final dur = state.currentTrack?.duration ?? Duration.zero;
    if (cfSec <= 0 || dur <= Duration.zero || !state.isPlaying) return;
    final remainingMs = (dur - pos).inMilliseconds;
    final windowMs = cfSec * 1000;
    if (remainingMs > 0 && remainingMs <= windowMs) {
      final ratio = (remainingMs / windowMs).clamp(0.0, 1.0);
      _player?.setVolume(state.volume * ratio * 100);
      if (remainingMs <= 350 && !_crossfading) {
        _crossfading = true;
        next();
      }
    }
  }

  /// Play a track at a given index in the queue
  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? queue, int index = 0}) async {
    _fallbackTimer?.cancel();
    _crossfading = false;
    state = state.copyWith(
      currentTrack: track,
      queue: queue ?? [track],
      currentIndex: index,
      isPlaying: true,
      position: Duration.zero,
      isLoading: true,
    );

    // 0. If track is downloaded locally on disk, play the local offline file directly!
    final localPath = _ref.read(downloadedTracksProvider.notifier).getLocalFilePath(track.id);
    if (localPath != null && File(localPath).existsSync()) {
      final dlQuality = _ref.read(downloadedTracksProvider)[track.id] ?? DownloadQuality.lossless;
      final mappedQuality = dlQuality == DownloadQuality.low
          ? AudioQuality.low
          : (dlQuality == DownloadQuality.high ? AudioQuality.medium : AudioQuality.lossless);
      track = track.copyWith(
        streamUrl: localPath,
        quality: mappedQuality,
        bitrate: dlQuality == DownloadQuality.low
            ? 96
            : (dlQuality == DownloadQuality.high ? 160 : 320),
        isLossless: dlQuality == DownloadQuality.lossless,
      );
      state = state.copyWith(currentTrack: track);
      try {
        if (_player != null) {
          await applyAudioProcessing();
          await _player!.open(Media(localPath), play: true);
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
      return;
    }

    // Pick cellular vs Wi-Fi streaming quality based on active network
    final isCellular = await NativeBridge.isCellular();
    final quality = isCellular
        ? _ref.read(audioQualityCellularProvider)
        : _ref.read(audioQualityWifiProvider);
    String streamUrl = track.streamUrl;
    if (streamUrl.isEmpty || !streamUrl.startsWith('http') || track.encryptedMediaUrl != null) {
      final resolved = await _service.resolveStreamUrl(track, quality: quality);
      if (resolved.isNotEmpty) {
        streamUrl = resolved;
        track = track.copyWith(
          streamUrl: streamUrl,
          quality: quality,
          bitrate: quality == AudioQuality.low
              ? 96
              : (quality == AudioQuality.medium ? 160 : 320),
          isLossless: quality == AudioQuality.lossless,
        );
        state = state.copyWith(currentTrack: track);
      }
    }

    try {
      if (_player != null && streamUrl.isNotEmpty) {
        await applyAudioProcessing();
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

/// Active download progress map: trackId -> 0.0 .. 1.0
final downloadProgressProvider = StateProvider<Map<String, double>>((ref) => {});

/// Downloaded music tracks map: trackId -> DownloadQuality (persisted with real local files)
class DownloadedTracksNotifier extends StateNotifier<Map<String, DownloadQuality>> {
  static const _storageKey = 'downloaded_tracks_map';
  static const _pathsKey = 'downloaded_tracks_paths';

  final Ref _ref;
  Map<String, String> _filePaths;

  DownloadedTracksNotifier(this._ref)
      : _filePaths = _loadPaths(),
        super(_load());

  static Map<String, DownloadQuality> _load() {
    final raw = SettingsStorage.getString(_storageKey, defaultValue: '{}');
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
        k,
        DownloadQuality.values.firstWhere(
          (q) => q.name == v,
          orElse: () => DownloadQuality.lossless,
        ),
      ));
    } catch (_) {
      return {};
    }
  }

  static Map<String, String> _loadPaths() {
    final raw = SettingsStorage.getString(_pathsKey, defaultValue: '{}');
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  String? getLocalFilePath(String trackId) => _filePaths[trackId];

  /// Legacy synchronous setter (kept for compatibility)
  void downloadTrack(String trackId, DownloadQuality quality) {
    final updated = Map<String, DownloadQuality>.from(state);
    updated[trackId] = quality;
    state = updated;
    _save();
  }

  /// Real song download in selected quality (Lossless 320kbps, High 160kbps, Low 96kbps).
  /// Saves both to app offline storage and Android's public `Download/Aniwhere/` folder.
  Future<String?> downloadTrackReal(MusicTrack track, DownloadQuality quality) async {
    final trackId = track.id;
    // Set initial progress
    _setProgress(trackId, 0.02);

    try {
      final AudioQuality audioQuality;
      final String qualityTag;
      switch (quality) {
        case DownloadQuality.lossless:
          audioQuality = AudioQuality.lossless;
          qualityTag = 'Lossless_320kbps';
          break;
        case DownloadQuality.high:
          audioQuality = AudioQuality.medium; // 160kbps stream
          qualityTag = 'High_160kbps';
          break;
        case DownloadQuality.low:
          audioQuality = AudioQuality.low; // 96kbps stream
          qualityTag = 'Low_96kbps';
          break;
      }

      final docDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${docDir.path}/downloads/music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final safeTitle = track.title
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final safeArtist = track.artist
          .replaceAll(RegExp(r'[^\w\s\-]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName =
          '${safeTitle.isEmpty ? trackId : safeTitle}-${safeArtist.isEmpty ? "Artist" : safeArtist}_$qualityTag.m4a';
      final localPath = '${musicDir.path}/$fileName';

      // Delete old file if re-downloading in a different quality
      final oldPath = _filePaths[trackId];
      if (oldPath != null && oldPath != localPath) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      final service = _ref.read(musicServiceProvider);
      final ok = await service.downloadTrackFile(
        track: track,
        quality: audioQuality,
        savePath: localPath,
        onProgress: (received, total) {
          if (total > 0) {
            _setProgress(trackId, (received / total).clamp(0.05, 0.98));
          }
        },
      );

      final file = File(localPath);
      if (!ok || !await file.exists() || await file.length() == 0) {
        _clearProgress(trackId);
        return null;
      }

      final bytes = await file.length();
      final sizeMb = (bytes / (1024 * 1024)).toStringAsFixed(1);

      // Also export to Android public Downloads/Aniwhere folder
      final publicPath = await NativeBridge.saveToDownloads(
        filePath: localPath,
        fileName: fileName,
        mimeType: 'audio/mp4',
      );

      _filePaths = Map<String, String>.from(_filePaths)..[trackId] = localPath;
      final updated = Map<String, DownloadQuality>.from(state)..[trackId] = quality;
      state = updated;
      _save();
      _clearProgress(trackId);

      // Also add to "Downloaded Songs" user playlist so user can find all downloads in one place
      _ref.read(userPlaylistsProvider.notifier).addDownloadedTrack(track);

      return '${publicPath ?? "Downloads/Aniwhere/$fileName"} ($sizeMb MB)';
    } catch (_) {
      _clearProgress(trackId);
      return null;
    }
  }

  void _setProgress(String trackId, double progress) {
    final current = Map<String, double>.from(_ref.read(downloadProgressProvider));
    current[trackId] = progress;
    _ref.read(downloadProgressProvider.notifier).state = current;
  }

  void _clearProgress(String trackId) {
    final current = Map<String, double>.from(_ref.read(downloadProgressProvider));
    current.remove(trackId);
    _ref.read(downloadProgressProvider.notifier).state = current;
  }

  void removeDownload(String trackId) {
    final path = _filePaths.remove(trackId);
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    final updated = Map<String, DownloadQuality>.from(state);
    updated.remove(trackId);
    state = updated;
    _save();
  }

  void _save() {
    final map = state.map((k, v) => MapEntry(k, v.name));
    SettingsStorage.setString(_storageKey, jsonEncode(map));
    SettingsStorage.setString(_pathsKey, jsonEncode(_filePaths));
  }
}

final downloadedTracksProvider =
    StateNotifierProvider<DownloadedTracksNotifier, Map<String, DownloadQuality>>((ref) {
  return DownloadedTracksNotifier(ref);
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

  /// Automatically adds a downloaded track to the "Downloaded Songs" playlist
  void addDownloadedTrack(MusicTrack track) {
    const dlId = 'downloaded_playlist';
    final exists = state.any((p) => p.id == dlId);
    if (!exists) {
      final dlPl = MusicPlaylist(
        id: dlId,
        title: 'Downloaded Songs',
        description: 'Offline downloaded tracks',
        thumbnailUrl: track.albumArtUrl,
        tracks: [track],
        trackCount: 1,
      );
      state = [dlPl, ...state];
      _persist();
      return;
    }
    addTrackToPlaylist(dlId, track);
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

  /// Replace every playlist whose id starts with [prefix] (e.g. playlists
  /// imported from YouTube Music) with [playlists], keeping local ones intact.
  void replaceSyncedPlaylists(String prefix, List<MusicPlaylist> playlists) {
    state = [
      ...state.where((pl) => !pl.id.startsWith(prefix)),
      ...playlists,
    ];
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
