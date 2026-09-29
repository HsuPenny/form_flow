import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_form_flow/data/app_state.dart';
import 'package:flutter_form_flow/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MyApp(state: AppState()));
    // Let the login intro animation play out.
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('login → overview → tracking → settings at $size',
        (tester) async {
      await pumpApp(tester, size);
      expect(find.text('進入你的工作區'), findsOneWidget);

      await tester.tap(find.text('使用示範身份進入'));
      await tester.pumpAndSettle();
      expect(find.text('把重要的事，問清楚。'), findsOneWidget);
      expect(find.text('2026 Q3 產品策略工作坊回饋'), findsOneWidget);

      await tester.tap(find.text('回覆追蹤').last);
      await tester.pumpAndSettle();
      expect(find.text('看見事情走到哪裡'), findsOneWidget);

      await tester.tap(find.text('點擊查看名單').first);
      await tester.pumpAndSettle();
      expect(find.text('林郁婷'), findsOneWidget);

      await tester.tap(find.text('林郁婷'));
      await tester.pumpAndSettle();
      expect(find.text('實作演練、案例分享'), findsOneWidget);
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('個人設定').last);
      await tester.pumpAndSettle();
      expect(find.text('讓工作區更像你的'), findsOneWidget);
    });

    testWidgets('create form wizard at $size', (tester) async {
      await pumpApp(tester, size);
      await tester.tap(find.text('使用示範身份進入'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('建立新表單'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('下一步'));
      await tester.tap(find.text('下一步'));
      await tester.pump();
      expect(find.text('請補上表單說明'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '測試表單');
      await tester.enterText(find.byType(TextField).at(1), '說明');
      await tester.ensureVisible(find.text('下一步'));
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('你想知道什麼？'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '問題一');
      await tester.ensureVisible(find.text('查看預覽'));
      await tester.tap(find.text('查看預覽'));
      await tester.pumpAndSettle();
      expect(find.text('送出前，再看一眼'), findsOneWidget);

      await tester.ensureVisible(find.text('立即發佈'));
      await tester.tap(find.text('立即發佈'));
      await tester.pumpAndSettle();
      expect(find.text('測試表單'), findsOneWidget);
    });
  }

  testWidgets('member fills a form', (tester) async {
    await pumpApp(tester, const Size(1280, 800));
    await tester.tap(find.text('團隊成員'));
    await tester.tap(find.text('使用示範身份進入'));
    await tester.pumpAndSettle();
    expect(find.text('回覆追蹤'), findsNothing);
    expect(find.text('專案結案回顧｜星港改版'), findsNothing);

    await tester.tap(find.text('2026 Q3 產品策略工作坊回饋'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('送出回覆'));
    await tester.tap(find.text('送出回覆'));
    await tester.pump();
    expect(find.text('此題為必填'), findsOneWidget);

    await tester.ensureVisible(find.text('非常適合'));
    await tester.tap(find.text('非常適合'));
    await tester.ensureVisible(find.text('送出回覆'));
    await tester.tap(find.text('送出回覆'));
    await tester.pumpAndSettle();
    expect(find.text('今天要回覆的表單'), findsOneWidget);
  });
}
