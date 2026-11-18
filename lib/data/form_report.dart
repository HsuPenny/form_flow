import 'models.dart';

/// How many people picked one choice of a question.
class OptionCount {
  const OptionCount(this.label, this.count);

  final String label;
  final int count;
}

/// One question's replies, summed up for the 回覆統計 view.
class QuestionStats {
  QuestionStats._(this.question, this.answered, this.options, this.texts);

  /// Counts [form]'s responses to question [index].
  factory QuestionStats.of(FormItem form, int index) {
    final question = form.questions[index];
    final counts = <String, int>{
      for (final o in question.options) o: 0,
      if (question.allowOther) _other: 0,
    };
    final texts = <({Member member, String text})>[];
    var answered = 0;

    // Newest first, so the text answers list leads with the latest.
    final responses = [...form.responses]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    for (final r in responses) {
      final value = r.answers[index];
      if (!_isAnswered(value)) continue;
      answered++;
      switch (value) {
        case Set<String> picked:
          for (final o in picked) {
            counts[o] = (counts[o] ?? 0) + 1;
          }
        case OtherAnswer o:
          counts[_other] = (counts[_other] ?? 0) + 1;
          texts.add((member: r.member, text: o.text.trim()));
        case _ when _counted(question.type):
          final s = value.toString();
          counts[s] = (counts[s] ?? 0) + 1;
        case _:
          texts.add((member: r.member, text: value.toString().trim()));
      }
    }

    final options = [
      for (final MapEntry(:key, :value) in counts.entries)
        OptionCount(key, value),
    ];
    // Dates have no fixed options; list them in calendar order.
    if (question.type == QuestionType.date) {
      options.sort((a, b) => a.label.compareTo(b.label));
    }
    return QuestionStats._(question, answered, options, texts);
  }

  static const _other = '其他';

  final Question question;

  /// People who answered this question (skipped optional ones don't count).
  final int answered;

  /// Count per choice, in the question's option order, with「其他」last.
  /// Dates are counted per day. Empty for 簡答 / 段落.
  final List<OptionCount> options;

  /// Free text, newest first: 簡答 / 段落 answers, or what was typed
  /// under「其他」.
  final List<({Member member, String text})> texts;

  /// Shows [options] as counts rather than a list of answers.
  bool get isChart => _counted(question.type);

  static bool _counted(QuestionType t) =>
      t.hasOptions || t == QuestionType.date;

  /// Share of [answered] who picked [o]. For 核取方塊 these can add up to
  /// more than 1.
  double share(OptionCount o) => answered == 0 ? 0 : o.count / answered;
}

/// Same rule as the form renderer: a blank「其他」isn't an answer.
bool _isAnswered(Object? v) => switch (v) {
  null => false,
  Set<String> s => s.isNotEmpty,
  OtherAnswer o => o.text.trim().isNotEmpty,
  _ => v.toString().trim().isNotEmpty,
};

/// [form] as CSV, one row per recipient: 已回覆 first (oldest reply first),
/// then 未回覆 with blank answers. Starts with a BOM so Excel reads the
/// Chinese text as UTF-8.
String formToCsv(FormItem form) {
  final responded = [...form.responses]
    ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
  final waiting = [
    for (final m in form.recipients)
      if (!form.hasResponded(m)) m,
  ];

  final rows = <List<String>>[
    [
      '姓名',
      '部門',
      '狀態',
      '填寫時間',
      for (var i = 0; i < form.questions.length; i++)
        '${i + 1}. ${form.questions[i].title}',
    ],
    for (final r in responded)
      [
        r.member.name,
        r.member.department,
        '已回覆',
        formatDateTime(r.submittedAt),
        for (var i = 0; i < form.questions.length; i++)
          _isAnswered(r.answers[i]) ? formatAnswer(r.answers[i]) : '',
      ],
    for (final m in waiting)
      [m.name, m.department, '未回覆', '', for (final _ in form.questions) ''],
  ];
  return '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n';
}

/// A file name for [form]'s export, safe on every platform.
String csvFileName(FormItem form) {
  final title = form.title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return '${title}_回覆.csv';
}

String _csvCell(String value) {
  // Spreadsheets run cells starting with these as formulas.
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;
  return RegExp(r'[",\r\n]').hasMatch(safe)
      ? '"${safe.replaceAll('"', '""')}"'
      : safe;
}
