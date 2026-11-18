import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_form_flow/data/form_report.dart';
import 'package:flutter_form_flow/data/models.dart';

void main() {
  const amy = Member('a', '林郁婷', '產品部');
  const ben = Member('b', '陳柏宇', '工程部');
  const cat = Member('c', '王小貓', '設計部');

  FormItem form(List<FormResponse> responses) => FormItem(
    id: 'f1',
    title: '工作坊 / 回饋',
    description: '',
    deadline: DateTime(2026, 10, 30),
    status: FormStatus.pending,
    questions: [
      Question(
        title: '適合嗎',
        type: QuestionType.single,
        options: ['適合', '不適合'],
        allowOther: true,
      ),
      Question(
        title: '想學',
        type: QuestionType.multiple,
        options: ['A', 'B', 'C'],
      ),
      Question(title: '建議', type: QuestionType.paragraph, required: false),
      Question(title: '日期', type: QuestionType.date, options: []),
    ],
    recipients: [amy, ben, cat],
    responses: responses,
  );

  final responses = [
    FormResponse(
      member: amy,
      submittedAt: DateTime(2026, 10, 20, 9, 5),
      answers: {
        0: '適合',
        1: {'A', 'B'},
        2: '多一點實作, 少一點 "簡報"',
        3: '2026-11-02',
      },
    ),
    FormResponse(
      member: ben,
      submittedAt: DateTime(2026, 10, 21, 14, 30),
      answers: {
        0: const OtherAnswer('看主題'),
        1: {'B'},
        3: '2026-11-01',
      },
    ),
  ];

  group('QuestionStats', () {
    test('counts single choice, with「其他」last and its text kept', () {
      final s = QuestionStats.of(form(responses), 0);
      expect(s.answered, 2);
      expect(s.isChart, isTrue);
      expect(
        [for (final o in s.options) (o.label, o.count)],
        [('適合', 1), ('不適合', 0), ('其他', 1)],
      );
      expect(s.texts.single.text, '看主題');
      expect(s.share(s.options.first), 0.5);
    });

    test('checkbox shares are per person and can add past 100%', () {
      final s = QuestionStats.of(form(responses), 1);
      expect([for (final o in s.options) o.count], [1, 2, 0]);
      expect(s.share(s.options[1]), 1);
    });

    test('skipped optional questions are not counted', () {
      final s = QuestionStats.of(form(responses), 2);
      expect(s.answered, 1);
      expect(s.isChart, isFalse);
      expect(s.texts.single.member, amy);
    });

    test('dates are counted per day in calendar order', () {
      final s = QuestionStats.of(form(responses), 3);
      expect(
        [for (final o in s.options) o.label],
        ['2026-11-01', '2026-11-02'],
      );
    });

    test('no replies', () {
      final s = QuestionStats.of(form([]), 0);
      expect(s.answered, 0);
      expect(s.share(s.options.first), 0);
    });
  });

  group('formToCsv', () {
    test('one row per recipient, answered first, quoted where needed', () {
      final csv = formToCsv(form(responses));
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(lines, [
        '姓名,部門,狀態,填寫時間,1. 適合嗎,2. 想學,3. 建議,4. 日期',
        '林郁婷,產品部,已回覆,2026-10-20 09:05,適合,A、B,'
            '"多一點實作, 少一點 ""簡報""",2026-11-02',
        '陳柏宇,工程部,已回覆,2026-10-21 14:30,其他：看主題,B,,2026-11-01',
        '王小貓,設計部,未回覆,,,,,',
        '',
      ]);
    });

    test('defuses cells that spreadsheets would run as formulas', () {
      final csv = formToCsv(
        form([
          FormResponse(
            member: amy,
            submittedAt: DateTime(2026, 10, 20),
            answers: {2: '=HYPERLINK("x")'},
          ),
        ]),
      );
      expect(csv, contains(',"\'=HYPERLINK(""x"")",'));
    });
  });

  test('csvFileName drops characters file systems reject', () {
    expect(csvFileName(form([])), '工作坊_回饋_回覆.csv');
  });
}
