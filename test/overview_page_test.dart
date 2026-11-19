import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/main.dart';
import 'package:flutter_form_flow/data/repositories/form_repository.dart';

void main() {
  testWidgets('已截止 tab loads more forms as the list scrolls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = MockFormRepository();
    final state = AppState(auth: MockAuthRepository(), forms: repo);
    await state.login(email: 'me@example.com', password: 'secret');
    final me = state.me;
    final lastWeek = DateTime.now().subtract(const Duration(days: 7));
    for (var i = 0; i < 25; i++) {
      await repo.saveForm(
        FormItem(
          id: 'old$i',
          title: '過期表單 $i',
          description: '',
          deadline: DateTime(lastWeek.year, lastWeek.month, lastWeek.day - i),
          status: FormStatus.pending,
          questions: [],
          recipients: [me],
        ),
      );
    }

    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();

    // 待完成 only lists forms that still take replies.
    expect(find.text('過期表單 0'), findsNothing);

    await tester.tap(find.text('已截止').first);
    await tester.pumpAndSettle();
    expect(find.text('過期表單 0'), findsOneWidget);
    expect(find.textContaining('截止・未回覆'), findsWidgets);
    expect(find.text('過期表單 24'), findsNothing);

    // Scroll to the end: the second batch arrives, then the end note.
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('過期表單 24'), findsOneWidget);
    expect(find.text('已經沒有更多表單了'), findsOneWidget);

    // An expired form opens read-only.
    await tester.tap(find.text('過期表單 24'));
    await tester.pumpAndSettle();
    expect(find.textContaining('無法再填寫'), findsOneWidget);
  });

  testWidgets('members load each tab from the backend, not every form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = MockFormRepository();
    final state = AppState(
      auth: MockAuthRepository(role: Role.member),
      forms: repo,
    );
    await state.login(email: 'me@example.com', password: 'secret');
    final me = state.me;
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    for (var i = 0; i < 25; i++) {
      await repo.saveForm(
        FormItem(
          id: 'open$i',
          title: '待填表單 $i',
          description: '',
          deadline: DateTime(nextWeek.year, nextWeek.month, nextWeek.day + i),
          status: FormStatus.pending,
          questions: [],
          recipients: [me],
        ),
      );
    }

    // Soonest deadline first, 20 at a time.
    final first = await state.fetchMyForms(FormCategory.pending);
    expect(first.items, hasLength(20));
    expect(first.total, 25);
    expect(first.items.first.id, 'open0');

    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('待填表單 0'), findsOneWidget);
    expect(find.text('待填表單 24'), findsNothing);
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
    expect(find.text('待填表單 24'), findsOneWidget);
  });

  testWidgets('after submitting, the next form comes from the backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = MockFormRepository();
    final state = AppState(
      auth: MockAuthRepository(role: Role.member),
      forms: repo,
    );
    await state.login(email: 'me@example.com', password: 'secret');
    final me = state.me;
    final soon = DateTime.now().add(const Duration(days: 1));
    for (final (id, days) in [('aaa', 0), ('bbb', 1)]) {
      await repo.saveForm(
        FormItem(
          id: id,
          title: '表單 $id',
          description: '',
          deadline: DateTime(soon.year, soon.month, soon.day + days),
          status: FormStatus.pending,
          questions: [Question(title: '姓名', type: QuestionType.shortText)],
          recipients: [me],
        ),
      );
    }
    final pendingBefore = (await state.fetchMyForms(
      FormCategory.pending,
    )).total;

    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('表單 aaa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '小明');
    await tester.tap(find.text('送出回覆'));
    await tester.pumpAndSettle();

    expect(find.text('已送出，謝謝你的回覆'), findsOneWidget);
    // aaa now has a reply, so the soonest open form left is bbb.
    expect(find.text('還有 ${pendingBefore - 1} 份待填寫'), findsOneWidget);
    expect(find.text('表單 bbb'), findsOneWidget);
  });
}
