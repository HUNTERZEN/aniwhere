import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/providers.dart';
import '../../data/models/app_settings.dart';
import '../../data/sources/source.dart';
import 'reader_providers.dart';
import 'reader_settings_sheet.dart';

/// Full-screen manga/webtoon reader with multiple reading modes.
/// Wraps the inner reader with a ProviderScope override so the
/// readerStateProvider is properly scoped to this session.
class ReaderScreen extends StatelessWidget {
  final ReaderParams params;

  const ReaderScreen({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        readerStateProvider.overrideWith((ref) {
          final chapterRepo = ref.read(chapterRepositoryProvider);
          final settingsRepo = ref.read(settingsRepositoryProvider);
          final settings = ref.read(readerSettingsProvider);
          final notifier = ReaderStateNotifier(
            params: params,
            chapterRepo: chapterRepo,
            settingsRepo: settingsRepo,
            initialSettings: settings,
          );
          ref.onDispose(() {
            notifier.saveProgressNow();
          });
          return notifier;
        }),
      ],
      child: _ReaderScreenInner(params: params),
    );
  }
}

/// Inner reader that has access to the scoped provider
class _ReaderScreenInner extends ConsumerStatefulWidget {
  final ReaderParams params;

  const _ReaderScreenInner({required this.params});

  @override
  ConsumerState<_ReaderScreenInner> createState() => _ReaderScreenInnerState();
}

