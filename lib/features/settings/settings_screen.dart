import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/providers.dart';
import '../../data/models/app_settings.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
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
                subtitle: 'Left to Right',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.view_agenda,
                title: 'Reader Mode',
                subtitle: 'Paged',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.brightness_6,
                title: 'Background Color',
                subtitle: 'Black',
                onTap: () {},
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
                subtitle: '1.0x',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.skip_next,
                title: 'Skip Intro Duration',
                subtitle: '85 seconds',
                onTap: () {},
              ),
              _SwitchSettingsTile(
                icon: Icons.play_arrow,
                title: 'Auto-play Next Episode',
                value: true,
                onChanged: (value) {},
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
                subtitle: 'Grid',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.sort,
                title: 'Default Sort',
                subtitle: 'Alphabetical',
                onTap: () {},
              ),
              _SwitchSettingsTile(
                icon: Icons.notifications,
                title: 'Update Notifications',
                value: true,
                onChanged: (value) {},
              ),
            ],
          ),

          // Tracking Section
          _SettingsSection(
            title: 'Tracking',
            children: [
              _SettingsTile(
                icon: Icons.link,
                title: 'MyAnimeList',
                subtitle: 'Not connected',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.link,
                title: 'AniList',
                subtitle: 'Not connected',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.link,
                title: 'Kitsu',
                subtitle: 'Not connected',
                onTap: () {},
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
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.restore,
                title: 'Restore',
                subtitle: 'Import from backup file',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.cleaning_services,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: () {},
              ),
            ],
          ),

          // About Section
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.info,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.code,
                title: 'Source Code',
                subtitle: 'View on GitHub',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.description,
                title: 'Licenses',
                subtitle: 'Open source licenses',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

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

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
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
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      onTap: () => onChanged(!value),
    );
  }
}
