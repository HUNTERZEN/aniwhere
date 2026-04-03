import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/app_settings.dart';
import 'reader_providers.dart';

/// Bottom sheet for configuring reader settings in real-time
class ReaderSettingsSheet extends StatelessWidget {
  final ReaderStateNotifier notifier;
  final ReaderState state;

  const ReaderSettingsSheet({
    super.key,
    required this.notifier,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              'Reader Settings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Reading Mode
            _SectionTitle(title: 'Reading Mode'),
            const SizedBox(height: 8),
            _SegmentedSelector<ReaderMode>(
              value: state.readerMode,
              options: const [
                (ReaderMode.paged, 'Paged', Icons.auto_stories),
                (ReaderMode.continuous, 'Scroll', Icons.swap_vert),
                (ReaderMode.webtoon, 'Webtoon', Icons.view_day),
              ],
              onChanged: notifier.setReaderMode,
            ),
            const SizedBox(height: 20),

            // Reading Direction
            _SectionTitle(title: 'Reading Direction'),
            const SizedBox(height: 8),
            _SegmentedSelector<ReadingDirection>(
              value: state.readingDirection,
              options: const [
                (ReadingDirection.leftToRight, 'LTR', Icons.arrow_forward),
                (ReadingDirection.rightToLeft, 'RTL', Icons.arrow_back),
                (ReadingDirection.vertical, 'Vertical', Icons.arrow_downward),
              ],
              onChanged: notifier.setReadingDirection,
            ),
            const SizedBox(height: 20),

            // Background Color
            _SectionTitle(title: 'Background'),
            const SizedBox(height: 8),
            _BackgroundSelector(
              value: state.background,
              onChanged: notifier.setBackground,
            ),
            const SizedBox(height: 20),

            // Page Gap
            _SectionTitle(title: 'Page Gap: ${state.pageGap}px'),
            Slider(
              value: state.pageGap.toDouble(),
              min: 0,
              max: 32,
              divisions: 8,
              label: '${state.pageGap}px',
              onChanged: (v) => notifier.setPageGap(v.round()),
            ),

            // Zoom Level
            _SectionTitle(title: 'Zoom: ${(state.zoom * 100).round()}%'),
            Slider(
              value: state.zoom,
              min: 0.5,
              max: 3.0,
              divisions: 10,
              label: '${(state.zoom * 100).round()}%',
              onChanged: notifier.setZoom,
            ),

            // Toggles
            SwitchListTile(
              title: const Text('Show Page Number'),
              value: state.showPageNumber,
              onChanged: (_) => notifier.togglePageNumber(),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Section title widget
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

/// A segmented control for selecting from a list of options
class _SegmentedSelector<T> extends StatelessWidget {
  final T value;
  final List<(T, String, IconData)> options;
  final ValueChanged<T> onChanged;

  const _SegmentedSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final (optValue, label, icon) = option;
        final isSelected = value == optValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Material(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(optValue),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryDark,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Background color selector with preview circles
class _BackgroundSelector extends StatelessWidget {
  final ReaderBackground value;
  final ValueChanged<ReaderBackground> onChanged;

  const _BackgroundSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ReaderBackground.values.map((bg) {
        final isSelected = value == bg;
        return GestureDetector(
          onTap: () => onChanged(bg),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _bgColor(bg),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bg.name[0].toUpperCase() + bg.name.substring(1),
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _bgColor(ReaderBackground bg) {
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
}
