import 'package:flutter/material.dart';
import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/main.dart';
import 'package:flutter_form_flow/pages/shell.dart';
import 'package:flutter_form_flow/pages/splash_page.dart';
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
      await tester.enterText(find.byType(TextField).at(3), '654321');
      await tester.tap(find.text('建立帳號'));
      await tester.pumpAndSettle();
      expect(find.text('兩次輸入的密碼不一致'), findsOneWidget);
      expect(state.isLoggedIn, false);
      await tester.enterText(find.byType(TextField).at(3), '123456');
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

  testWidgets('forgot and reset password from the login page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(
      auth: MockAuthRepository(),
      forms: MockFormRepository(),
    );
    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();

    // The eye button reveals and hides the password.
    bool obscured() => tester.widget<TextField>(find.byType(TextField).at(1))
        .obscureText;
    expect(obscured(), true);
    await tester.tap(find.byTooltip('顯示密碼'));
    await tester.pump();
    expect(obscured(), false);
    await tester.tap(find.byTooltip('隱藏密碼'));
    await tester.pump();
    expect(obscured(), true);

    await tester.enterText(find.byType(TextField).at(0), 'a@b.c');
    await tester.tap(find.text('忘記密碼？'));
    await tester.pumpAndSettle();
    // The email typed on the login page carries over.
    expect(find.text('a@b.c'), findsOneWidget);

    bool enabled(String label) => tester
        .widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        )
        .enabled;

    // Send is disabled while the email is empty.
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(enabled('寄送驗證碼'), false);
    await tester.enterText(find.byType(TextField), 'a@b.c');
    await tester.pump();
    expect(enabled('寄送驗證碼'), true);

    await tester.tap(find.text('寄送驗證碼'));
    await tester.pumpAndSettle();
    expect(find.text('請到信箱查收'), findsOneWidget);

    await tester.tap(find.text('輸入驗證碼'));
    await tester.pumpAndSettle();
    expect(find.text('重設密碼'), findsOneWidget);
    expect(enabled('更新密碼'), false);
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), 'newpass');
    await tester.enterText(find.byType(TextField).at(2), 'other');
    await tester.pump();
    expect(enabled('更新密碼'), true);
    await tester.tap(find.text('更新密碼'));
    await tester.pumpAndSettle();
    expect(find.text('兩次輸入的密碼不一致'), findsOneWidget);
    expect(state.isLoggedIn, false);

    await tester.enterText(find.byType(TextField).at(2), 'newpass');
    await tester.tap(find.text('更新密碼'));
    await tester.pumpAndSettle();
    // Signed in, with the pushed pages gone.
    expect(state.isLoggedIn, true);
    expect(find.text('重設密碼'), findsNothing);
    expect(find.text('請到信箱查收'), findsNothing);
  });

  testWidgets('a restored session plays the splash before the app', (
    tester,
  ) async {
    // A session saved by a previous launch.
    final auth = MockAuthRepository();
    await auth.signIn(email: 'a@b.c', password: 'pw');
    final state = AppState(auth: auth, forms: MockFormRepository());
    state.restoreSession();
    await tester.pumpWidget(MyApp(state: state));
    await tester.pump();
    await tester.pump();
    expect(state.isLoggedIn, true);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(AppShell), findsOneWidget);
  });

  test('role comes from the auth repository', () async {
    final s = AppState(
      auth: MockAuthRepository(role: Role.member),
      forms: MockFormRepository(),
    );
    await s.login(email: 'x@y.z', password: 'pw');
    expect(s.isAdmin, false);
  });
}
