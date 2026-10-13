import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  int _filter = 0; // index into the tabs built in [build]
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nav = ShellNav.of(context);

    // Everyone, admins included, sees the published forms assigned to them,
    // filed by their own reply. Drafts and form-wide progress live in 表單管理.
    final me = app.me;
    FormStatus statusOf(FormItem f) => f.statusFor(me);
    final visible = app.forms
        .where(
          (f) => f.status != FormStatus.draft && f.recipients.contains(me),
        )
        .toList();
    final completed = visible
        .where((f) => statusOf(f) == FormStatus.completed)
        .toList();
    final pending = visible
        .where((f) => statusOf(f) == FormStatus.pending)
        .toList();

    final tabs = <(String, List<FormItem>)>[
      ('全部', visible),
      ('待完成', pending),
      ('已完成', completed),
    ];
    final filtered = tabs[_filter].$2
        .where((f) => f.title.contains(_query.trim()))
        .toList();

    return ListPageBody(
      onRefresh: () => runOrToast(context, app.refreshForms),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            eyebrow: '表單總覽',
            title: '今天要回覆的表單',
            subtitle: '完成指派給你的表單，讓團隊知道你的想法。',
            icon: BrandGlyph.forms,
          ),
          const SizedBox(height: 20),
          TabsWithSearch(
            tabs: SegmentedTabs(
              labels: [for (final t in tabs) t.$1],
              counts: [for (final t in tabs) t.$2.length],
              selected: _filter,
              onChanged: (i) => setState(() => _filter = i),
            ),
            onQueryChanged: (v) => setState(() => _query = v),
          ),
        ],
      ),
      list: filtered.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                for (final form in filtered) ...[
                  _FormCard(
                    form: form,
                    status: statusOf(form),
                    onView: () => nav.openForm(form),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.form,
    required this.status,
    required this.onView,
  });

  final FormItem form;

  /// [FormItem.status] as the viewer sees it; see [FormItem.statusFor].
  final FormStatus status;
  final VoidCallback onView;

  /// "剩 N 天" for open forms (orange when due within 3 days), otherwise
  /// the deadline date in gray.
  (String, bool urgent) _deadlineLabel() {
    final date = formatDate(form.deadline).substring(5).replaceAll('-', '/');
    if (status != FormStatus.pending) return ('$date 截止', false);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      form.deadline.year,
      form.deadline.month,
      form.deadline.day,
    );
    final days = due.difference(today).inDays;
    return switch (days) {
      < 0 => ('已截止', false),
      0 => ('今天截止', true),
      _ => ('剩 $days 天', days <= 3),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (deadline, urgent) = _deadlineLabel();

    return AppCard(
      onTap: onView,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  // Centers the first title line on the 28px badge row.
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 28,
                child: Center(child: StatusBadge.forStatus(status)),
              ),
            ],
          ),
          if (form.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              form.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.schedule,
                text: deadline,
                highlighted: urgent,
              ),
              _MetaChip(
                icon: Icons.timer_outlined,
                text: '約 ${form.estimatedMinutes} 分鐘',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  final IconData icon;
  final String text;

  /// Orange instead of gray, e.g. for a deadline that's close.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.primaryDeep : AppColors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primarySoft : AppColors.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.mutedForeground),
            SizedBox(height: 8),
            Text(
              '這裡目前沒有表單',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
