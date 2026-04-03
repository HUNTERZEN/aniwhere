import 'package:isar/isar.dart';

part 'search_history.g.dart';

/// Database model for persisting search queries
@collection
class SearchHistoryEntry {
  Id id = Isar.autoIncrement;

  /// The search query text
  @Index(unique: true, replace: true)
  late String query;

  /// When this search was last performed
  late DateTime timestamp;
}
