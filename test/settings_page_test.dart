import 'package:flutter/material.dart';
import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/main.dart';
import 'package:flutter_form_flow/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppState> openSettings(WidgetTester tester, Role role) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(
      auth: MockAuthRepository(role: role),
      forms: MockFormRepository(),
    );
    await state.login(email: 'a@b.c', password: 'pw');
    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('個人設定').last);
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('admins pick the department from a bottom sheet', (tester) async {
    final state = await openSettings(tester, Role.admin);
    expect(find.byType(AppDropdownField<String>), findsOneWidget);
    expect(find.text('部門由管理員設定'), findsNothing);

    await tester.tap(find.byType(AppDropdownField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工程部').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存變更'));
    await tester.pumpAndSettle();
    expect(state.department, '工程部');
  });

  testWidgets('members see their department read-only', (tester) async {
    final state = await openSettings(tester, Role.member);
    expect(find.byType(AppDropdownField<String>), findsNothing);
    expect(find.text('部門由管理員設定'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '新名字');
    await tester.tap(find.text('儲存變更'));
    await tester.pumpAndSettle();
    expect(state.displayName, '新名字');
    expect(state.department, '營運管理');
  });

  testWidgets('change password dialog validates and closes', (tester) async {
    await openSettings(tester, Role.member);
    await tester.tap(find.text('修改密碼'));
    await tester.pumpAndSettle();

    bool canSubmit() => tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text('更新密碼'),
            matching: find.byType(FilledButton),
          ),
        )
        .enabled;
    expect(canSubmit(), false);

    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'old-pass');
    await tester.enterText(fields.at(1), 'new-pass');
    await tester.enterText(fields.at(2), 'typo-pass');
    await tester.pump();
    expect(canSubmit(), true);
    await tester.tap(find.text('更新密碼'));
    await tester.pump();
    expect(find.text('兩次輸入的新密碼不一致'), findsOneWidget);

    await tester.enterText(fields.at(2), 'new-pass');
    await tester.tap(find.text('更新密碼'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('密碼已更新'), findsOneWidget);
  });
}
