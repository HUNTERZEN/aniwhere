import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tracker_service.dart';
import 'myanimelist_tracker.dart';
import 'anilist_tracker.dart';
import 'kitsu_tracker.dart';

/// Provider for MyAnimeList Tracker
final myAnimeListTrackerProvider = Provider<TrackerService>((ref) {
  return MyAnimeListTracker();
});

/// Provider for AniList Tracker
final aniListTrackerProvider = Provider<TrackerService>((ref) {
  return AniListTracker();
});

/// Provider for Kitsu Tracker
final kitsuTrackerProvider = Provider<TrackerService>((ref) {
  return KitsuTracker();
});

/// Provider that returns all registered trackers
final trackersProvider = Provider<List<TrackerService>>((ref) {
  return [
    ref.watch(myAnimeListTrackerProvider),
    ref.watch(aniListTrackerProvider),
    ref.watch(kitsuTrackerProvider),
  ];
});

/// A state notifier to force UI updates when authentication state changes
class TrackerStateNotifier extends StateNotifier<void> {
  TrackerStateNotifier() : super(null);

  void refresh() {
    state = null; // Triggers rebuilds for listeners
  }
}

final trackerStateProvider = StateNotifierProvider<TrackerStateNotifier, void>((ref) {
  return TrackerStateNotifier();
});
