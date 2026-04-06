import '../sources/source.dart';
import 'extension_model.dart';
import 'extension_runtime.dart';

/// Source implementation that wraps a JavaScript extension
class ExtensionSource extends Source implements ReadableSource, WatchableSource {
  final LoadedExtension _extension;
  late final ExtensionRuntime _runtime;
  
  ExtensionSource(this._extension) {
    _runtime = ExtensionRuntime(_extension);
  }

  @override
  String get id => _extension.metadata.id;

  @override
  String get name => _extension.metadata.name;

  @override
  String get language => _extension.metadata.language;

  @override
  String get baseUrl => _extension.metadata.baseUrl ?? '';

  @override
  SourceContentType get contentType {
    switch (_extension.metadata.contentType) {
      case 'anime':
        return SourceContentType.anime;
      case 'novel':
        return SourceContentType.novel;
      default:
        return SourceContentType.manga;
    }
  }

  @override
  String? get iconUrl => _extension.metadata.iconUrl;

  @override
  bool get supportsLatest => _extension.metadata.supportsLatest;

  @override
  List<SourceFilter> get filters => []; // TODO: Parse filters from JS

  /// Initialize the runtime
  Future<void> initialize() async {
    await _runtime.initialize();
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> getPopular(int page) async {
    await _runtime.initialize();
    return _runtime.getPopular(page);
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> getLatest(int page) async {
    await _runtime.initialize();
    return _runtime.getLatest(page);
  }

  @override
  Future<SourcePaginatedResult<SourceMedia>> search(
    String query,
    int page, {
    Map<String, dynamic>? filters,
  }) async {
    await _runtime.initialize();
    return _runtime.search(query, page, filters: filters);
  }

  @override
  Future<SourceMedia> getDetails(String id) async {
    await _runtime.initialize();
    return _runtime.getDetails(id);
  }

  @override
  Future<List<SourceChapter>> getChapters(String mediaId) async {
    await _runtime.initialize();
    return _runtime.getChapters(mediaId);
  }

  @override
  Future<List<SourcePage>> getPages(String chapterId) async {
    await _runtime.initialize();
    return _runtime.getPages(chapterId);
  }

  @override
  Future<List<SourceVideo>> getVideoStreams(String episodeId) async {
    await _runtime.initialize();
    return _runtime.getVideoStreams(episodeId);
  }

  /// Dispose runtime resources
  void dispose() {
    _runtime.dispose();
  }
}
