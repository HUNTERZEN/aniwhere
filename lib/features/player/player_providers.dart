import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/repositories/chapter_repository.dart';
import '../../data/sources/source.dart';

// ============================================================================
// Player Data Providers
// ============================================================================

/// Parameters needed to open the player
class PlayerParams {
  final Source source;
  final String mediaId;
  final String episodeId;
  final List<SourceChapter> episodes;
  final int initialEpisodeIndex;

  const PlayerParams({
    required this.source,
    required this.mediaId,
    required this.episodeId,
    required this.episodes,
    required this.initialEpisodeIndex,
  });

  /// The source ID used for Isar storage: "sourceName:mediaId"
  String get entrySourceId => '${source.id}:$mediaId';
}

/// Provides video streams for a given episode from the source
final videoStreamsProvider = FutureProvider.family<List<SourceVideo>, (Source, String)>(
  (ref, params) async {
    final (source, episodeId) = params;
    if (source is WatchableSource) {
      return source.getVideoStreams(episodeId);
    }
    throw Exception('Source ${source.id} is not a watchable source');
  },
);

// ============================================================================
// Player State Notifier
// ============================================================================

class PlayerState {
  final bool isLoading;
  final String? error;
  final int currentEpisodeIndex;
  final bool showControls;
  final bool isSidebarOpen;
  final List<SourceVideo> streams;
  final SourceVideo? currentStream;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool isPlaying;
  final double playbackSpeed;
  final bool isFullscreen;

  const PlayerState({
    this.isLoading = true,
    this.error,
    this.currentEpisodeIndex = 0,
    this.showControls = true,
    this.isSidebarOpen = false,
    this.streams = const [],
    this.currentStream,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.isFullscreen = true,
  });

  PlayerState copyWith({
    bool? isLoading,
    String? error,
    int? currentEpisodeIndex,
    bool? showControls,
    bool? isSidebarOpen,
    List<SourceVideo>? streams,
    SourceVideo? currentStream,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? isPlaying,
    double? playbackSpeed,
    bool? isFullscreen,
  }) {
    return PlayerState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentEpisodeIndex: currentEpisodeIndex ?? this.currentEpisodeIndex,
      showControls: showControls ?? this.showControls,
      isSidebarOpen: isSidebarOpen ?? this.isSidebarOpen,
      streams: streams ?? this.streams,
      currentStream: currentStream ?? this.currentStream,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isFullscreen: isFullscreen ?? this.isFullscreen,
    );
  }
}

class PlayerStateNotifier extends StateNotifier<PlayerState> {
  final ChapterRepository _chapterRepo;
  final PlayerParams params;
  
  Player? _player;
  VideoController? _videoController;
  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  List<StreamSubscription> _subscriptions = [];

  PlayerStateNotifier({
    required this.params,
    required ChapterRepository chapterRepo,
  })  : _chapterRepo = chapterRepo,
        super(PlayerState(currentEpisodeIndex: params.initialEpisodeIndex)) {
    _initPlayer();
  }

  /// Public accessor for the current state
  PlayerState get currentState => state;
  
  Player? get player => _player;
  VideoController? get videoController => _videoController;

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    _cancelSubscriptions();
    
    // Save final progress
    saveProgressNow();
    
