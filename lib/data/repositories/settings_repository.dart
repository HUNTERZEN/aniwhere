import '../models/app_settings.dart';
import '../sources/database_service.dart';

/// Repository for managing app settings
class SettingsRepository {
  /// Get current settings
  Future<AppSettings> getSettings() async {
    final isar = await DatabaseService.instance;
    return await isar.appSettings.get(0) ?? AppSettings();
  }

  /// Save settings
  Future<void> saveSettings(AppSettings settings) async {
    final isar = await DatabaseService.instance;
    settings.id = 0; // Ensure single instance
    await isar.writeTxn(() => isar.appSettings.put(settings));
  }

  /// Update a single setting
  Future<void> updateSetting(void Function(AppSettings) updater) async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() async {
      final settings = await isar.appSettings.get(0) ?? AppSettings();
      updater(settings);
      await isar.appSettings.put(settings);
    });
  }

  /// Watch settings changes
  Stream<AppSettings?> watchSettings() async* {
    final isar = await DatabaseService.instance;
    yield* isar.appSettings.watchObject(0, fireImmediately: true);
  }

  /// Reset settings to defaults
  Future<void> resetSettings() async {
    final isar = await DatabaseService.instance;
    await isar.writeTxn(() => isar.appSettings.put(AppSettings()));
  }
}
