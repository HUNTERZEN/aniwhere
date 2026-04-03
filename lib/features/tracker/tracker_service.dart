import '../../data/models/tracker_status.dart';

/// The base interface for a third-party tracking service (e.g. MyAnimeList, AniList)
abstract class TrackerService {
  /// Unique identifier for this tracker
  String get id;

  /// Display name of the tracker
  String get name;

  /// Returns true if the user is currently authenticated with this tracker
  bool get isLoggedIn;

  /// The user's username or display name if authenticated
  String? get username;

  /// Path to a local asset image representing the tracker logo
  String get logoAsset;

  /// Initiate the OAuth2 authentication flow
  Future<bool> authenticate();

  /// Log out and clear local credentials
  Future<void> logout();

  /// Search for a media item on the tracker by title to link it.
  /// Returns a map of tracker DB ID to Title.
  Future<Map<String, String>> search(String query, {bool isAnime = true});

  /// Get current status of a linked media item
  Future<TrackerStatus?> getStatus(String trackerMediaId);

  /// Update the status/progress on the tracker
  Future<void> updateStatus(TrackerStatus status);

  /// Helper to convert a standardized TrackerStatusValue to the tracker's specific API string
  String statusToTrackerString(TrackerStatusValue status);

  /// Helper to convert the tracker's specific API string to TrackerStatusValue
  TrackerStatusValue trackerStringToStatus(String status);
}
