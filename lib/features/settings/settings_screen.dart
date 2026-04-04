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

/// Settings screen for app configuration
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
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          final s = settings ?? AppSettings();
          return ListView(
            children: [
              // Appearance Section
              _SettingsSection(
                title: 'Appearance',
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode,
                    title: 'Theme',
                    subtitle: _getThemeLabel(themeMode),
                    onTap: () => _showThemeDialog(context, ref, themeMode),
                  ),
                ],
              ),

              // Reader Section
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

              // Player Section
              _SettingsSection(
                title: 'Player',
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

              // Library Section
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

              // Tracking Section
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

              // API Configuration Section
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

              // Data Section
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

              // About Section
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
                        applicationLegalese: '© 2026 Aniwhere\nWatch and read anime, manga, anywhere.',
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
      case ThemeMode.dark:   return 'Dark';
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

/// Settings section with title
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
        ...children,
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
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Switch settings tile
class _SwitchSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary,
      ),
      onTap: () => onChanged(!value),
    );
  }
}
