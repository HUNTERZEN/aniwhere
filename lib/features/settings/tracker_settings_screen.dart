import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../tracker/tracker_providers.dart';
import '../tracker/tracker_service.dart';

class TrackerSettingsScreen extends ConsumerWidget {
  const TrackerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the global tracker state to rebuild when auth changes
    ref.watch(trackerStateProvider);
    final trackers = ref.watch(trackersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackers'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: trackers.length,
        itemBuilder: (context, index) {
          final tracker = trackers[index];
          return _TrackerListTile(tracker: tracker);
        },
      ),
    );
  }
}

class _TrackerListTile extends ConsumerStatefulWidget {
  final TrackerService tracker;

  const _TrackerListTile({required this.tracker});

  @override
  ConsumerState<_TrackerListTile> createState() => _TrackerListTileState();
}

class _TrackerListTileState extends ConsumerState<_TrackerListTile> {
  bool _isLoading = false;

  Future<void> _toggleAuth() async {
    setState(() => _isLoading = true);
    
    try {
      if (widget.tracker.isLoggedIn) {
        await widget.tracker.logout();
      } else {
        final success = await widget.tracker.authenticate();
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed or was cancelled. Note: Some trackers require setting up your own API keys in the source code.')),
          );
        }
      }
      
      if (mounted) {
        ref.read(trackerStateProvider.notifier).refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = widget.tracker.isLoggedIn;
    
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        // Since we don't have the actual assets, safely fallback to an icon
        child: const Icon(Icons.sync_alt), 
      ),
      title: Text(widget.tracker.name),
      subtitle: isLoggedIn 
          ? Text('Logged in as ${widget.tracker.username ?? 'Unknown'}')
          : const Text('Not logged in'),
      trailing: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: _toggleAuth,
              child: Text(
                isLoggedIn ? 'LOGOUT' : 'LOGIN',
                style: TextStyle(
                  color: isLoggedIn ? AppColors.error : AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}
