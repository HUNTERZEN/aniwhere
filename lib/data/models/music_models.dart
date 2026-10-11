class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final Duration duration;
  final String streamUrl;
  final String? encryptedMediaUrl;
  final AudioQuality quality;
  final String? lyricsUrl;
  final bool isLossless;
  final int? bitrate;
  final int? sampleRate;
  final String? codec;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    required this.duration,
    required this.streamUrl,
    this.encryptedMediaUrl,
    this.quality = AudioQuality.high,
    this.lyricsUrl,
    this.isLossless = false,
    this.bitrate,
    this.sampleRate,
    this.codec,
  });

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    Duration? duration,
    String? streamUrl,
    String? encryptedMediaUrl,
    AudioQuality? quality,
    String? lyricsUrl,
    bool? isLossless,
    int? bitrate,
    int? sampleRate,
    String? codec,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      encryptedMediaUrl: encryptedMediaUrl ?? this.encryptedMediaUrl,
      quality: quality ?? this.quality,
      lyricsUrl: lyricsUrl ?? this.lyricsUrl,
      isLossless: isLossless ?? this.isLossless,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      codec: codec ?? this.codec,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumArtUrl': albumArtUrl,
    'durationMs': duration.inMilliseconds,
    'streamUrl': streamUrl,
    'encryptedMediaUrl': encryptedMediaUrl,
    'quality': quality.name,
    'lyricsUrl': lyricsUrl,
    'isLossless': isLossless,
    'bitrate': bitrate,
    'sampleRate': sampleRate,
    'codec': codec,
  };

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String? ?? '',
    album: json['album'] as String? ?? '',
    albumArtUrl: json['albumArtUrl'] as String?,
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    streamUrl: json['streamUrl'] as String? ?? '',
    encryptedMediaUrl: json['encryptedMediaUrl'] as String?,
    quality: AudioQuality.values.firstWhere(
      (q) => q.name == json['quality'],
      orElse: () => AudioQuality.high,
    ),
    lyricsUrl: json['lyricsUrl'] as String?,
    isLossless: json['isLossless'] as bool? ?? false,
    bitrate: json['bitrate'] as int?,
    sampleRate: json['sampleRate'] as int?,
    codec: json['codec'] as String?,
  );
}

class MusicPlaylist {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final List<MusicTrack> tracks;
  final int trackCount;

  const MusicPlaylist({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.tracks = const [],
    this.trackCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'trackCount': tracks.length,
  };

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) {
    final trackList = (json['tracks'] as List? ?? [])
        .map((t) => MusicTrack.fromJson(t as Map<String, dynamic>))
        .toList();
    return MusicPlaylist(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tracks: trackList,
      trackCount: json['trackCount'] as int? ?? trackList.length,
    );
  }
}

/// Albums & singles model (e.g. AUJLA SZN 1, Loser, Dracula)
class MusicAlbumItem {
  final String id;
  final String title;
  final String artist;
  final String type; // 'Album', 'Single', 'EP'
  final String? year;
  final String? thumbnailUrl;
  final List<MusicTrack> tracks;

  const MusicAlbumItem({
    required this.id,
    required this.title,
    required this.artist,
    this.type = 'Album',
    this.year,
    this.thumbnailUrl,
    this.tracks = const [],
  });
}

/// Audio streaming quality levels 
enum AudioQuality {
  low(label: 'Low', detail: '~64 kbps · saves data', maxKbps: 64),
  medium(label: 'Medium', detail: '~128 kbps · balanced', maxKbps: 128),
  high(label: 'High', detail: '~256 kbps · great quality', maxKbps: 256),
  lossless(label: 'Lossless', detail: 'FLAC/ALAC · bit-perfect', maxKbps: 9216);

  final String label;
  final String detail;
  final int maxKbps;

  const AudioQuality({
    required this.label,
    required this.detail,
    required this.maxKbps,
  });
}

/// Download quality levels
enum DownloadQuality {
  low(label: 'Low', detail: '~64-128 kbps · saves data', perTrack: '~3 MB'),
  high(label: 'High', detail: '~256-320 kbps · high quality', perTrack: '~8 MB'),
  lossless(label: 'Lossless', detail: 'FLAC / 24-bit · bit-perfect', perTrack: '~35 MB');

  final String label;
  final String detail;
  final String perTrack;

  const DownloadQuality({
    required this.label,
    required this.detail,
    required this.perTrack,
  });
}

/// PCM output mode 
enum OutputPcmMode {
  pcm16('16-bit PCM'),
  float32('32-bit float');

  final String label;
  const OutputPcmMode(this.label);
}

/// Repeat mode for music player
enum MusicRepeatMode {
  off,
  all,
  one,
}

/// Lyrics sync line
class LyricLine {
  final Duration timestamp;
  final String text;
  final List<LyricWord>? words;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.words,
  });
}

/// Word-level lyric sync
class LyricWord {
  final Duration start;
  final Duration end;
  final String text;

  const LyricWord({
    required this.start,
    required this.end,
    required this.text,
  });
}

/// Now playing state
class NowPlayingState {
  final MusicTrack? currentTrack;
  final List<MusicTrack> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration bufferedPosition;
  final bool isShuffled;
  final MusicRepeatMode repeatMode;
  final double volume;
  final double playbackSpeed;
  final bool isLoading;

  const NowPlayingState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.isShuffled = false,
    this.repeatMode = MusicRepeatMode.off,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.isLoading = false,
  });

  NowPlayingState copyWith({
    MusicTrack? currentTrack,
    List<MusicTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? bufferedPosition,
    bool? isShuffled,
    MusicRepeatMode? repeatMode,
    double? volume,
    double? playbackSpeed,
    bool? isLoading,
  }) {
    return NowPlayingState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get hasTrack => currentTrack != null;
  bool get hasNext => currentIndex < queue.length - 1;
  bool get hasPrevious => currentIndex > 0;
  double get progress =>
      currentTrack != null && currentTrack!.duration.inMilliseconds > 0
          ? position.inMilliseconds / currentTrack!.duration.inMilliseconds
          : 0.0;
}
