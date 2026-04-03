import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/tracker_status.dart';
import '../tracker/tracker_providers.dart';
import '../tracker/tracker_service.dart';

class TrackerStatusSheet extends ConsumerStatefulWidget {
  final String title;

  const TrackerStatusSheet({
    super.key,
    required this.title, // Pass title to search tracker automatically if needed
  });

  @override
  ConsumerState<TrackerStatusSheet> createState() => _TrackerStatusSheetState();
}

class _TrackerStatusSheetState extends ConsumerState<TrackerStatusSheet> {
  // A map of tracker ID to their fetched status for this media
  final Map<String, TrackerStatus> _statuses = {};
  final Map<String, bool> _loading = {};
  
  // We'll simulate finding the mediaId via searching the title for each tracker
  // In a real app, this mapping would be saved locally.

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
  }

  Future<void> _fetchStatuses() async {
    final trackers = ref.read(trackersProvider).where((t) => t.isLoggedIn).toList();
    
    for (final tracker in trackers) {
      if (!mounted) return;
      setState(() => _loading[tracker.id] = true);
      
      try {
        // Step 1: Search by title to find the remote ID
        // (If we had local mappings mapped, we'd use those instead)
        final searchResult = await tracker.search(widget.title);
        
        if (searchResult.isNotEmpty) {
          final mediaId = searchResult.keys.first;
          // Step 2: Fetch status
          final status = await tracker.getStatus(mediaId);
          if (status != null) {
            _statuses[tracker.id] = status;
          } else {
            // Unset status but we have the ID to set it later
            _statuses[tracker.id] = TrackerStatus(
              trackerId: tracker.id,
              mediaId: mediaId,
              status: TrackerStatusValue.unknown,
              progress: 0,
            );
          }
        }
      } finally {
        if (mounted) {
          setState(() => _loading[tracker.id] = false);
        }
      }
    }
  }

  Future<void> _updateStatus(TrackerService tracker, TrackerStatus status) async {
    setState(() => _loading[tracker.id] = true);
    try {
      await tracker.updateStatus(status);
      setState(() => _statuses[tracker.id] = status);
    } finally {
      if (mounted) {
        setState(() => _loading[tracker.id] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackers = ref.watch(trackersProvider).where((t) => t.isLoggedIn).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tracker Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          if (trackers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No trackers linked. Log in via Settings.'),
              ),
            )
          else
            ...trackers.map((t) => _buildTrackerRow(t)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrackerRow(TrackerService tracker) {
    final isLoading = _loading[tracker.id] ?? false;
    final status = _statuses[tracker.id];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, size: 24, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  tracker.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (status != null && !isLoading) ...[
              const SizedBox(height: 12),
              _buildInteractionForm(tracker, status),
            ] else if (status == null && !isLoading) ...[
              const SizedBox(height: 12),
              const Text(
                'Media not found on this tracker',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionForm(TrackerService tracker, TrackerStatus status) {
    return Column(
      children: [
        DropdownButtonFormField<TrackerStatusValue>(
          value: status.status == TrackerStatusValue.unknown ? null : status.status,
          hint: const Text('Status'),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: TrackerStatusValue.values
              .where((e) => e != TrackerStatusValue.unknown)
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.displayName),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              _updateStatus(tracker, status.copyWith(status: val));
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Progress',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: status.progress.toString()),
                onSubmitted: (val) {
                  final progress = int.tryParse(val) ?? status.progress;
                  _updateStatus(tracker, status.copyWith(progress: progress));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: status.score,
                hint: const Text('Score'),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: List.generate(11, (i) => i).map((e) => DropdownMenuItem(
                  value: e == 0 ? null : e,
                  child: Text(e == 0 ? 'No Score' : '$e / 10'),
                )).toList(),
                onChanged: (val) {
                  _updateStatus(tracker, status.copyWith(score: val));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
