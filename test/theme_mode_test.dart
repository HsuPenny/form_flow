import 'package:flutter/material.dart';
import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/data/theme_mode_store.dart';
import 'package:flutter_form_flow/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setThemeMode applies, notifies and saves the choice', () async {
    final store = MemoryThemeModeStore();
    final state = AppState(
      auth: MockAuthRepository(),
      forms: MockFormRepository(),
      themeStore: store,
    );
    var notified = 0;
    state.addListener(() => notified++);

    expect(state.themeMode, ThemeMode.system);
    await state.setThemeMode(ThemeMode.dark);
    expect(state.themeMode, ThemeMode.dark);
    expect(notified, 1);
    expect(await store.load(), ThemeMode.dark);

    // Picking the current mode again is a no-op.
    await state.setThemeMode(ThemeMode.dark);
    expect(notified, 1);
  });

  test('PrefsThemeModeStore round-trips and defaults to system', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsThemeModeStore();
    expect(await store.load(), ThemeMode.system);

    await store.save(ThemeMode.light);
    expect(await PrefsThemeModeStore().load(), ThemeMode.light);

    SharedPreferences.setMockInitialValues({'theme_mode': 'bogus'});
    expect(await PrefsThemeModeStore().load(), ThemeMode.system);
  });

  test('each theme carries the matching AppColors', () {
    expect(buildAppTheme().extension<AppColors>(), AppColors.light);
    expect(
      buildAppTheme(Brightness.dark).extension<AppColors>(),
      AppColors.dark,
    );
    expect(buildAppTheme(Brightness.dark).brightness, Brightness.dark);
  });
}
