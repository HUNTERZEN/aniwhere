import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper around the `com.aniwhere/native` platform channel.
///
/// Exposes a few small native capabilities that are not covered by the
/// plugins the app already depends on:
///  * Reading WebView cookies (incl. HttpOnly) for the YouTube Music sign-in
///  * Clearing WebView cookies on sign-out
///  * Detecting whether the active network is cellular (audio quality)
///  * Keeping the screen awake (reader setting)
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.aniwhere/native');

  static bool get _supported => Platform.isAndroid;

  /// Returns the raw `Cookie` header string the system WebView holds for [url].
  static Future<String?> getCookies(String url) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('getCookies', {'url': url});
    } catch (_) {
      return null;
    }
  }

  /// Removes every cookie stored by the system WebView.
  static Future<void> clearCookies() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('clearCookies');
    } catch (_) {}
  }

  /// True when the active connection is a cellular (metered mobile) network.
  static Future<bool> isCellular() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isCellular') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Keeps the display on while [enabled] is true.
  static Future<void> setKeepScreenOn(bool enabled) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('setKeepScreenOn', {'enabled': enabled});
    } catch (_) {}
  }

  /// Copies a downloaded file at [filePath] into the public `Download/Aniwhere/` folder on Android.
  static Future<String?> saveToDownloads({
    required String filePath,
    required String fileName,
    String mimeType = 'audio/mp4',
  }) async {
    if (!_supported) return filePath;
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'filePath': filePath,
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } catch (_) {
      return filePath;
    }
  }
}

