import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import 'extension_model.dart';

/// Repository for managing extension storage and retrieval
class ExtensionRepository {
  final Dio _dio = Dio();
  Directory? _extensionsDir;

  /// Get the extensions directory
  Future<Directory> get extensionsDir async {
    if (_extensionsDir != null) return _extensionsDir!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _extensionsDir = Directory('${appDir.path}/extensions');
    
    if (!await _extensionsDir!.exists()) {
      await _extensionsDir!.create(recursive: true);
    }
    
    return _extensionsDir!;
  }

  /// Get list of installed extensions
  Future<List<LoadedExtension>> getInstalledExtensions() async {
    final dir = await extensionsDir;
    final extensions = <LoadedExtension>[];
    
    try {
      final entities = await dir.list().toList();
      
      for (final entity in entities) {
        if (entity is Directory) {
          final ext = await _loadExtensionFromDir(entity);
          if (ext != null) {
            extensions.add(ext);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading extensions: $e');
    }
    
    return extensions;
  }

  /// Load extension from directory
  Future<LoadedExtension?> _loadExtensionFromDir(Directory dir) async {
    try {
      final manifestFile = File('${dir.path}/manifest.json');
      final codeFile = File('${dir.path}/source.js');
      
      if (!await manifestFile.exists() || !await codeFile.exists()) {
        return null;
      }
      
      final manifestJson = jsonDecode(await manifestFile.readAsString());
      final jsCode = await codeFile.readAsString();
      
      final metadata = ExtensionMetadata.fromJson(manifestJson);
      
      return LoadedExtension(
        metadata: metadata,
        jsCode: jsCode,
        isEnabled: true,
      );
    } catch (e) {
      debugPrint('Error loading extension from ${dir.path}: $e');
      return null;
    }
  }

  /// Install extension from URL
  Future<LoadedExtension?> installFromUrl(String url) async {
    try {
      // Download extension package (ZIP or JS file)
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.data == null) {
        throw Exception('Failed to download extension');
      }
      
      final bytes = response.data!;
      final content = utf8.decode(bytes);
      
      // Parse JS to extract metadata from comments
      final metadata = _parseMetadataFromJs(content, url);
      
      // Save extension
      return await _saveExtension(metadata, content);
    } catch (e) {
      debugPrint('Error installing extension from URL: $e');
      return null;
    }
  }

  /// Install extension from local file
  Future<LoadedExtension?> installFromFile(File file) async {
    try {
      final content = await file.readAsString();
      final metadata = _parseMetadataFromJs(content, file.path);
      return await _saveExtension(metadata, content);
    } catch (e) {
      debugPrint('Error installing extension from file: $e');
      return null;
    }
  }

  /// Install extension from raw JS code
  Future<LoadedExtension?> installFromCode(String jsCode, {String? sourceUrl}) async {
    try {
      final metadata = _parseMetadataFromJs(jsCode, sourceUrl);
      return await _saveExtension(metadata, jsCode);
    } catch (e) {
      debugPrint('Error installing extension from code: $e');
      return null;
    }
  }

  /// Parse metadata from JS comments
  /// Expects format:
  /// // @id mangakakalot
  /// // @name MangaKakalot
  /// // @version 1.0.0
  /// // @author YourName
  /// // @description Manga source for MangaKakalot
  /// // @language en
  /// // @contentType manga
  /// // @baseUrl https://mangakakalot.com
  /// // @supportsLatest true
  ExtensionMetadata _parseMetadataFromJs(String jsCode, String? sourceUrl) {
    final lines = jsCode.split('\n');
    final metadata = <String, String>{};
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('// @')) {
        final match = RegExp(r'// @(\w+)\s+(.+)').firstMatch(trimmed);
        if (match != null) {
          metadata[match.group(1)!] = match.group(2)!.trim();
        }
      } else if (!trimmed.startsWith('//') && trimmed.isNotEmpty) {
        // Stop parsing after we hit actual code
        break;
      }
    }
    
    final id = metadata['id'] ?? 'ext_${DateTime.now().millisecondsSinceEpoch}';
    
    return ExtensionMetadata(
      id: id,
      name: metadata['name'] ?? 'Unknown Extension',
      version: metadata['version'] ?? '1.0.0',
      author: metadata['author'] ?? 'Unknown',
      description: metadata['description'] ?? '',
      language: metadata['language'] ?? 'en',
      contentType: metadata['contentType'] ?? 'manga',
      iconUrl: metadata['iconUrl'],
      baseUrl: metadata['baseUrl'],
      supportsLatest: metadata['supportsLatest']?.toLowerCase() == 'true',
      installedAt: DateTime.now(),
      sourceUrl: sourceUrl,
    );
  }

