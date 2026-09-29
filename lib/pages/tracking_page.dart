import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  String? _formFilter; // form id, null = 全部表單
  int _tab = 0; // 0 完成進度, 1 最新回覆
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final forms = _formFilter == null
        ? app.forms
        : app.forms.where((f) => f.id == _formFilter).toList();

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: '回覆追蹤',
            title: '看見事情走到哪裡',
            subtitle: '點選一份表單，查看已回覆與未回覆名單；再點選已回覆的人即可查看答案。',
            icon: BrandGlyph.tracking,
          ),
          const SizedBox(height: 12),
          _StatTiles(forms),
          const SizedBox(height: 12),
          AppDropdownField<String?>(
            value: _formFilter,
            icon: Icons.filter_list,
            fillColor: Colors.white,
            items: [(null, '全部表單'), for (final f in app.forms) (f.id, f.title)],
            onChanged: (v) => setState(() {
              _formFilter = v;
              _expandedId = v;
            }),
          ),
          const SizedBox(height: 16),
          SegmentedTabs(
            labels: const ['完成進度', '最新回覆'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) _progressView(forms) else _Timeline(forms),
        ],
      ),
    );
  }

  Widget _progressView(List<FormItem> forms) {
    final wide = isWide(context);
    FormItem? expanded;
    for (final f in forms) {
      if (f.id == _expandedId) expanded = f;
    }

    final cards = Column(
      children: [
        for (final f in forms) ...[
          _ProgressCard(
            form: f,
            expanded: f.id == _expandedId,
            // Narrow screens open the name list inside the card itself.
            showList: !wide && f.id == _expandedId,
            onTap: () =>
                setState(() => _expandedId = _expandedId == f.id ? null : f.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );

    if (!wide) return cards;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: cards),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: expanded == null
              ? const SizedBox.shrink()
              : _RecipientsPanel(
                  form: expanded,
                  onClose: () => setState(() => _expandedId = null),
                ),
        ),
      ],
    );
  }
}

/// 整體回覆率 / 已回覆 / 待回覆 across the forms being shown.
class _StatTiles extends StatelessWidget {
  const _StatTiles(this.forms);

  final List<FormItem> forms;

  @override
  Widget build(BuildContext context) {
    var total = 0, responded = 0;
    for (final f in forms) {
      total += f.totalCount;
      responded += f.respondedCount;
    }
    final rate = total == 0 ? 0 : (responded / total * 100).round();

    Widget tile(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppText.mono.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        tile('整體回覆率', '$rate%', AppColors.foreground),
        const SizedBox(width: 8),
        tile('已回覆', '$responded', AppColors.success),
        const SizedBox(width: 8),
        tile('待回覆', '${total - responded}', AppColors.accent),
      ],
    );
  }
}

/// Circular progress with the percentage in the middle; green when done.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing(this.form);

  final FormItem form;

  @override
  Widget build(BuildContext context) {
    final done = form.totalCount > 0 && form.respondedCount >= form.totalCount;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: form.progress,
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            backgroundColor: AppColors.muted,
            color: done ? AppColors.success : AppColors.primaryDark,
          ),
          Center(
            child: Text(
              '${form.percent}%',
              style: AppText.mono.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.form,
    required this.expanded,
    required this.showList,
    required this.onTap,
  });

  final FormItem form;
  final bool expanded;
  final bool showList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ProgressRing(form),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatDate(form.deadline)} 截止 · '
                    '${form.respondedCount}/${form.totalCount} 人',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (form.status == FormStatus.draft) ...[
              const StatusBadge('草稿', tone: BadgeTone.muted),
              const SizedBox(width: 6),
            ],
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(
          color: expanded ? AppColors.primary : AppColors.border,
          width: expanded ? 1.3 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            summary,
            if (showList) ...[
              const Divider(height: 1, color: AppColors.muted),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: _RecipientList(form, key: ValueKey(form.id)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Side panel with the name list, used on wide screens.
class _RecipientsPanel extends StatelessWidget {
  const _RecipientsPanel({required this.form, required this.onClose});

  final FormItem form;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProgressRing(form),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${formatDate(form.deadline)} 截止',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: '收起',
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RecipientList(form, key: ValueKey(form.id)),
        ],
      ),
    );
  }
}

