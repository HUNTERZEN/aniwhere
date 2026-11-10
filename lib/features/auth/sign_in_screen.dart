import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/native_bridge.dart';
import '../../core/theme/app_colors.dart';
import '../../ui/widgets/glass_app_bar.dart';
import 'auth_service.dart';

/// Google Sign-In screen for YouTube Music.
///
/// On Android, opens the Google login flow inside a WebView and automatically
/// captures the session cookies once the user lands on `music.youtube.com`.
/// Also provides a manual cookie paste fallback for desktop / power users.
class YtMusicSignInScreen extends ConsumerStatefulWidget {
  const YtMusicSignInScreen({super.key});

  @override
  ConsumerState<YtMusicSignInScreen> createState() => _YtMusicSignInScreenState();
}

class _YtMusicSignInScreenState extends ConsumerState<YtMusicSignInScreen> {
  static const String _loginUrl =
      'https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F';

  WebViewController? _controller;
  double _progress = 0;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        // Standard Chrome user-agent so Google's OAuth guard does not reject
        // the embedded WebView with `disallowed_useragent`.
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p / 100);
            },
            onPageFinished: _onPageFinished,
          ),
        )
        ..loadRequest(Uri.parse(_loginUrl));
    }
  }

  Future<void> _onPageFinished(String url) async {
    if (_verifying || !url.contains('youtube.com')) return;
    final cookie = await NativeBridge.getCookies('https://music.youtube.com');
    if (!YtMusicApi.isValidCookie(cookie)) return;
    await _finishWithCookie(cookie!);
  }

  Future<void> _finishWithCookie(String cookie) async {
    if (_verifying) return;
    setState(() => _verifying = true);
    final err = await ref.read(ytMusicAuthProvider.notifier).completeSignIn(cookie);
    if (!mounted) return;
    setState(() => _verifying = false);

    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _showManualCookieDialog() async {
    final ctrl = TextEditingController();
    final cookie = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste YouTube Music Cookie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open music.youtube.com in your browser, copy the Cookie request header '
              '(must include SAPISID), and paste it below.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'SAPISID=...; __Secure-3PAPISID=...;',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (cookie != null && cookie.isNotEmpty) {
      await _finishWithCookie(cookie);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Sign in to YouTube Music'),
        actions: [
          IconButton(
            tooltip: 'Paste cookie manually',
            icon: const Icon(Icons.key_rounded),
            onPressed: _showManualCookieDialog,
          ),
          if (_controller != null)
            IconButton(
              tooltip: 'Done',
              icon: const Icon(Icons.check_rounded),
              onPressed: () => _onPageFinished('https://music.youtube.com'),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Embedded sign-in is available on Android.\n'
                      'On desktop, connect by pasting your YouTube Music cookie.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _showManualCookieDialog,
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Paste Cookie'),
                    ),
                  ],
                ),
              ),
            ),
          if (_progress < 1.0 && _controller != null)
            LinearProgressIndicator(
              value: _progress,
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: Colors.transparent,
            ),
          if (_verifying)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Connecting your YouTube Music account…',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

