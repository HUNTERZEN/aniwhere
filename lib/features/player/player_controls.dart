import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/sources/source.dart';
import 'player_providers.dart';

class PlayerControls extends ConsumerStatefulWidget {
  final PlayerStateNotifier notifier;
  final PlayerState state;

  const PlayerControls({
    super.key,
    required this.notifier,
    required this.state,
  });

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  bool _isDragging = false;
  double _dragValue = 0;

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.showControls) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: widget.notifier.onUserInteraction,
      onPanDown: (_) => widget.notifier.onUserInteraction(),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Column(
          children: [
            _buildTopBar(),
            const Spacer(),
            _buildCenterControls(),
            const Spacer(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final currentEpisode = widget.notifier.params.episodes[widget.state.currentEpisodeIndex];
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentEpisode.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Episode ${currentEpisode.number?.toStringAsFixed(0) ?? '?' }',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Skip Intro Button
            if (widget.state.duration.inSeconds > 90)
              TextButton(
                onPressed: widget.notifier.skipIntro,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Skip Intro +85s', style: TextStyle(color: Colors.white)),
              ),
              
            const SizedBox(width: 8),
            
            // Quality Selector
            if (widget.state.streams.isNotEmpty)
              PopupMenuButton<SourceVideo>(
                icon: const Icon(Icons.high_quality, color: Colors.white),
                tooltip: 'Quality',
                initialValue: widget.state.currentStream,
                onSelected: widget.notifier.changeQuality,
                itemBuilder: (context) {
                  return widget.state.streams.map((stream) {
                    return PopupMenuItem<SourceVideo>(
                      value: stream,
                      child: Text(
                        stream.quality.toUpperCase(),
                        style: TextStyle(
                          fontWeight: stream == widget.state.currentStream
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: stream == widget.state.currentStream
                              ? AppColors.primary
                              : null,
                        ),
                      ),
                    );
                  }).toList();
                },
              ),

            // Speed Selector  
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed, color: Colors.white),
              tooltip: 'Playback Speed',
              initialValue: widget.state.playbackSpeed,
              onSelected: widget.notifier.setPlaybackSpeed,
              itemBuilder: (context) {
                return [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                  return PopupMenuItem<double>(
                    value: speed,
                    child: Text(
                      '${speed}x',
                      style: TextStyle(
                        fontWeight: speed == widget.state.playbackSpeed
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: speed == widget.state.playbackSpeed
                            ? AppColors.primary
                            : null,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
            
            // Episodes Sidebar Toggle
            IconButton(
              icon: const Icon(Icons.list, color: Colors.white),
              onPressed: widget.notifier.toggleSidebar,
              tooltip: 'Episodes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous Episode
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 48, color: Colors.white),
          onPressed: widget.notifier.canGoPrevEpisode()
              ? widget.notifier.playPrevEpisode
              : null,
          color: Colors.white,
          disabledColor: Colors.white30,
        ),
        const SizedBox(width: 32),
        
        // Rewind 10s
        IconButton(
          icon: const Icon(Icons.replay_10, size: 48, color: Colors.white),
          onPressed: () => widget.notifier.seekRelative(const Duration(seconds: -10)),
        ),
        const SizedBox(width: 32),
        
        // Play/Pause
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              widget.state.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 64,
              color: Colors.white,
            ),
            onPressed: widget.notifier.playOrPause,
          ),
        ),
        const SizedBox(width: 32),
        
        // Forward 10s
        IconButton(
          icon: const Icon(Icons.forward_10, size: 48, color: Colors.white),
          onPressed: () => widget.notifier.seekRelative(const Duration(seconds: 10)),
        ),
        const SizedBox(width: 32),
        
        // Next Episode
        IconButton(
          icon: const Icon(Icons.skip_next, size: 48, color: Colors.white),
          onPressed: widget.notifier.canGoNextEpisode()
              ? widget.notifier.playNextEpisode
              : null,
          color: Colors.white,
          disabledColor: Colors.white30,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final position = widget.state.position;
    final duration = widget.state.duration;
    final buffered = widget.state.buffered;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Text(
              _formatDuration(position),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Buffered indicator
                  if (duration.inMilliseconds > 0)
                    LinearProgressIndicator(
                      value: buffered.inMilliseconds / duration.inMilliseconds,
                      backgroundColor: Colors.white24,
                      color: Colors.white54,
                      minHeight: 4,
                    ),
                  
                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withOpacity(0.3),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _isDragging
                          ? _dragValue
                          : position.inMilliseconds.toDouble(),
                      max: duration.inMilliseconds > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1.0, // avoid division by zero
                      min: 0,
                      onChangeStart: (value) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                        widget.notifier.onUserInteraction();
                      },
                      onChanged: (value) {
                        setState(() {
                          _dragValue = value;
                        });
                        widget.notifier.onUserInteraction();
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          _isDragging = false;
                        });
                        widget.notifier.seekTo(Duration(milliseconds: value.toInt()));
                        widget.notifier.onUserInteraction();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(duration),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
