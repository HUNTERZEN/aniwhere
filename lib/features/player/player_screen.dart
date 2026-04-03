import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/providers.dart';
import 'player_providers.dart';
import 'player_controls.dart';
import 'episode_sidebar.dart';

/// Full-screen video player for anime episodes.
/// Wraps the inner player with a ProviderScope override so the
/// playerStateProvider is properly scoped to this session.
class PlayerScreen extends StatelessWidget {
  final PlayerParams params;

  const PlayerScreen({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        playerStateProvider.overrideWith((ref) {
          final chapterRepo = ref.read(chapterRepositoryProvider);
          final notifier = PlayerStateNotifier(
            params: params,
            chapterRepo: chapterRepo,
          );
          ref.onDispose(() {
            notifier.saveProgressNow();
          });
          return notifier;
        }),
      ],
      child: _PlayerScreenInner(),
    );
  }
}

class _PlayerScreenInner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PlayerScreenInner> createState() => _PlayerScreenInnerState();
}

class _PlayerScreenInnerState extends ConsumerState<_PlayerScreenInner> {
  // Cache notifier reference so we don't access ref after dispose
  late final PlayerStateNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(playerStateProvider.notifier);
    
    // Hide system UI for immersive viewing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore system UI on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Progress is saved via ProviderScope's ref.onDispose callback
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video Player
          if (notifier.videoController != null)
            Center(
              child: Video(
                controller: notifier.videoController!,
                controls: NoVideoControls, // We use our own custom controls
                fit: BoxFit.contain,
              ),
            ),

          // 2. Loading / Error states
          if (state.isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (state.error != null)
            _buildErrorView(state.error!),

          // 3. Custom Controls Overlay
          if (!state.isLoading && state.error == null)
            Positioned.fill(
              child: PlayerControls(
                notifier: notifier,
                state: state,
              ),
            ),

          // 4. Episode Sidebar
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: EpisodeSidebar(
              notifier: notifier,
              state: state,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _notifier.switchEpisode(_notifier.currentState.currentEpisodeIndex);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
