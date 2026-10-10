import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Central persistent key-value storage backed by SharedPreferences
class SettingsStorage {
  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences instance
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('SettingsStorage.init() must be called before accessing prefs');
    }
    return _prefs!;
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  static Future<bool> setBool(String key, bool value) async {
    return (await _ensurePrefs()).setBool(key, value);
  }

  static double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  static Future<bool> setDouble(String key, double value) async {
    return (await _ensurePrefs()).setDouble(key, value);
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  static Future<bool> setInt(String key, int value) async {
    return (await _ensurePrefs()).setInt(key, value);
  }

  static String getString(String key, {String defaultValue = ''}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  static Future<bool> setString(String key, String value) async {
    return (await _ensurePrefs()).setString(key, value);
  }

  static List<String> getStringList(String key, {List<String> defaultValue = const []}) {
    return _prefs?.getStringList(key) ?? defaultValue;
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    return (await _ensurePrefs()).setStringList(key, value);
  }

  static Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!;
  }
}
