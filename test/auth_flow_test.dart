import 'package:flutter/material.dart';
import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('login and signup at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState(
        auth: MockAuthRepository(),
        forms: MockFormRepository(),
      );
      await tester.pumpWidget(MyApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('登入').last);
      await tester.pump();
      expect(find.text('請輸入工作信箱'), findsOneWidget);

      await tester.tap(find.text('還沒有帳號？建立帳號'));
      await tester.pumpAndSettle();
      expect(find.text('顯示名稱'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '測試者');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.c');
      await tester.enterText(find.byType(TextField).at(2), '123');
      await tester.tap(find.text('建立帳號'));
      await tester.pumpAndSettle();
      expect(find.text('密碼至少需要 6 個字元'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(2), '123456');
      await tester.tap(find.text('建立帳號'));
      await tester.pumpAndSettle();
      expect(state.isLoggedIn, true);
      expect(state.displayName, '測試者');
      expect(state.email, 'a@b.c');
      expect(state.forms, isNotEmpty);

      await state.submitResponse(state.forms.first, {0: 'x'});
      expect(state.forms.first.hasResponded(state.me), true);

      // Let the validation toast time out so it doesn't cover the page.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('個人設定').last);
      await tester.pumpAndSettle();
      expect(find.text('切換示範身份'), findsNothing);
      // Centered, so the mobile bottom bar doesn't cover it.
      await Scrollable.ensureVisible(
        tester.element(find.text('登出工作區')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('登出工作區'));
      await tester.pumpAndSettle();
      expect(state.isLoggedIn, false);
      expect(find.text('還沒有帳號？建立帳號'), findsOneWidget);
    });
  }

  test('role comes from the auth repository', () async {
    final s = AppState(
      auth: MockAuthRepository(role: Role.member),
      forms: MockFormRepository(),
    );
    await s.login(email: 'x@y.z', password: 'pw');
    expect(s.isAdmin, false);
  });
}
