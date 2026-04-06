import 'dart:convert';

/// Metadata for a custom extension
class ExtensionMetadata {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String language;
  final String contentType; // 'manga', 'anime', 'novel'
  final String? iconUrl;
  final String? baseUrl;
  final bool supportsLatest;
  final DateTime installedAt;
  final DateTime? updatedAt;
  final String? sourceUrl; // URL where extension was downloaded from

  const ExtensionMetadata({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.language,
    required this.contentType,
    this.iconUrl,
    this.baseUrl,
    this.supportsLatest = false,
    required this.installedAt,
    this.updatedAt,
    this.sourceUrl,
  });

  factory ExtensionMetadata.fromJson(Map<String, dynamic> json) {
    return ExtensionMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      contentType: json['contentType'] as String? ?? 'manga',
      iconUrl: json['iconUrl'] as String?,
      baseUrl: json['baseUrl'] as String?,
      supportsLatest: json['supportsLatest'] as bool? ?? false,
      installedAt: json['installedAt'] != null
          ? DateTime.parse(json['installedAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'author': author,
        'description': description,
        'language': language,
        'contentType': contentType,
        'iconUrl': iconUrl,
        'baseUrl': baseUrl,
        'supportsLatest': supportsLatest,
        'installedAt': installedAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'sourceUrl': sourceUrl,
      };

  String toJsonString() => jsonEncode(toJson());

  ExtensionMetadata copyWith({
    String? id,
    String? name,
    String? version,
    String? author,
    String? description,
    String? language,
    String? contentType,
    String? iconUrl,
    String? baseUrl,
    bool? supportsLatest,
    DateTime? installedAt,
    DateTime? updatedAt,
    String? sourceUrl,
  }) {
    return ExtensionMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      language: language ?? this.language,
      contentType: contentType ?? this.contentType,
      iconUrl: iconUrl ?? this.iconUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      supportsLatest: supportsLatest ?? this.supportsLatest,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}

/// Represents a loaded extension with its code
class LoadedExtension {
  final ExtensionMetadata metadata;
  final String jsCode;
  final bool isEnabled;

  const LoadedExtension({
    required this.metadata,
    required this.jsCode,
    this.isEnabled = true,
  });

  LoadedExtension copyWith({
    ExtensionMetadata? metadata,
    String? jsCode,
    bool? isEnabled,
  }) {
    return LoadedExtension(
      metadata: metadata ?? this.metadata,
      jsCode: jsCode ?? this.jsCode,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
