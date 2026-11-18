import 'package:flutter/material.dart';

import '../data/form_report.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// 統計: every question of [form] with its replies summed up — bars for
/// choices and dates, the latest answers for 簡答 / 段落.
class ResponseStats extends StatelessWidget {
  const ResponseStats(this.form, {super.key});

  final FormItem form;

  @override
  Widget build(BuildContext context) {
    if (form.responses.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '還沒有人回覆',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.mutedForeground,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < form.questions.length; i++)
          _QuestionStatsCard(index: i, stats: QuestionStats.of(form, i)),
      ],
    );
  }
}

class _QuestionStatsCard extends StatelessWidget {
  const _QuestionStatsCard({required this.index, required this.stats});

  final int index;
  final QuestionStats stats;

  @override
  Widget build(BuildContext context) {
    final q = stats.question;
    final note = q.type == QuestionType.multiple ? ' · 可複選' : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.colors.secondary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${index + 1}. ',
                  style: AppText.mono.copyWith(
                    color: context.colors.primaryDeep,
                  ),
                ),
                TextSpan(text: q.title),
              ],
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${q.type.label} · ${stats.answered} 人回答$note',
            style: TextStyle(
              fontSize: 11,
              color: context.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          if (stats.answered == 0)
            Text(
              '沒有人回答這題',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.mutedForeground,
              ),
            )
          else if (stats.isChart) ...[
            for (final o in stats.options) _bar(context, o),
            if (stats.texts.isNotEmpty) ...[
              const SizedBox(height: 4),
              _TextAnswers(stats.texts, label: '「其他」填寫內容'),
            ],
          ] else
            _TextAnswers(stats.texts),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, OptionCount o) {
    final share = stats.share(o);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.label, style: const TextStyle(fontSize: 12)),
              ),
              Text(
                '${o.count} 人 · ${(share * 100).round()}%',
                style: AppText.mono.copyWith(
                  fontSize: 11,
                  color: context.colors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: context.colors.muted,
              color: context.colors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Free-text answers, newest first; shows [_initial] until 顯示全部.
class _TextAnswers extends StatefulWidget {
  const _TextAnswers(this.texts, {this.label});

  final List<({Member member, String text})> texts;
  final String? label;

  @override
  State<_TextAnswers> createState() => _TextAnswersState();
}

class _TextAnswersState extends State<_TextAnswers> {
  static const _initial = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final texts = widget.texts;
    final shown = _all ? texts : texts.take(_initial);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label case final label?)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.mutedForeground,
              ),
            ),
          ),
        for (final t in shown)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.text, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  t.member.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        if (texts.length > _initial)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _all ? '收合' : '顯示全部 ${texts.length} 則',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
