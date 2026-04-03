import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/tracker_status.dart';
import 'tracker_service.dart';

class KitsuTracker implements TrackerService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://kitsu.io/api/edge',
    headers: {
      'Accept': 'application/vnd.api+json',
      'Content-Type': 'application/vnd.api+json',
    },
  ));
  
  static const String _clientId = 'DUMMY_CLIENT_ID'; // Replace with real Kitsu Client ID
  static const String _callbackScheme = 'aniwhere';
  static const String _tokenPrefKey = 'kitsu_access_token';
  static const String _userPrefKey = 'kitsu_username';
  static const String _userIdPrefKey = 'kitsu_user_id';

  String? _accessToken;
  String? _username;
  String? _userId;

  KitsuTracker() {
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenPrefKey);
    _username = prefs.getString(_userPrefKey);
    _userId = prefs.getString(_userIdPrefKey);
    
    if (_accessToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  @override
  String get id => 'kitsu';

  @override
  String get name => 'Kitsu';

  @override
  bool get isLoggedIn => _accessToken != null;

  @override
  String? get username => _username;

  @override
  String get logoAsset => 'assets/icons/kitsu.png'; 

  @override
  Future<bool> authenticate() async {
    final url = 'https://kitsu.io/api/oauth/authorize?response_type=token&client_id=$_clientId&redirect_uri=$_callbackScheme://auth';
    
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
      
      // Fetch user profile
      await _fetchUserProfile();
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> _fetchUserProfile() async {
    if (_accessToken == null) return;
    
    try {
      final response = await _dio.get('/users?filter[self]=true');
      final data = response.data['data'] as List?;
      if (data != null && data.isNotEmpty) {
        _userId = data[0]['id'];
        _username = data[0]['attributes']['name'];
        
        final prefs = await SharedPreferences.getInstance();
        if (_userId != null) await prefs.setString(_userIdPrefKey, _userId!);
        if (_username != null) await prefs.setString(_userPrefKey, _username!);
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Future<void> logout() async {
    _accessToken = null;
    _username = null;
    _userId = null;
    _dio.options.headers.remove('Authorization');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefKey);
    await prefs.remove(_userPrefKey);
    await prefs.remove(_userIdPrefKey);
  }

  @override
  Future<Map<String, String>> search(String query, {bool isAnime = true}) async {
    try {
      final endpoint = isAnime ? '/anime' : '/manga';
      final response = await _dio.get(endpoint, queryParameters: {
        'filter[text]': query,
        'page[limit]': 10,
      });

      final mediaList = response.data['data'] as List? ?? [];
      final result = <String, String>{};
      
      for (final item in mediaList) {
        final title = item['attributes']['titles']['en'] ?? item['attributes']['titles']['en_jp'] ?? item['attributes']['canonicalTitle'];
        result[item['id'].toString()] = title;
      }
      
      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<TrackerStatus?> getStatus(String trackerMediaId) async {
    if (!isLoggedIn || _userId == null) return null;

    try {
      // Kitsu uses library-entries endpoint
      final response = await _dio.get('/library-entries', queryParameters: {
        'filter[userId]': _userId,
        'filter[animeId]': trackerMediaId, // In Kitsu, animeId and mangaId overlap in library-entries, so this needs to be checked carefully. We'll try anime first.
      });

      var entries = response.data['data'] as List?;
      
      // If none found, maybe it's manga
      if (entries == null || entries.isEmpty) {
        final mangaResp = await _dio.get('/library-entries', queryParameters: {
          'filter[userId]': _userId,
          'filter[mangaId]': trackerMediaId,
        });
        entries = mangaResp.data['data'] as List?;
      }

      if (entries == null || entries.isEmpty) return null;

      final entry = entries[0]['attributes'];
      final progress = entry['progress'] ?? 0;
      final status = entry['status'];
      final rating = entry['ratingTwenty']; // 2-20 scale

      int? score;
      if (rating != null) {
        score = rating ~/ 2; // Convert to 1-10
      }

      return TrackerStatus(
        trackerId: id,
        mediaId: trackerMediaId,
        status: trackerStringToStatus(status),
        progress: progress,
        score: score,
        totalEpisodes: null, // Would need to fetch linked media object to get total
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateStatus(TrackerStatus status) async {
    if (!isLoggedIn || _userId == null) return;

    try {
      // Find the entry ID first
      final getResponse = await _dio.get('/library-entries', queryParameters: {
        'filter[userId]': _userId,
        'filter[animeId]': status.mediaId, 
      });
      
      var entries = getResponse.data['data'] as List?;
      String? entryId;
      String type = 'anime';
      
      if (entries == null || entries.isEmpty) {
        final mangaResp = await _dio.get('/library-entries', queryParameters: {
          'filter[userId]': _userId,
          'filter[mangaId]': status.mediaId,
        });
        entries = mangaResp.data['data'] as List?;
        type = 'manga';
      }

      final statusStr = statusToTrackerString(status.status);
      final scoreVal = status.score != null ? status.score! * 2 : null;

      if (entries == null || entries.isEmpty) {
        // Create new entry
        await _dio.post('/library-entries', data: {
          'data': {
            'type': 'libraryEntries',
            'attributes': {
              'status': statusStr,
              'progress': status.progress,
              if (scoreVal != null) 'ratingTwenty': scoreVal,
            },
            'relationships': {
              'user': {
                'data': {'type': 'users', 'id': _userId}
              },
              'media': {
                'data': {'type': type, 'id': status.mediaId}
              }
            }
          }
        });
      } else {
        // Update existing entry
        entryId = entries[0]['id'];
        await _dio.patch('/library-entries/$entryId', data: {
          'data': {
            'id': entryId,
            'type': 'libraryEntries',
            'attributes': {
              'status': statusStr,
              'progress': status.progress,
              if (scoreVal != null) 'ratingTwenty': scoreVal,
            }
          }
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  @override
  String statusToTrackerString(TrackerStatusValue status) {
    switch (status) {
      case TrackerStatusValue.reading:
        return 'current';
      case TrackerStatusValue.completed:
        return 'completed';
      case TrackerStatusValue.onHold:
        return 'on_hold';
      case TrackerStatusValue.dropped:
        return 'dropped';
      case TrackerStatusValue.planToRead:
        return 'planned';
      case TrackerStatusValue.unknown:
        return 'current';
    }
  }

  @override
  TrackerStatusValue trackerStringToStatus(String status) {
    switch (status) {
      case 'current':
        return TrackerStatusValue.reading;
      case 'completed':
        return TrackerStatusValue.completed;
      case 'on_hold':
        return TrackerStatusValue.onHold;
      case 'dropped':
        return TrackerStatusValue.dropped;
      case 'planned':
        return TrackerStatusValue.planToRead;
      default:
        return TrackerStatusValue.unknown;
    }
  }
}
