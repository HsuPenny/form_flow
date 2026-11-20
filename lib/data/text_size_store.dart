import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The in-app 文字大小 choice. Multiplies the system font size setting
/// rather than replacing it, so a user who already enlarged text in the
/// system keeps that and can go further here.
enum TextSize {
  small(0.9, '小'),
  standard(1.0, '標準'),
  large(1.15, '大'),
  extraLarge(1.3, '特大');

  const TextSize(this.scale, this.label);

  final double scale;
  final String label;
}

/// Where the 文字大小 choice is kept. Device-local like the theme mode
/// (see ThemeModeStore): never sent to the backend.
abstract class TextSizeStore {
  Future<TextSize> load();
  Future<void> save(TextSize size);
}

/// Saves to the platform's plain key-value storage (SharedPreferences).
class PrefsTextSizeStore implements TextSizeStore {
  static const _key = 'text_size';

  @override
  Future<TextSize> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      return TextSize.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TextSize.standard,
      );
    } catch (e) {
      // A broken store shouldn't keep the app from starting.
      debugPrint('Could not read text size: $e');
      return TextSize.standard;
    }
  }

  @override
  Future<void> save(TextSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, size.name);
  }
}

/// Keeps the choice in memory only; the default for tests.
class MemoryTextSizeStore implements TextSizeStore {
  TextSize _size = TextSize.standard;

  @override
  Future<TextSize> load() async => _size;

  @override
  Future<void> save(TextSize size) async => _size = size;
}
