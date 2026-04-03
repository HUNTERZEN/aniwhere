import 'package:isar/isar.dart';

part 'category.g.dart';

/// Represents a user-defined category for organizing library entries
@collection
class LibraryCategory {
  Id id = Isar.autoIncrement;

  /// Name of the category
  @Index(unique: true)
  late String name;

  /// Sort order for display
  int sortOrder = 0;

  /// Color for the category (stored as ARGB int)
  int? color;

  /// Icon code point (from MaterialIcons)
  int? iconCodePoint;

  /// Whether this category is the default for new entries
  bool isDefault = false;

  /// Date created
  DateTime dateCreated = DateTime.now();

  /// Number of items in this category (not stored, computed)
  @ignore
  int itemCount = 0;
}
