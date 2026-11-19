import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/mock_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/mock_form_repository.dart';
import 'package:flutter_form_flow/main.dart';

void main() {
  late MockFormRepository repo;
  late AppState state;

  Future<void> openTracking(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MyApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('表單管理').last);
    await tester.pumpAndSettle();
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -1500));
      await tester.pumpAndSettle();
    }
  }

  setUp(() async {
    repo = MockFormRepository();
    state = AppState(auth: MockAuthRepository(), forms: repo);
    await state.login(email: 'me@example.com', password: 'secret');
  });

  testWidgets('完成進度 loads more forms as the list scrolls', (tester) async {
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    for (var i = 0; i < 25; i++) {
      await repo.saveForm(
        FormItem(
          id: 'p$i',
          title: '進度表單 ${i.toString().padLeft(2, '0')}',
          description: '',
          deadline: nextWeek,
          status: FormStatus.pending,
          questions: [],
          recipients: [state.me],
        ),
      );
    }
    final summary = await repo.fetchProgressSummary();

    await openTracking(tester);

    // Newest first, 20 at a time.
    expect(find.text('進度表單 24'), findsOneWidget);
    expect(find.text('進度表單 00'), findsNothing);
    // The totals cover every published form, not just the first batch.
    expect(find.text('${summary.waiting}'), findsOneWidget);

    await scrollToEnd(tester);
    expect(find.text('進度表單 00'), findsOneWidget);
    expect(find.text('已經沒有更多表單了'), findsOneWidget);
  });

  testWidgets('最新回覆 loads more replies as the list scrolls', (tester) async {
    final now = DateTime.now();
    final people = [
      for (var i = 0; i < 25; i++)
        Member('r$i', '填答者${i.toString().padLeft(2, '0')}', ''),
    ];
    await repo.saveForm(
      FormItem(
        id: 'busy',
        title: '熱門表單',
        description: '',
        deadline: now.add(const Duration(days: 7)),
        status: FormStatus.pending,
        questions: [],
        recipients: people,
        responses: [
          for (var i = 0; i < 25; i++)
            FormResponse(
              member: people[i],
              // 填答者00 is the newest.
              submittedAt: now.subtract(Duration(minutes: i)),
              answers: {},
            ),
        ],
      ),
    );

    await openTracking(tester);
    await tester.tap(find.text('最新回覆'));
    await tester.pumpAndSettle();

    expect(find.textContaining('填答者00'), findsOneWidget);
    expect(find.textContaining('填答者24'), findsNothing);
    expect(find.text('顯示更多'), findsNothing);

    await scrollToEnd(tester);
    expect(find.textContaining('填答者24'), findsOneWidget);
    expect(find.text('已經沒有更多回覆了'), findsOneWidget);
  });

  testWidgets('searching 最新回覆 asks the backend again', (tester) async {
    final now = DateTime.now();
    final someone = Member('x1', '搜尋目標人', '');
    await repo.saveForm(
      FormItem(
        id: 'needle',
        title: '獨特標題表單',
        description: '',
        deadline: now.add(const Duration(days: 7)),
        status: FormStatus.pending,
        questions: [],
        recipients: [someone],
        responses: [
          FormResponse(member: someone, submittedAt: now, answers: {}),
        ],
      ),
    );
    final all = (await state.fetchResponses()).total;
    expect(all, greaterThan(1));

    await openTracking(tester);
    await tester.tap(find.text('最新回覆'));
    await tester.pumpAndSettle();

    // Narrow screens keep the search box behind a toggle.
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '獨特標題');
    // Past the search debounce.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.textContaining('搜尋目標人'), findsOneWidget);
    expect(find.textContaining('填寫了「'), findsOneWidget);
  });

  testWidgets('drafts still load in one go and can be deleted', (tester) async {
    await openTracking(tester);
    await tester.tap(find.text('草稿'));
    await tester.pumpAndSettle();

    final drafts = await state.fetchDrafts();
    expect(drafts, isNotEmpty);
    expect(find.text(drafts.first.title), findsOneWidget);

    await tester.tap(find.byTooltip('刪除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '刪除'));
    await tester.pumpAndSettle();
    expect(find.text(drafts.first.title), findsNothing);
  });
}