/// 未回覆 / 已回覆 toggle plus the matching people. Starts on 未回覆,
/// since those are the people you usually need to chase.
class _RecipientList extends StatefulWidget {
  const _RecipientList(this.form, {super.key});

  final FormItem form;

  @override
  State<_RecipientList> createState() => _RecipientListState();
}

class _RecipientListState extends State<_RecipientList> {
  late bool _waiting = widget.form.respondedCount < widget.form.totalCount;

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    if (form.recipients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '這份表單尚未指派收件人',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    final waiting = [
      for (final m in form.recipients)
        if (!form.hasResponded(m)) m,
    ];
    final responded = [
      for (final m in form.recipients)
        if (form.hasResponded(m)) m,
    ];
    final people = _waiting ? waiting : responded;

    Widget toggle(String label, bool forWaiting, Color bg, Color fg) {
      final on = _waiting == forWaiting;
      // Background, border and text color share one timing so nothing
      // flashes; the weight stays fixed so the pill doesn't change width.
      const duration = Duration(milliseconds: 180);
      return GestureDetector(
        onTap: () => setState(() => _waiting = forWaiting),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: on ? bg : bg.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? bg : AppColors.border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: AppText.sans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: on ? fg : AppColors.mutedForeground,
            ),
            child: Text(label),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            toggle(
              '未回覆 ${waiting.length}',
              true,
              AppColors.accentSoft,
              AppColors.accent,
            ),
            const SizedBox(width: 6),
            toggle(
              '已回覆 ${responded.length}',
              false,
              AppColors.successSoft,
              AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                _waiting ? '所有人都回覆了' : '還沒有人回覆',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        for (final m in people) _row(m),
      ],
    );
  }

  Widget _row(Member m) {
    final response = widget.form.responseOf(m);
    return InkWell(
      onTap: response == null
          ? null
          : () => showResponseDialog(context, widget.form, response),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Avatar(m.initials, dimmed: response == null),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: m.name,
                  style: const TextStyle(fontSize: 13),
                  children: [
                    TextSpan(
                      text: ' · ${m.department}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (response == null)
              const Text(
                '未回覆',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              )
            else ...[
              Text(
                formatDateTime(response.submittedAt).substring(5),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 最新回覆: newest first, grouped by day (今天 / 昨天 / date).
class _Timeline extends StatelessWidget {
  const _Timeline(this.forms);

  final List<FormItem> forms;

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    return switch (diff) {
      0 => '今天',
      1 => '昨天',
      _ => formatDate(d),
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final f in forms)
        for (final r in f.responses) (form: f, response: r),
    ]..sort((a, b) => b.response.submittedAt.compareTo(a.response.submittedAt));

    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '尚無回覆',
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    final groups = <String, List<({FormItem form, FormResponse response})>>{};
    for (final row in rows) {
      groups
          .putIfAbsent(_dayLabel(row.response.submittedAt), () => [])
          .add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: day, value: items) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _entry(
              context,
              items[i].form,
              items[i].response,
              last: i == items.length - 1,
            ),
        ],
      ],
    );
  }

  Widget _entry(
    BuildContext context,
    FormItem form,
    FormResponse r, {
    required bool last,
  }) {
    final time = formatDateTime(r.submittedAt).substring(11);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar with a line down to the next entry of the same day.
          Column(
            children: [
              Avatar(r.member.initials, size: 30),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 4 : 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                onTap: () => showResponseDialog(context, form, r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: r.member.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: '  ${r.member.department}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          time,
                          style: AppText.mono.copyWith(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '填寫了「${form.title}」',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showResponseDialog(
  BuildContext context,
  FormItem form,
  FormResponse response,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.base + 4),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Response / 回覆內容'),
                        const SizedBox(height: 8),
                        Text(
                          response.member.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${response.member.department} · '
                          '${formatDateTime(response.submittedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(form.title, style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < form.questions.length; i++)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  NumberChip(i),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      form.questions[i].title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 36),
                                child: Text(
                                  formatAnswer(response.answers[i]),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
