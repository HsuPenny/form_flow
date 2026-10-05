import 'package:flutter/material.dart';
import 'package:flutter_form_flow/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String?>> pumpField(WidgetTester tester, String? initial) async {
    final changes = <String?>[];
    String? value = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppDropdownField<String?>(
              value: value,
              hint: '請選擇表單',
              items: const [(null, '全部表單'), ('a', '表單 A'), ('b', '表單 B')],
              onChanged: (v) => setState(() {
                value = v;
                changes.add(v);
              }),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('opens a bottom sheet and reports the picked value', (
    tester,
  ) async {
    final changes = await pumpField(tester, null);
    expect(find.text('全部表單'), findsOneWidget);

    await tester.tap(find.byType(AppDropdownField<String?>));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('表單 B'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(changes, ['b']);
    expect(find.text('表單 B'), findsOneWidget);
  });

  testWidgets('a null option can be picked; dismissing changes nothing', (
    tester,
  ) async {
    final changes = await pumpField(tester, 'a');

    await tester.tap(find.byType(AppDropdownField<String?>));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // barrier
    await tester.pumpAndSettle();
    expect(changes, isEmpty);

    await tester.tap(find.byType(AppDropdownField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部表單'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
  });
}