    _player?.dispose();
    super.dispose();
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _initPlayer() async {
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'Aniwhere Player',
      ),
    );
    _videoController = VideoController(_player!);

    // Listen to player state changes
    _subscriptions.addAll([
      _player!.stream.position.listen((position) {
        if (!mounted) return;
        state = state.copyWith(position: position);
      }),
      _player!.stream.duration.listen((duration) {
        if (!mounted) return;
        state = state.copyWith(duration: duration);
      }),
      _player!.stream.buffer.listen((buffered) {
        if (!mounted) return;
        state = state.copyWith(buffered: buffered);
      }),
      _player!.stream.playing.listen((playing) {
        if (!mounted) return;
        state = state.copyWith(isPlaying: playing);
        if (playing) {
          _queueHideControls();
        } else {
          _hideControlsTimer?.cancel();
        }
      }),
      _player!.stream.rate.listen((rate) {
        if (!mounted) return;
        state = state.copyWith(playbackSpeed: rate);
      }),
      _player!.stream.error.listen((error) {
        if (!mounted) return;
        setError('Player error: $error');
      }),
      // Handle end of video
      _player!.stream.completed.listen((completed) {
        if (!mounted || !completed) return;
        // Mark as fully read/watched
        _markCurrentAsWatched();
        
        // Auto-play next episode if available?
        // Let's just show controls for now
        showControls();
      }),
    ]);

    // Setup periodic saving
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveProgress();
    });

    await _loadEpisode();
  }

  Future<void> _loadEpisode() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final currentEpisode = params.episodes[state.currentEpisodeIndex];
    
    try {
      final source = params.source;
      if (source is! WatchableSource) {
        setError('Source is not watchable');
        return;
      }

      final streams = await source.getVideoStreams(currentEpisode.id);
      if (!mounted) return;
      
      if (streams.isEmpty) {
        setError('No video streams found for this episode');
        return;
      }

      // Try to find 1080p, then 720p, else use the first one
      SourceVideo? selectedStream;
      for (final stream in streams) {
        final q = stream.quality?.toLowerCase() ?? '';
        if (q.contains('1080')) {
          selectedStream = stream;
          break;
        } else if (q.contains('720') && selectedStream == null) {
          selectedStream = stream;
        } else if (q.contains('default') && selectedStream == null) {
          selectedStream = stream;
        }
      }
      
      selectedStream ??= streams.first;

      state = state.copyWith(
        streams: streams,
        currentStream: selectedStream,
        isLoading: false,
      );

      // Restore saved progress
      final stored = await _chapterRepo.getChapter(
        params.entrySourceId,
        currentEpisode.id,
      );
      
      Duration startPosition = Duration.zero;
      if (stored != null && stored.progress > 0) {
        startPosition = Duration(seconds: stored.progress);
      }

      // Load media into player
      final media = Media(
        selectedStream.url,
        httpHeaders: selectedStream.headers,
      );
      
      await _player?.open(media, play: true);
      
      if (startPosition > Duration.zero) {
        await _player?.seek(startPosition);
      }

    } catch (e) {
      if (mounted) {
        setError('Failed to load episode: $e');
      }
    }
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  // == Controls ==

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
    if (state.showControls && state.isPlaying) {
      _queueHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }
  
  void showControls() {
    state = state.copyWith(showControls: true);
    if (state.isPlaying) {
      _queueHideControls();
    }
  }

  void hideControls() {
    state = state.copyWith(showControls: false);
  }

  void _queueHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && state.isPlaying && !state.isSidebarOpen) {
        hideControls();
      }
    });
  }

  void onUserInteraction() {
    showControls();
  }

  // == Playback ==

  void playOrPause() {
    _player?.playOrPause();
  }

  void seekTo(Duration position) {
    _player?.seek(position);
  }

  void seekRelative(Duration amount) {
    final newPos = state.position + amount;
    _player?.seek(newPos);
  }

  void setPlaybackSpeed(double speed) {
    _player?.setRate(speed);
  }
  
  void skipIntro() {
    // Arbitrary 85 seconds skip. We could implement Aniskip API in the future.
    seekRelative(const Duration(seconds: 85));
  }
  
  void changeQuality(SourceVideo stream) async {
    if (stream.url == state.currentStream?.url) return;
    
    final currentPos = state.position;
    final isPlaying = state.isPlaying;
    
    state = state.copyWith(currentStream: stream, isLoading: true);
    
    final media = Media(
      stream.url,
      httpHeaders: stream.headers,
    );
    
    await _player?.open(media, play: isPlaying);
    await _player?.seek(currentPos);
    
    state = state.copyWith(isLoading: false);
  }

  // == Episodes ==

  void toggleSidebar() {
    state = state.copyWith(isSidebarOpen: !state.isSidebarOpen);
    if (state.isSidebarOpen) {
      _hideControlsTimer?.cancel();
    } else {
      _queueHideControls();
    }
  }

  bool canGoNextEpisode() {
    // Episodes are usually returned in descending order (latest first).
    // So "next" episode means index - 1
    return state.currentEpisodeIndex > 0;
  }

  bool canGoPrevEpisode() {
    return state.currentEpisodeIndex < params.episodes.length - 1;
  }

  void playNextEpisode() {
    if (canGoNextEpisode()) {
      switchEpisode(state.currentEpisodeIndex - 1);
    }
  }

  void playPrevEpisode() {
    if (canGoPrevEpisode()) {
      switchEpisode(state.currentEpisodeIndex + 1);
    }
  }

  void switchEpisode(int newIndex) async {
    // Save progress of current before switching
    await _saveProgress();
    
    state = state.copyWith(
      currentEpisodeIndex: newIndex,
      position: Duration.zero,
      duration: Duration.zero,
      streams: [],
      currentStream: null,
    );
    
    await _loadEpisode();
  }

  // == Progress ==

  Future<void> _saveProgress() async {
    if (state.duration == Duration.zero) return;
    
    final currentEpisode = params.episodes[state.currentEpisodeIndex];
    try {
      await _chapterRepo.saveProgress(
        entrySourceId: params.entrySourceId,
        chapterId: currentEpisode.id,
        currentPage: state.position.inSeconds,
        totalPages: state.duration.inSeconds,
        title: currentEpisode.title,
        number: currentEpisode.number,
      );
    } catch (e) {
      // Silently fail
    }
  }
  
  Future<void> _markCurrentAsWatched() async {
    final currentEpisode = params.episodes[state.currentEpisodeIndex];
    try {
      await _chapterRepo.markAsRead(
        params.entrySourceId,
        currentEpisode.id,
      );
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> saveProgressNow() async {
    await _saveProgress();
  }
}

/// Provider for the player state notifier, scoped per session
final playerStateProvider =
    StateNotifierProvider.autoDispose<PlayerStateNotifier, PlayerState>(
  (ref) {
    throw UnimplementedError('playerStateProvider must be overridden');
  },
);
