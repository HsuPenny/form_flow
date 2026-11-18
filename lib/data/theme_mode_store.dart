import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the 淺色 / 深色 / 跟隨系統 choice is kept. Local to the device on
/// purpose: it is never sent to the backend, so each device keeps its own.
abstract class ThemeModeStore {
  Future<ThemeMode> load();
  Future<void> save(ThemeMode mode);
}

/// Saves to the platform's plain key-value storage (SharedPreferences).
class PrefsThemeModeStore implements ThemeModeStore {
  static const _key = 'theme_mode';

  @override
  Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      return ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
    } catch (e) {
      // A broken store shouldn't keep the app from starting.
      debugPrint('Could not read theme mode: $e');
      return ThemeMode.system;
    }
  }

  @override
  Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

/// Keeps the choice in memory only; the default for tests.
class MemoryThemeModeStore implements ThemeModeStore {
  ThemeMode _mode = ThemeMode.system;

  @override
  Future<ThemeMode> load() async => _mode;

  @override
  Future<void> save(ThemeMode mode) async => _mode = mode;
}
