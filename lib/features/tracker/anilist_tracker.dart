import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/tracker_status.dart';
import 'tracker_service.dart';

class AniListTracker implements TrackerService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://graphql.anilist.co'));
  
  static const String _clientId = '38439'; 
  static const String _callbackScheme = 'aniwhere';
  static const String _tokenPrefKey = 'anilist_access_token';
  static const String _userPrefKey = 'anilist_username';

  String? _accessToken;
  String? _username;

  AniListTracker() {
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenPrefKey);
    _username = prefs.getString(_userPrefKey);
    
    if (_accessToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  @override
  String get id => 'anilist';

  @override
  String get name => 'AniList';

  @override
  bool get isLoggedIn => _accessToken != null;

  @override
  String? get username => _username;

  @override
  String get logoAsset => 'assets/icons/anilist.png'; // Make sure to add this asset later

  @override
  Future<bool> authenticate() async {
    final url = 'https://anilist.co/api/v2/oauth/authorize?client_id=$_clientId&response_type=token';
    
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: _callbackScheme,
      );

      final token = Uri.parse(result).fragment
          .split('&')
          .firstWhere((e) => e.startsWith('access_token='))
          .split('=')[1];

      _accessToken = token;
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenPrefKey, token);
      
      // Fetch user profile to get username
      await _fetchUserProfile();
      
      return true;
    } catch (e) {
      // Auth failed or cancelled
      return false;
    }
  }
  
  Future<void> _fetchUserProfile() async {
    if (_accessToken == null) return;
    
    try {
      final query = '''
        query {
          Viewer {
            name
          }
        }
      ''';
      
      final response = await _dio.post('', data: {'query': query});
      if (response.data['data']?['Viewer']?['name'] != null) {
        _username = response.data['data']['Viewer']['name'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userPrefKey, _username!);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Future<void> logout() async {
    _accessToken = null;
    _username = null;
    _dio.options.headers.remove('Authorization');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefKey);
    await prefs.remove(_userPrefKey);
  }

  @override
  Future<Map<String, String>> search(String query, {bool isAnime = true}) async {
    final gqlQuery = '''
      query (\$search: String, \$type: MediaType) {
        Page(page: 1, perPage: 10) {
          media(search: \$search, type: \$type) {
            id
            title {
              romaji
              english
            }
          }
        }
      }
    ''';
    
    final variables = {
      'search': query,
      'type': isAnime ? 'ANIME' : 'MANGA',
    };

    try {
      final response = await _dio.post('', data: {
        'query': gqlQuery,
        'variables': variables,
      });

      final mediaList = response.data['data']?['Page']?['media'] as List? ?? [];
      final result = <String, String>{};
      
      for (final item in mediaList) {
        final title = item['title']['english'] ?? item['title']['romaji'] ?? 'Unknown';
        result[item['id'].toString()] = title;
      }
      
      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<TrackerStatus?> getStatus(String trackerMediaId) async {
    if (!isLoggedIn) return null;

    final query = '''
      query (\$mediaId: Int) {
        MediaList(mediaId: \$mediaId) {
          status
          progress
          score(format: POINT_100)
          media {
            episodes
            chapters
          }
        }
      }
    ''';
    
    try {
      final response = await _dio.post('', data: {
        'query': query,
        'variables': {'mediaId': int.parse(trackerMediaId)},
      });

      final mediaList = response.data['data']?['MediaList'];
      if (mediaList == null) return null;

      return TrackerStatus(
        trackerId: id,
        mediaId: trackerMediaId,
        status: trackerStringToStatus(mediaList['status']),
        progress: mediaList['progress'] ?? 0,
        score: mediaList['score'],
        totalEpisodes: mediaList['media']['episodes'] ?? mediaList['media']['chapters'],
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        // Not on list yet
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> updateStatus(TrackerStatus status) async {
    if (!isLoggedIn) return;

    final mutation = '''
      mutation (\$mediaId: Int, \$progress: Int, \$status: MediaListStatus, \$score: Float) {
        SaveMediaListEntry(mediaId: \$mediaId, progress: \$progress, status: \$status, scoreRaw: \$score) {
          id
          status
          progress
        }
      }
    ''';
    
    final variables = {
      'mediaId': int.parse(status.mediaId),
      'progress': status.progress,
      'status': statusToTrackerString(status.status),
      if (status.score != null) 'score': status.score! * 10, // Assuming score is 0-10 internally, saving as POINT_100
    };

    await _dio.post('', data: {
      'query': mutation,
      'variables': variables,
    });
  }

  @override
  String statusToTrackerString(TrackerStatusValue status) {
    switch (status) {
      case TrackerStatusValue.reading:
        return 'CURRENT';
      case TrackerStatusValue.completed:
        return 'COMPLETED';
      case TrackerStatusValue.onHold:
        return 'PAUSED';
      case TrackerStatusValue.dropped:
        return 'DROPPED';
      case TrackerStatusValue.planToRead:
        return 'PLANNING';
      case TrackerStatusValue.unknown:
        return 'CURRENT';
    }
  }

  @override
  TrackerStatusValue trackerStringToStatus(String status) {
    switch (status) {
      case 'CURRENT':
        return TrackerStatusValue.reading;
      case 'COMPLETED':
        return TrackerStatusValue.completed;
      case 'PAUSED':
        return TrackerStatusValue.onHold;
      case 'DROPPED':
        return TrackerStatusValue.dropped;
      case 'PLANNING':
        return TrackerStatusValue.planToRead;
      default:
        return TrackerStatusValue.unknown;
    }
  }
}
