import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/extensions/extension_model.dart';
import '../../data/extensions/extension_repository.dart';
import '../../data/sources/source_registry.dart';

class ExtensionManagerScreen extends ConsumerStatefulWidget {
  const ExtensionManagerScreen({super.key});

  @override
  ConsumerState<ExtensionManagerScreen> createState() => _ExtensionManagerScreenState();
}

class _ExtensionManagerScreenState extends ConsumerState<ExtensionManagerScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _installFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter a URL');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(extensionRepositoryProvider);
      await repo.installFromUrl(url);
      
      // Refresh extensions list
      ref.invalidate(installedExtensionsProvider);
      
      // Register in source registry
      final registry = ref.read(sourceRegistryProvider);
      await registry.loadExtensions();
      
      _urlController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extension installed successfully!')),
        );
      }
    } catch (e) {
      _showError('Failed to install extension: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _installFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['js'],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);

      final file = File(result.files.single.path!);
      final repo = ref.read(extensionRepositoryProvider);
      await repo.installFromFile(file);
      
      // Refresh extensions list
      ref.invalidate(installedExtensionsProvider);
      
      // Register in source registry
      final registry = ref.read(sourceRegistryProvider);
      await registry.loadExtensions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extension installed successfully!')),
        );
      }
    } catch (e) {
      _showError('Failed to install extension: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uninstallExtension(LoadedExtension ext) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uninstall Extension'),
        content: Text('Are you sure you want to uninstall "${ext.metadata.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(extensionRepositoryProvider);
      await repo.uninstall(ext.metadata.id);
      
      // Unregister from source registry
      final registry = ref.read(sourceRegistryProvider);
      registry.unregister(ext.metadata.id);
      
      // Refresh extensions list
      ref.invalidate(installedExtensionsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ext.metadata.name} uninstalled')),
        );
      }
    } catch (e) {
      _showError('Failed to uninstall: $e');
    }
  }

  Future<void> _toggleExtension(LoadedExtension ext) async {
    try {
      final repo = ref.read(extensionRepositoryProvider);
      await repo.setEnabled(ext.metadata.id, !ext.isEnabled);
      
      final registry = ref.read(sourceRegistryProvider);
      if (ext.isEnabled) {
        // Was enabled, now disabling
        registry.unregister(ext.metadata.id);
      } else {
        // Was disabled, now enabling
        await registry.registerExtension(ext.copyWith(isEnabled: true));
      }
      
      // Refresh extensions list
      ref.invalidate(installedExtensionsProvider);
    } catch (e) {
      _showError('Failed to toggle extension: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAddExtensionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Extension',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Extension URL',
                hintText: 'https://example.com/extension.js',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _installFromUrl();
                    },
              icon: const Icon(Icons.download),
              label: const Text('Install from URL'),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _installFromFile();
                    },
              icon: const Icon(Icons.folder_open),
              label: const Text('Install from File'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extensionsAsync = ref.watch(installedExtensionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _showAddExtensionDialog,
        icon: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Add Extension'),
      ),
      body: extensionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error loading extensions: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(installedExtensionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (extensions) {
          if (extensions.isEmpty) {
            return _buildEmptyState();
          }
          return _buildExtensionsList(extensions);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off,
              size: 96,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Extensions Installed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Extensions add support for additional manga and anime sources.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddExtensionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Extension'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtensionsList(List<LoadedExtension> extensions) {
    // Group by content type
    final mangaExts = extensions.where((e) => e.metadata.contentType == 'manga').toList();
    final animeExts = extensions.where((e) => e.metadata.contentType == 'anime').toList();
    final novelExts = extensions.where((e) => e.metadata.contentType == 'novel').toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (mangaExts.isNotEmpty) ...[
          _buildSectionHeader('Manga Sources', Icons.menu_book),
          ...mangaExts.map(_buildExtensionTile),
        ],
        if (animeExts.isNotEmpty) ...[
          _buildSectionHeader('Anime Sources', Icons.movie),
          ...animeExts.map(_buildExtensionTile),
        ],
        if (novelExts.isNotEmpty) ...[
          _buildSectionHeader('Novel Sources', Icons.book),
          ...novelExts.map(_buildExtensionTile),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionTile(LoadedExtension ext) {
    final metadata = ext.metadata;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: metadata.iconUrl != null
              ? ClipOval(
                  child: Image.network(
                    metadata.iconUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _getContentTypeIcon(metadata.contentType),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : Icon(
                  _getContentTypeIcon(metadata.contentType),
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                metadata.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'v${metadata.version}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metadata.description.isNotEmpty)
              Text(
                metadata.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.language,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  metadata.language.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(width: 12),
                if (metadata.author.isNotEmpty) ...[
                  Icon(
                    Icons.person,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metadata.author,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: ext.isEnabled,
              onChanged: (_) => _toggleExtension(ext),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'uninstall':
                    _uninstallExtension(ext);
                    break;
                  case 'update':
                    _checkForUpdate(ext);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'update',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Check for Update'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'uninstall',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Uninstall', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getContentTypeIcon(String contentType) {
    switch (contentType) {
      case 'anime':
        return Icons.movie;
      case 'novel':
        return Icons.book;
      default:
        return Icons.menu_book;
    }
  }

  Future<void> _checkForUpdate(LoadedExtension ext) async {
    if (ext.metadata.sourceUrl == null) {
      _showError('No source URL configured for this extension');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(extensionRepositoryProvider);
      final updated = await repo.checkForUpdate(ext.metadata.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated
                  ? 'Extension updated successfully!'
                  : 'Already on the latest version',
            ),
          ),
        );
      }
      
      if (updated) {
        ref.invalidate(installedExtensionsProvider);
      }
    } catch (e) {
      _showError('Failed to check for updates: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Extensions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Extensions allow you to add custom manga, anime, and novel sources to Aniwhere.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                'How to Install:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Tap the "Add Extension" button'),
              Text('2. Enter a URL to a .js extension file, or'),
              Text('3. Select a .js file from your device'),
              SizedBox(height: 16),
              Text(
                'Extension Format:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Extensions are JavaScript files that implement the source interface. They must include metadata comments and required functions.',
                style: TextStyle(height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                '⚠️ Warning:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              SizedBox(height: 8),
              Text(
                'Only install extensions from sources you trust. Malicious extensions could potentially access your data.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
