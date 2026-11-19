import 'package:flutter/material.dart';
import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/data/text_size_store.dart';
import 'package:flutter_form_flow/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setTextSize applies, notifies and saves the choice', () async {
    final store = MemoryTextSizeStore();
    final state = AppState(
      auth: MockAuthRepository(),
      forms: MockFormRepository(),
      textSizeStore: store,
    );
    var notified = 0;
    state.addListener(() => notified++);

    expect(state.textSize, TextSize.standard);
    await state.setTextSize(TextSize.large);
    expect(state.textSize, TextSize.large);
    expect(notified, 1);
    expect(await store.load(), TextSize.large);

    // Picking the current size again is a no-op.
    await state.setTextSize(TextSize.large);
    expect(notified, 1);
  });

  test('PrefsTextSizeStore round-trips and defaults to standard', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsTextSizeStore();
    expect(await store.load(), TextSize.standard);

    await store.save(TextSize.extraLarge);
    expect(await PrefsTextSizeStore().load(), TextSize.extraLarge);

    SharedPreferences.setMockInitialValues({'text_size': 'bogus'});
    expect(await PrefsTextSizeStore().load(), TextSize.standard);
  });

  test('AppTextScaler stacks on the system scale', () {
    const scaler = AppTextScaler(TextScaler.linear(1.2), 1.5);
    expect(scaler.scale(10), closeTo(18, 1e-9));
    expect(scaler, const AppTextScaler(TextScaler.linear(1.2), 1.5));
    expect(scaler == const AppTextScaler(TextScaler.linear(1.2), 1), isFalse);
  });
}
