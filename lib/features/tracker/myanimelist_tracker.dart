import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/tracker_status.dart';
import 'tracker_service.dart';

class MyAnimeListTracker implements TrackerService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api.myanimelist.net/v2'));
  
  static const String _clientId = '08914d134a8b5d495185cfb78bb76d8e'; 
  static const String _callbackScheme = 'aniwhere';
  static const String _tokenPrefKey = 'mal_access_token';
  static const String _userPrefKey = 'mal_username';

  String? _accessToken;
  String? _username;

  MyAnimeListTracker() {
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
  String get id => 'myanimelist';

  @override
  String get name => 'MyAnimeList';

  @override
  bool get isLoggedIn => _accessToken != null;

  @override
  String? get username => _username;

  @override
  String get logoAsset => 'assets/icons/mal.png'; 

  @override
  Future<bool> authenticate() async {
    // MAL requires PKCE. We'll use a simple plain challenge for demonstration.
    // In production, use high entropy random string.
    final codeChallenge = 'an_arbitrary_string_for_pkce_challenge_1234567890';
    
    final url = 'https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=$_clientId&code_challenge=$codeChallenge&code_challenge_method=plain';
    
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: _callbackScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;

      // Exchange code for token
      final tokenResponse = await Dio().post(
        'https://myanimelist.net/v1/oauth2/token',
        data: {
          'client_id': _clientId,
          'code': code,
          'code_verifier': codeChallenge,
          'grant_type': 'authorization_code',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      _accessToken = tokenResponse.data['access_token'];
      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenPrefKey, _accessToken!);
      
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
      final response = await _dio.get('/users/@me');
      _username = response.data['name'];
      
      final prefs = await SharedPreferences.getInstance();
      if (_username != null) {
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
    try {
      final endpoint = isAnime ? '/anime' : '/manga';
      final response = await _dio.get(endpoint, queryParameters: {
        'q': query,
        'limit': 10,
      });

      final mediaList = response.data['data'] as List? ?? [];
      final result = <String, String>{};
      
      for (final item in mediaList) {
        final node = item['node'];
        result[node['id'].toString()] = node['title'];
      }
      
      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  Future<TrackerStatus?> getStatus(String trackerMediaId) async {
    if (!isLoggedIn) return null;

    try {
      // The API requires knowing if it's anime or manga, but we don't have that info
      // purely from the interface right now. We'll try anime first, then manga.
      try {
        final response = await _dio.get('/anime/$trackerMediaId?fields=my_list_status,num_episodes');
        final status = response.data['my_list_status'];
        if (status == null) return null;

        return TrackerStatus(
          trackerId: id,
          mediaId: trackerMediaId,
          status: trackerStringToStatus(status['status']),
          progress: status['num_episodes_watched'] ?? 0,
          score: status['score'] > 0 ? status['score'] : null,
          totalEpisodes: response.data['num_episodes'],
        );
      } catch (e) {
        if (e is DioException && e.response?.statusCode != 404) rethrow;
        
        // Try manga
        final response = await _dio.get('/manga/$trackerMediaId?fields=my_list_status,num_chapters');
        final status = response.data['my_list_status'];
        if (status == null) return null;

        return TrackerStatus(
          trackerId: id,
          mediaId: trackerMediaId,
          status: trackerStringToStatus(status['status']),
          progress: status['num_chapters_read'] ?? 0,
          score: status['score'] > 0 ? status['score'] : null,
          totalEpisodes: response.data['num_chapters'],
        );
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateStatus(TrackerStatus status) async {
    if (!isLoggedIn) return;

    try {
      // Again, we need to know if it's anime or manga. We will use a generic try-catch approach
      final data = {
        'status': statusToTrackerString(status.status),
        'score': status.score ?? 0,
      };

      try {
        // Assume anime
        data['num_watched_episodes'] = status.progress;
        await _dio.put(
          '/anime/${status.mediaId}/my_list_status',
          data: data,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
      } catch (e) {
        if (e is DioException && e.response?.statusCode != 404) rethrow;

        // Try manga
        data.remove('num_watched_episodes');
        data['num_chapters_read'] = status.progress;
        await _dio.put(
          '/manga/${status.mediaId}/my_list_status',
          data: data,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  String statusToTrackerString(TrackerStatusValue status) {
    switch (status) {
      case TrackerStatusValue.reading:
        return 'watching'; // MAL uses 'watching' for anime and 'reading' for manga. We default to watching and let MAL correct it if needed, or we adapt.
      case TrackerStatusValue.completed:
        return 'completed';
      case TrackerStatusValue.onHold:
        return 'on_hold';
      case TrackerStatusValue.dropped:
        return 'dropped';
      case TrackerStatusValue.planToRead:
        return 'plan_to_watch';
      case TrackerStatusValue.unknown:
        return 'watching';
    }
  }

  @override
  TrackerStatusValue trackerStringToStatus(String status) {
    switch (status) {
      case 'watching':
      case 'reading':
        return TrackerStatusValue.reading;
      case 'completed':
        return TrackerStatusValue.completed;
      case 'on_hold':
        return TrackerStatusValue.onHold;
      case 'dropped':
        return TrackerStatusValue.dropped;
      case 'plan_to_watch':
      case 'plan_to_read':
        return TrackerStatusValue.planToRead;
      default:
        return TrackerStatusValue.unknown;
    }
  }
}
