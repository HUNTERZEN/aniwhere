enum TrackerStatusValue {
  reading, // or watching
  completed,
  onHold,
  dropped,
  planToRead, // or planToWatch
  unknown;

  String get displayName {
    switch (this) {
      case TrackerStatusValue.reading:
        return 'Reading/Watching';
      case TrackerStatusValue.completed:
        return 'Completed';
      case TrackerStatusValue.onHold:
        return 'On Hold';
      case TrackerStatusValue.dropped:
        return 'Dropped';
      case TrackerStatusValue.planToRead:
        return 'Plan to Read/Watch';
      case TrackerStatusValue.unknown:
        return 'Unknown';
    }
  }
}

class TrackerStatus {
  final String trackerId;
  final String mediaId; // ID of the media on the tracker (e.g. MAL ID)
  final TrackerStatusValue status;
  final int progress;
  final int? score; // 0-10 or Custom, but we'll use 0-100 internally or similar. Usually 0 if unset.
  final int? totalEpisodes;

  const TrackerStatus({
    required this.trackerId,
    required this.mediaId,
    required this.status,
    required this.progress,
    this.score,
    this.totalEpisodes,
  });

  TrackerStatus copyWith({
    String? trackerId,
    String? mediaId,
    TrackerStatusValue? status,
    int? progress,
    int? score,
    int? totalEpisodes,
  }) {
    return TrackerStatus(
      trackerId: trackerId ?? this.trackerId,
      mediaId: mediaId ?? this.mediaId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      score: score ?? this.score,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
    );
  }
}
