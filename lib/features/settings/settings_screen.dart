import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/providers.dart';
import '../../core/router/app_router.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/music_models.dart';
import '../../features/music/music_providers.dart';
import '../../ui/widgets/glass_app_bar.dart';

/// Settings screen for app configuration
/// Now with full music/audio settings
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = 'Loading...';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: const GlassAppBar(
        title: Text('Settings'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          final s = settings ?? AppSettings();
          return ListView(
            children: [
              // ═══════════════════════════════════════════════
              // Appearance Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Appearance',
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode,
                    title: 'Theme',
                    subtitle: _getThemeLabel(themeMode),
                    onTap: () => _showThemeDialog(context, ref, themeMode),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.auto_awesome,
                    title: 'Liquid Glass',
                    subtitle: 'Frosted glass blur on nav bar & overlays',
                    value: ref.watch(liquidGlassProvider),
                    onChanged: (v) =>
                        ref.read(liquidGlassProvider.notifier).state = v,
                  ),
                  if (ref.watch(liquidGlassProvider)) ...[
                    _SliderSettingsTile(
                      icon: Icons.blur_on,
                      title: 'Liquid Glass Blur',
                      subtitle: '${ref.watch(liquidGlassIntensityProvider).toInt()}px radius',
                      value: ref.watch(liquidGlassIntensityProvider),
                      min: 5.0,
                      max: 45.0,
                      divisions: 40,
                      onChanged: (v) =>
                          ref.read(liquidGlassIntensityProvider.notifier).state = v,
                    ),
                    _SliderSettingsTile(
                      icon: Icons.opacity,
                      title: 'Liquid Glass Opacity',
                      subtitle: '${(ref.watch(liquidGlassOpacityProvider) * 100).toInt()}% tint',
                      value: ref.watch(liquidGlassOpacityProvider),
                      min: 0.15,
                      max: 0.70,
                      divisions: 55,
                      onChanged: (v) =>
                          ref.read(liquidGlassOpacityProvider.notifier).state = v,
                    ),
                  ],
                  _SettingsTile(
                    icon: Icons.notifications_active,
                    title: 'System Media & Device Capsule',
                    subtitle: 'Shows playback in notification drawer & punch-hole capsule',
                    onTap: () {},
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.animation,
                    title: 'Reduce Animations',
                    subtitle: 'Freeze mesh gradients & motion effects',
                    value: ref.watch(reduceAnimationProvider),
                    onChanged: (v) =>
                        ref.read(reduceAnimationProvider.notifier).state = v,
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.image,
                    title: 'Full Bleed Artwork',
                    subtitle: 'Edge-to-edge album art on the player',
                    value: ref.watch(fullBleedArtworkProvider),
                    onChanged: (v) =>
                        ref.read(fullBleedArtworkProvider.notifier).state = v,
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.movie_filter,
                    title: 'Animated Canvas',
                    subtitle: 'Motion artwork behind player cover art',
                    value: ref.watch(animatedCanvasProvider),
                    onChanged: (v) =>
                        ref.read(animatedCanvasProvider.notifier).state = v,
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Audio & Playback Section 
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Audio & Playback',
                children: [
                  _SettingsTile(
                    icon: Icons.wifi,
                    title: 'Audio Quality (Wi-Fi)',
                    subtitle: ref.watch(audioQualityWifiProvider).label,
                    onTap: () => _showAudioQualityDialog(
                      context,
                      ref,
                      'Audio Quality (Wi-Fi)',
                      audioQualityWifiProvider,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.signal_cellular_alt,
                    title: 'Audio Quality (Cellular)',
                    subtitle: ref.watch(audioQualityCellularProvider).label,
                    onTap: () => _showAudioQualityDialog(
                      context,
                      ref,
                      'Audio Quality (Cellular)',
                      audioQualityCellularProvider,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.download,
                    title: 'Download Quality',
                    subtitle: ref.watch(downloadQualityProvider).label,
                    onTap: () => _showDownloadQualityDialog(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.compare_arrows,
                    title: 'Crossfade',
                    subtitle: ref.watch(crossfadeSecondsProvider) == 0
                        ? 'Off'
                        : '${ref.watch(crossfadeSecondsProvider)}s',
                    onTap: () => _showCrossfadeDialog(context, ref),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.skip_next,
                    title: 'Skip Silence',
                    value: ref.watch(skipSilenceProvider),
                    onChanged: (v) =>
                        ref.read(skipSilenceProvider.notifier).state = v,
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.volume_up,
                    title: 'Loudness Normalization',
                    subtitle: 'Level every track to the same loudness',
                    value: ref.watch(loudnessNormalizationProvider),
                    onChanged: (v) =>
                        ref.read(loudnessNormalizationProvider.notifier).state = v,
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.equalizer,
                    title: 'Equalizer',
                    value: ref.watch(equalizerEnabledProvider),
                    onChanged: (v) =>
                        ref.read(equalizerEnabledProvider.notifier).state = v,
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.surround_sound,
                    title: 'Spatial Audio',
                    subtitle: 'Stereo widening & cross-feed',
                    value: ref.watch(spatialAudioProvider),
                    onChanged: (v) =>
                        ref.read(spatialAudioProvider.notifier).state = v,
                  ),
                  _SettingsTile(
                    icon: Icons.memory,
                    title: 'Output PCM Mode',
                    subtitle: ref.watch(outputPcmModeProvider).label,
                    onTap: () => _showPcmModeDialog(context, ref),
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Lyrics Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Lyrics',
                children: [
                  _SwitchSettingsTile(
                    icon: Icons.lyrics,
                    title: 'Synced Lyrics',
                    subtitle: 'Time-synced lyrics on the player',
                    value: ref.watch(syncedLyricsProvider),
                    onChanged: (v) =>
                        ref.read(syncedLyricsProvider.notifier).state = v,
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.blur_on,
                    title: 'Lyrics Blur',
                    subtitle: 'Blur unfocused lyric lines',
                    value: ref.watch(lyricsBlurProvider),
                    onChanged: (v) =>
                        ref.read(lyricsBlurProvider.notifier).state = v,
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Player Stats
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Player',
                children: [
                  _SwitchSettingsTile(
                    icon: Icons.analytics,
                    title: 'Stats for Nerds',
                    subtitle: 'Show codec, bitrate, sample rate on player',
                    value: ref.watch(showNerdStatsProvider),
                    onChanged: (v) =>
                        ref.read(showNerdStatsProvider.notifier).state = v,
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Reader Section (original)
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Reader',
                children: [
                  _SettingsTile(
                    icon: Icons.chrome_reader_mode,
                    title: 'Reading Direction',
                    subtitle: _readingDirLabel(s.readingDirection),
                    onTap: () => _showEnumDialog<ReadingDirection>(
                      context, ref,
                      title: 'Reading Direction',
                      values: ReadingDirection.values,
                      current: s.readingDirection,
                      labelOf: _readingDirLabel,
                      onSelected: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.readingDirection = v),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.view_agenda,
                    title: 'Reader Mode',
                    subtitle: _readerModeLabel(s.readerMode),
                    onTap: () => _showEnumDialog<ReaderMode>(
                      context, ref,
                      title: 'Reader Mode',
                      values: ReaderMode.values,
                      current: s.readerMode,
                      labelOf: _readerModeLabel,
                      onSelected: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.readerMode = v),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.brightness_6,
                    title: 'Background Color',
                    subtitle: _readerBgLabel(s.readerBackground),
                    onTap: () => _showEnumDialog<ReaderBackground>(
                      context, ref,
                      title: 'Reader Background',
                      values: ReaderBackground.values,
                      current: s.readerBackground,
                      labelOf: _readerBgLabel,
                      onSelected: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.readerBackground = v),
                    ),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.format_list_numbered,
                    title: 'Show Page Number',
                    value: s.showPageNumber,
                    onChanged: (v) => ref.read(settingsRepositoryProvider)
                        .updateSetting((s) => s.showPageNumber = v),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.screen_lock_portrait,
                    title: 'Keep Screen On',
                    value: s.keepScreenOn,
                    onChanged: (v) => ref.read(settingsRepositoryProvider)
                        .updateSetting((s) => s.keepScreenOn = v),
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Video Player Section (original)
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Video Player',
                children: [
                  _SettingsTile(
                    icon: Icons.speed,
                    title: 'Default Playback Speed',
                    subtitle: '${s.defaultPlaybackSpeed}x',
                    onTap: () => _showSpeedDialog(context, ref, s.defaultPlaybackSpeed),
                  ),
                  _SettingsTile(
                    icon: Icons.skip_next,
                    title: 'Skip Intro Duration',
                    subtitle: '${s.skipIntroSeconds} seconds',
                    onTap: () => _showIntDialog(
                      context, ref,
                      title: 'Skip Intro (seconds)',
                      current: s.skipIntroSeconds,
                      onSave: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.skipIntroSeconds = v),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.skip_previous,
                    title: 'Skip Outro Duration',
                    subtitle: '${s.skipOutroSeconds} seconds',
                    onTap: () => _showIntDialog(
                      context, ref,
                      title: 'Skip Outro (seconds)',
                      current: s.skipOutroSeconds,
                      onSave: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.skipOutroSeconds = v),
                    ),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.play_arrow,
                    title: 'Auto-play Next Episode',
                    value: s.autoPlayNext,
                    onChanged: (v) => ref.read(settingsRepositoryProvider)
                        .updateSetting((s) => s.autoPlayNext = v),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.memory,
                    title: 'Hardware Acceleration',
                    value: s.hardwareAcceleration,
                    onChanged: (v) => ref.read(settingsRepositoryProvider)
                        .updateSetting((s) => s.hardwareAcceleration = v),
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Library Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Library',
                children: [
                  _SettingsTile(
                    icon: Icons.grid_view,
                    title: 'Display Mode',
                    subtitle: _displayModeLabel(s.libraryDisplayMode),
                    onTap: () => _showEnumDialog<LibraryDisplayMode>(
                      context, ref,
                      title: 'Display Mode',
                      values: LibraryDisplayMode.values,
                      current: s.libraryDisplayMode,
                      labelOf: _displayModeLabel,
                      onSelected: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.libraryDisplayMode = v),
                    ),
                  ),
                  _SwitchSettingsTile(
                    icon: Icons.notifications,
                    title: 'Update Notifications',
                    value: s.notifyOnUpdate,
                    onChanged: (v) => ref.read(settingsRepositoryProvider)
                        .updateSetting((s) => s.notifyOnUpdate = v),
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Tracking Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Tracking',
                children: [
                  _SettingsTile(
                    icon: Icons.sync,
                    title: 'Manage Trackers',
                    subtitle: 'Connect to MyAnimeList, AniList, Kitsu',
                    onTap: () => context.push(AppRouter.trackerSettings),
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // API Configuration Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'API Configuration',
                children: [
                  _SettingsTile(
                    icon: Icons.audiotrack,
                    title: 'Preferred Anime Audio',
                    subtitle: s.animeAudioPreference == AnimeAudioPreference.dub
                        ? 'English Dubbed'
                        : 'Original Japanese (Subbed)',
                    onTap: () => _showEnumDialog<AnimeAudioPreference>(
                      context, ref,
                      title: 'Preferred Audio',
                      values: AnimeAudioPreference.values,
                      current: s.animeAudioPreference,
                      labelOf: (v) => v == AnimeAudioPreference.dub
                          ? 'English Dubbed'
                          : 'Original Japanese (Subbed)',
                      onSelected: (v) => ref.read(settingsRepositoryProvider)
                          .updateSetting((s) => s.animeAudioPreference = v),
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.link,
                    title: 'Consumet API URL',
                    subtitle: s.consumetApiUrl,
                    onTap: () {
                      final controller = TextEditingController(text: s.consumetApiUrl);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Consumet API URL'),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'https://consumet-api-clone.vercel.app/anime/gogoanime',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(settingsRepositoryProvider).updateSetting(
                                  (s) => s.consumetApiUrl = controller.text.trim(),
                                );
                                Navigator.pop(ctx);
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // Data Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'Data & Storage',
                children: [
                  _SettingsTile(
                    icon: Icons.backup,
                    title: 'Backup',
                    subtitle: 'Export library to file',
                    onTap: () => _exportBackup(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.restore,
                    title: 'Restore',
                    subtitle: 'Import from backup file',
                    onTap: () => _importBackup(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.cleaning_services,
                    title: 'Clear Cache',
                    subtitle: 'Free up storage space',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cache cleared')),
                      );
                    },
                  ),
                ],
              ),

              // ═══════════════════════════════════════════════
              // About Section
              // ═══════════════════════════════════════════════
              _SettingsSection(
                title: 'About',
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'App Version',
                    subtitle: _buildNumber.isNotEmpty 
                        ? 'v$_appVersion (Build $_buildNumber)'
                        : 'v$_appVersion',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary, width: 1),
                      ),
                      child: Text(
                        'v$_appVersion',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Aniwhere',
                        applicationVersion: 'v$_appVersion (Build $_buildNumber)',
                        applicationIcon: const Icon(Icons.play_circle_outline, size: 48, color: AppColors.primary),
                        applicationLegalese: '© 2026 Aniwhere\nWatch, read, and listen — anime, manga, and music, anywhere.',
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.code,
                    title: 'Source Code',
                    subtitle: 'github.com/HUNTERZEN/aniwhere',
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () async {
                      final url = Uri.parse('https://github.com/HUNTERZEN/aniwhere.git');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open GitHub')),
                          );
                        }
                      }
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.description,
                    title: 'Open Source Licenses',
                    subtitle: 'View third-party licenses',
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Aniwhere',
                      applicationVersion: 'v$_appVersion',
                      applicationIcon: const Icon(Icons.play_circle_outline, size: 48, color: AppColors.primary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  // ─────────────────── Label helpers ───────────────────

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'System';
      case ThemeMode.light:  return 'Light';
      case ThemeMode.dark:   return 'Monochrome (Black & White)';
    }
  }

  String _readingDirLabel(ReadingDirection v) {
    switch (v) {
      case ReadingDirection.leftToRight: return 'Left to Right';
      case ReadingDirection.rightToLeft: return 'Right to Left';
      case ReadingDirection.vertical:    return 'Vertical';
      case ReadingDirection.webtoon:     return 'Webtoon';
    }
  }

  String _readerModeLabel(ReaderMode v) {
    switch (v) {
      case ReaderMode.paged:      return 'Paged';
      case ReaderMode.continuous:  return 'Continuous';
      case ReaderMode.webtoon:     return 'Webtoon';
    }
  }

  String _readerBgLabel(ReaderBackground v) {
    switch (v) {
      case ReaderBackground.white: return 'White';
      case ReaderBackground.black: return 'Black';
      case ReaderBackground.gray:  return 'Gray';
      case ReaderBackground.sepia: return 'Sepia';
    }
  }

  String _displayModeLabel(LibraryDisplayMode v) {
    switch (v) {
      case LibraryDisplayMode.grid:        return 'Grid';
      case LibraryDisplayMode.list:        return 'List';
      case LibraryDisplayMode.compactGrid: return 'Compact Grid';
    }
  }

  // ─────────────────── Theme dialog ───────────────────

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeLabel(mode)),
              value: mode,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeNotifierProvider.notifier).setTheme(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────── Audio Quality dialog ───────────────────

  void _showAudioQualityDialog(
    BuildContext context,
    WidgetRef ref,
    String title,
    StateNotifierProvider<PersistentEnumNotifier<AudioQuality>, AudioQuality> provider,
  ) {
    final current = ref.read(provider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AudioQuality.values.map((q) {
            return RadioListTile<AudioQuality>(
              title: Text(q.label),
              subtitle: Text(q.detail, style: const TextStyle(fontSize: 12)),
              value: q,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v != null) {
                  ref.read(provider.notifier).state = v;
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────── Download Quality dialog ───────────────────

  void _showDownloadQualityDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(downloadQualityProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DownloadQuality.values.map((q) {
            return RadioListTile<DownloadQuality>(
              title: Text(q.label),
              subtitle: Text('${q.detail} · ${q.perTrack}',
                  style: const TextStyle(fontSize: 12)),
              value: q,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v != null) {
                  ref.read(downloadQualityProvider.notifier).state = v;
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────── Crossfade dialog ───────────────────

  void _showCrossfadeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(crossfadeSecondsProvider);
    showDialog(
      context: context,
      builder: (ctx) {
        int value = current;
        return StatefulBuilder(
          builder: (ctx, setLocalState) => AlertDialog(
            title: const Text('Crossfade'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value == 0 ? 'Off' : '${value}s',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: 12,
                  divisions: 12,
                  activeColor: AppColors.primary,
                  label: value == 0 ? 'Off' : '${value}s',
                  onChanged: (v) {
                    setLocalState(() => value = v.round());
                  },
                ),
                Text(
                  'Adjustable 0–12 seconds crossfade\nbetween tracks',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(crossfadeSecondsProvider.notifier).state = value;
                  Navigator.pop(ctx);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────── PCM Mode dialog ───────────────────

  void _showPcmModeDialog(BuildContext context, WidgetRef ref) {
    final current = ref.read(outputPcmModeProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Output PCM Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OutputPcmMode.values.map((m) {
            return RadioListTile<OutputPcmMode>(
              title: Text(m.label),
              value: m,
              groupValue: current,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v != null) {
                  ref.read(outputPcmModeProvider.notifier).state = v;
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────── Generic enum dialog ───────────────────

  void _showEnumDialog<T extends Enum>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<T> values,
    required T current,
    required String Function(T) labelOf,
    required void Function(T) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: values.map((v) {
            return RadioListTile<T>(
              title: Text(labelOf(v)),
              value: v,
              groupValue: current,
              onChanged: (selected) {
                if (selected != null) {
                  onSelected(selected);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────── Speed dialog ───────────────────

  void _showSpeedDialog(BuildContext context, WidgetRef ref, double current) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Playback Speed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((spd) {
            return RadioListTile<double>(
              title: Text('${spd}x'),
              value: spd,
              groupValue: current,
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsRepositoryProvider)
                      .updateSetting((s) => s.defaultPlaybackSpeed = v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────── Integer input dialog ───────────────────

  void _showIntDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int current,
    required void Function(int) onSave,
  }) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'seconds'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                onSave(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─────────────────── Backup / Restore ───────────────────

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating backup...')),
      );
      final path = await ref.read(backupRepositoryProvider).exportLibrary();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup saved to: $path'),
            action: SnackBarAction(
              label: 'SHARE',
              onPressed: () {
                SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Aniwhere Backup'));
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restoring backup...')),
      );

      final count =
          await ref.read(backupRepositoryProvider).importLibrary(filePath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $count library entries')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

/// Settings section with title wrapped in glass-bordered card
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Standard settings tile
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Switch settings tile with optional subtitle
class _SwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
      onTap: () => onChanged(!value),
    );
  }
}

/// Slider settings tile for continuous adjustments like blur and opacity
class _SliderSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