class _ReaderScreenInnerState extends ConsumerState<_ReaderScreenInner>
    with TickerProviderStateMixin {
  PageController? _pageController;
  ScrollController? _scrollController;
  List<SourcePage> _pages = [];
  bool _initialized = false;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();

    // Animations for controls fade
    _controlsAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeInOut,
    );
    _controlsAnimController.forward(); // Start with controls visible

    // Load the first chapter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChapter();
    });
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

    // Save progress before leaving
    ref.read(readerStateProvider.notifier).saveProgressNow();

    _pageController?.dispose();
    _scrollController?.dispose();
    _controlsAnimController.dispose();
    super.dispose();
  }

  /// Convenience getter for the notifier
  ReaderStateNotifier get _notifier =>
      ref.read(readerStateProvider.notifier);

  /// Load pages for the current chapter
  Future<void> _loadChapter() async {
    final state = ref.read(readerStateProvider);
    final chapterIndex = state.currentChapterIndex;
    final chapter = widget.params.chapters[chapterIndex];

    try {
      final source = widget.params.source;
      if (source is! ReadableSource) {
        _notifier.setError('Source is not readable');
        return;
      }

      final pages = await source.getPages(chapter.id);
      if (!mounted) return;

      setState(() {
        _pages = pages;
      });

      _notifier.setPagesLoaded(pages.length);

      // Restore saved progress
      await _notifier.restoreProgress();

      // Initialize page controller at the saved page
      _initControllers();
    } catch (e) {
      if (mounted) {
        _notifier.setError('Failed to load pages: $e');
      }
    }
  }

  /// Initialize/re-initialize page and scroll controllers
  void _initControllers() {
    final state = ref.read(readerStateProvider);

    _pageController?.dispose();
    _scrollController?.dispose();

    if (state.readerMode == ReaderMode.paged) {
      _pageController = PageController(initialPage: state.currentPage);
    } else {
      _scrollController = ScrollController();
    }

    if (!_initialized) {
      _initialized = true;
    }

    // Force rebuild
    if (mounted) setState(() {});
  }

  /// Switch to a different chapter
  Future<void> _switchChapter(int newIndex) async {
    _notifier.switchChapter(newIndex);
    setState(() {
      _pages = [];
      _initialized = false;
    });
    await _loadChapter();
  }

  /// Handle center-tap to toggle controls
  void _onCenterTap() {
    _notifier.toggleControls();
    final state = ref.read(readerStateProvider);
    if (state.showControls) {
      _controlsAnimController.forward();
    } else {
      _controlsAnimController.reverse();
    }
  }

  /// Handle left/right tap for paged navigation
  void _onLeftTap() {
    final state = ref.read(readerStateProvider);
    if (state.readerMode != ReaderMode.paged) return;

    if (state.readingDirection == ReadingDirection.rightToLeft) {
      _goToNextPage();
    } else {
      _goToPrevPage();
    }
  }

  void _onRightTap() {
    final state = ref.read(readerStateProvider);
    if (state.readerMode != ReaderMode.paged) return;

    if (state.readingDirection == ReadingDirection.rightToLeft) {
      _goToPrevPage();
    } else {
      _goToNextPage();
    }
  }

  void _goToNextPage() {
    final state = ref.read(readerStateProvider);
    if (state.currentPage < state.totalPages - 1) {
      final nextPage = state.currentPage + 1;
      _pageController?.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPrevPage() {
    final state = ref.read(readerStateProvider);
    if (state.currentPage > 0) {
      final prevPage = state.currentPage - 1;
      _pageController?.animateToPage(
        prevPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Show the settings bottom sheet
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Wrap in Consumer to reactively read the scoped provider
        return Consumer(
          builder: (ctx, ref, _) {
            final state = ref.watch(readerStateProvider);
            final notifier = ref.read(readerStateProvider.notifier);
            return ReaderSettingsSheet(
              notifier: notifier,
              state: state,
            );
          },
        );
      },
    ).then((_) {
      // After closing settings, reinitialize controllers if mode changed
      _initControllers();
    });
  }

  /// Get background color from the ReaderBackground enum
  Color _getBackgroundColor(ReaderBackground bg) {
    switch (bg) {
      case ReaderBackground.white:
        return Colors.white;
      case ReaderBackground.black:
        return Colors.black;
      case ReaderBackground.gray:
        return const Color(0xFF404040);
      case ReaderBackground.sepia:
        return const Color(0xFFF5E6C8);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the state so we rebuild on every change
    final state = ref.watch(readerStateProvider);
    final bgColor = _getBackgroundColor(state.background);
    final currentChapter =
        widget.params.chapters[state.currentChapterIndex];

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Main reader content
          if (state.isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          else if (state.error != null)
            _buildErrorView(state.error!)
          else
            _buildReaderContent(state),

          // Tap zones (for paged mode)
          if (!state.isLoading && state.error == null)
            _buildTapZones(),

          // Top controls
          _buildTopBar(state, currentChapter),

          // Bottom controls
          _buildBottomBar(state),

          // Page number overlay (center bottom)
          if (state.showPageNumber &&
              !state.showControls &&
              !state.isLoading &&
              state.error == null)
            _buildPageIndicator(state),
        ],
      ),
    );
  }

  /// Build the main reader content based on current mode
  Widget _buildReaderContent(ReaderState state) {
    switch (state.readerMode) {
      case ReaderMode.paged:
        return _buildPagedReader(state);
      case ReaderMode.continuous:
        return _buildContinuousReader(state);
      case ReaderMode.webtoon:
        return _buildWebtoonReader(state);
    }
  }

  /// Paged reader using PageView
  Widget _buildPagedReader(ReaderState state) {
    if (_pageController == null) return const SizedBox.shrink();

    final isVertical =
        state.readingDirection == ReadingDirection.vertical;
    final isRTL = state.readingDirection == ReadingDirection.rightToLeft;

    return PageView.builder(
      controller: _pageController,
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      reverse: isRTL,
      itemCount: _pages.length,
      onPageChanged: (page) {
        _notifier.goToPage(page);
      },
      itemBuilder: (context, index) {
        return _buildPage(_pages[index], state);
      },
    );
  }

  /// Continuous scroll reader
  Widget _buildContinuousReader(ReaderState state) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: state.pageGap.toDouble()),
          child: _buildPage(_pages[index], state),
        );
      },
    );
  }

  /// Webtoon mode — continuous vertical with no page gaps, full-width images
  Widget _buildWebtoonReader(ReaderState state) {
    return ListView.builder(
      controller: _scrollController,
      physics: const ClampingScrollPhysics(),
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return _buildWebtoonPage(_pages[index], state);
      },
    );
  }

  /// Build a single manga page with zoom support
  Widget _buildPage(SourcePage page, ReaderState state) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: state.zoom.clamp(1.0, 5.0),
      child: Center(
        child: CachedNetworkImage(
          imageUrl: page.imageUrl,
          httpHeaders: page.headers,
          fit: BoxFit.contain,
          placeholder: (context, url) => const SizedBox(
            height: 400,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: AppColors.error),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      color: _isLightBg(state.background)
                          ? Colors.black54
                          : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build a webtoon-optimized page (full width, no extra padding)
  Widget _buildWebtoonPage(SourcePage page, ReaderState state) {
    return CachedNetworkImage(
      imageUrl: page.imageUrl,
      httpHeaders: page.headers,
      fit: BoxFit.fitWidth,
      width: MediaQuery.of(context).size.width,
      placeholder: (context, url) => const SizedBox(
        height: 600,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 48, color: AppColors.error),
              const SizedBox(height: 8),
              Text(
                'Failed to load image',
                style: TextStyle(
                  color: _isLightBg(state.background)
                      ? Colors.black54
                      : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Invisible tap zones for paged navigation
  Widget _buildTapZones() {
    return Row(
      children: [
        // Left zone — previous page (or next in RTL)
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onLeftTap,
            child: const SizedBox.expand(),
          ),
        ),
        // Center zone — toggle controls
        Expanded(
          flex: 2,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onCenterTap,
            child: const SizedBox.expand(),
          ),
        ),
        // Right zone — next page (or previous in RTL)
        Expanded(
          flex: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onRightTap,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  /// Top app bar with chapter info and controls
  Widget _buildTopBar(ReaderState state, SourceChapter chapter) {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _controlsAnimation.value,
            child: IgnorePointer(
              ignoring: !state.showControls,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        // Back button
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        // Chapter title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chapter.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (state.totalPages > 0)
                                Text(
                                  '${state.currentPage + 1} / ${state.totalPages}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Settings button
                        IconButton(
                          icon: const Icon(Icons.settings,
                              color: Colors.white),
                          onPressed: _showSettingsSheet,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Bottom bar with page slider and chapter navigation
  Widget _buildBottomBar(ReaderState state) {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _controlsAnimation.value,
            child: IgnorePointer(
              ignoring: !state.showControls,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page slider
                      if (state.totalPages > 1 &&
                          state.readerMode == ReaderMode.paged)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                '${state.currentPage + 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppColors.primary,
                                    inactiveTrackColor:
                                        Colors.white.withValues(alpha: 0.3),
                                    thumbColor: AppColors.primary,
                                    trackHeight: 3,
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                  ),
                                  child: Slider(
                                    value: state.currentPage.toDouble(),
                                    min: 0,
                                    max: (state.totalPages - 1)
                                        .toDouble()
                                        .clamp(0, double.infinity),
                                    onChanged: (v) {
                                      final page = v.round();
                                      _pageController?.jumpToPage(page);
                                      _notifier.goToPage(page);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                '${state.totalPages}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                      // Chapter navigation buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            // Previous chapter
                            TextButton.icon(
                              onPressed: _notifier.canGoPrevChapter()
                                  ? () => _switchChapter(
                                      state.currentChapterIndex + 1)
                                  : null,
                              icon: const Icon(Icons.skip_previous,
                                  size: 20),
                              label: const Text('Prev'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.3),
                              ),
                            ),

                            // Chapter indicator
                            Text(
                              'Ch. ${widget.params.chapters[state.currentChapterIndex].number?.toStringAsFixed(0) ?? '?'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            // Next chapter
                            TextButton.icon(
                              onPressed: _notifier.canGoNextChapter()
                                  ? () => _switchChapter(
                                      state.currentChapterIndex - 1)
                                  : null,
                              icon: const Icon(Icons.skip_next,
                                  size: 20),
                              label: const Text('Next'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                disabledForegroundColor:
                                    Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Small page indicator overlay when controls are hidden
  Widget _buildPageIndicator(ReaderState state) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 8,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${state.currentPage + 1} / ${state.totalPages}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Error view with retry button
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
              onPressed: _loadChapter,
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

  bool _isLightBg(ReaderBackground bg) {
    return bg == ReaderBackground.white || bg == ReaderBackground.sepia;
  }
}