  /// Save extension to disk
  Future<LoadedExtension> _saveExtension(ExtensionMetadata metadata, String jsCode) async {
    final dir = await extensionsDir;
    final extDir = Directory('${dir.path}/${metadata.id}');
    
    if (!await extDir.exists()) {
      await extDir.create(recursive: true);
    }
    
    // Save manifest
    final manifestFile = File('${extDir.path}/manifest.json');
    await manifestFile.writeAsString(jsonEncode(metadata.toJson()));
    
    // Save code
    final codeFile = File('${extDir.path}/source.js');
    await codeFile.writeAsString(jsCode);
    
    return LoadedExtension(
      metadata: metadata,
      jsCode: jsCode,
      isEnabled: true,
    );
  }

  /// Uninstall extension
  Future<bool> uninstall(String extensionId) async {
    try {
      final dir = await extensionsDir;
      final extDir = Directory('${dir.path}/$extensionId');
      
      if (await extDir.exists()) {
        await extDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error uninstalling extension: $e');
      return false;
    }
  }

  /// Update extension
  Future<LoadedExtension?> update(String extensionId, String newJsCode) async {
    try {
      final dir = await extensionsDir;
      final extDir = Directory('${dir.path}/$extensionId');
      
      if (!await extDir.exists()) {
        return null;
      }
      
      final manifestFile = File('${extDir.path}/manifest.json');
      final oldMetadata = ExtensionMetadata.fromJson(
        jsonDecode(await manifestFile.readAsString()),
      );
      
      final newMetadata = _parseMetadataFromJs(newJsCode, oldMetadata.sourceUrl);
      final updatedMetadata = newMetadata.copyWith(
        installedAt: oldMetadata.installedAt,
        updatedAt: DateTime.now(),
      );
      
      // Save updated files
      await manifestFile.writeAsString(jsonEncode(updatedMetadata.toJson()));
      
      final codeFile = File('${extDir.path}/source.js');
      await codeFile.writeAsString(newJsCode);
      
      return LoadedExtension(
        metadata: updatedMetadata,
        jsCode: newJsCode,
        isEnabled: true,
      );
    } catch (e) {
      debugPrint('Error updating extension: $e');
      return null;
    }
  }

  /// Toggle extension enabled state
  Future<bool> toggleEnabled(String extensionId, bool enabled) async {
    try {
      final dir = await extensionsDir;
      final manifestFile = File('${dir.path}/$extensionId/manifest.json');
      
      if (!await manifestFile.exists()) {
        return false;
      }
      
      final json = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      json['enabled'] = enabled;
      await manifestFile.writeAsString(jsonEncode(json));
      
      return true;
    } catch (e) {
      debugPrint('Error toggling extension: $e');
      return false;
    }
  }

  /// Alias for toggleEnabled
  Future<bool> setEnabled(String extensionId, bool enabled) => toggleEnabled(extensionId, enabled);

  /// Check for update and apply if available
  Future<bool> checkForUpdate(String extensionId) async {
    try {
      final dir = await extensionsDir;
      final manifestFile = File('${dir.path}/$extensionId/manifest.json');
      
      if (!await manifestFile.exists()) {
        return false;
      }
      
      final json = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final sourceUrl = json['sourceUrl'] as String?;
      
      if (sourceUrl == null || sourceUrl.isEmpty) {
        return false;
      }
      
      // Download latest version
      final response = await _dio.get<List<int>>(
        sourceUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.data == null) {
        return false;
      }
      
      final bytes = response.data!;
      final content = utf8.decode(bytes);
      
      // Parse new metadata
      final newMetadata = _parseMetadataFromJs(content, sourceUrl);
      final currentVersion = json['version'] as String?;
      
      // Check if version is newer
      if (currentVersion != null && newMetadata.version == currentVersion) {
        return false;
      }
      
      // Apply update
      await update(extensionId, content);
      return true;
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return false;
    }
  }
}

/// Provider for extension repository
final extensionRepositoryProvider = Provider<ExtensionRepository>((ref) {
  return ExtensionRepository();
});

/// Provider for installed extensions
final installedExtensionsProvider = FutureProvider<List<LoadedExtension>>((ref) async {
  final repo = ref.watch(extensionRepositoryProvider);
  return repo.getInstalledExtensions();
});
