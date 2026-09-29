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
  final _search = TextEditingController();
  bool _searchOpen = false; // narrow screens only

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nav = ShellNav.of(context);
    final wide = isWide(context);

    // Members only see forms that have been published.
    final visible = app.isAdmin
        ? app.forms
        : app.forms.where((f) => f.status != FormStatus.draft).toList();
    final completed = visible
        .where((f) => f.status == FormStatus.completed)
        .toList();
    final pending = visible
        .where((f) => f.status == FormStatus.pending)
        .toList();
    final drafts = visible.where((f) => f.status == FormStatus.draft).toList();

    // Only admins can see drafts, so only they get the 草稿 tab.
    final tabs = <(String, List<FormItem>)>[
      ('全部', visible),
      ('待完成', pending),
      ('已完成', completed),
      if (app.isAdmin) ('草稿', drafts),
    ];
    if (_filter >= tabs.length) _filter = 0;
    final filtered = tabs[_filter].$2
        .where((f) => f.title.contains(_query.trim()))
        .toList();

    final search = SizedBox(
      width: wide ? 240 : double.infinity,
      child: TextField(
        controller: _search,
        autofocus: !wide,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: '搜尋表單名稱',
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.search, size: 18),
          prefixIconConstraints: BoxConstraints(minWidth: 36),
        ),
      ),
    );
    // Narrow screens tuck search behind an icon next to the tabs.
    final searchToggle = Material(
      color: _searchOpen ? AppColors.primarySoft : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => setState(() {
          _searchOpen = !_searchOpen;
          if (!_searchOpen) {
            _search.clear();
            _query = '';
          }
        }),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: _searchOpen ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Icon(
            _searchOpen ? Icons.close : Icons.search,
            size: 18,
            color: _searchOpen ? AppColors.primaryDeep : AppColors.foreground,
          ),
        ),
      ),
    );
    final tabBar = SegmentedTabs(
      labels: [for (final t in tabs) t.$1],
      counts: [for (final t in tabs) t.$2.length],
      selected: _filter,
      onChanged: (i) => setState(() => _filter = i),
    );

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: app.isAdmin ? '表單管理' : '表單總覽',
            title: app.isAdmin ? '把重要的事，問清楚' : '今天要回覆的表單',
            subtitle: app.isAdmin
                ? '建立清楚的提問，收回有脈絡的回覆。'
                : '完成指派給你的表單，讓團隊知道你的想法。',
            icon: BrandGlyph.forms,
            // Narrow screens use the shell's floating button instead.
            action: app.isAdmin && wide
                ? HeaderAction(
                    icon: Icons.add,
                    label: '建立新表單',
                    onPressed: nav.openCreate,
                  )
                : null,
          ),
          const SizedBox(height: 20),
          if (wide)
            Row(children: [tabBar, const Spacer(), search])
          else ...[
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabBar,
                  ),
                ),
                const SizedBox(width: 8),
                searchToggle,
              ],
            ),
            if (_searchOpen) ...[const SizedBox(height: 10), search],
          ],
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const _EmptyState()
          else
            for (final form in filtered) ...[
              _FormCard(
                form: form,
                isAdmin: app.isAdmin,
                onView: () => form.status == FormStatus.draft
                    ? nav.openEdit(form)
                    : nav.openForm(form),
                onDelete: () => _confirmDelete(form),
              ),
              const SizedBox(height: 12),
            ],
          // Keep the last card clear of the floating 建立表單 button.
          if (app.isAdmin && !wide) const SizedBox(height: 64),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(FormItem form) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('刪除表單？', style: TextStyle(fontSize: 18)),
        content: Text('「${form.title}」會被移除，這個動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      AppScope.of(context).deleteForm(form);
      showToast(context, '已刪除表單');
    }
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.form,
    required this.isAdmin,
    required this.onView,
    required this.onDelete,
  });

  final FormItem form;
  final bool isAdmin;
  final VoidCallback onView;
  final VoidCallback onDelete;

  /// "剩 N 天" for open forms (orange when due within 3 days), otherwise
  /// the deadline date in gray.
  (String, bool urgent) _deadlineLabel() {
    final date = formatDate(form.deadline).substring(5).replaceAll('-', '/');
    if (form.status != FormStatus.pending) return ('$date 截止', false);
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
    // Admins track replies; members care about how long filling takes.
    final showProgress = isAdmin && form.status != FormStatus.draft;

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
                  // Centers the first title line on the 28px trailing group.
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
              // Fixed height so the badge and delete icon share one center
              // line whether or not the delete button is shown.
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    StatusBadge.forForm(form),
                    if (isAdmin && form.status == FormStatus.draft) ...[
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: '刪除',
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.destructive,
                        ),
                      ),
                    ],
                  ],
                ),
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
          if (showProgress) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ProgressLine(form.progress)),
                const SizedBox(width: 10),
                Text(
                  '${form.percent}%',
                  style: AppText.mono.copyWith(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
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
              if (isAdmin)
                _MetaChip(
                  icon: Icons.format_list_numbered,
                  text: '${form.questions.length} 題',
                )
              else
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
