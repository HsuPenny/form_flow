import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/paged_feed.dart';
import '../data/models.dart';
import '../data/repositories/form_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

/// 待完成 / 已完成 / 已截止. Each asks the backend for its own forms, a
/// batch at a time as the list scrolls; see [FormCategory].
enum _Tab { pending, completed, expired }

class _OverviewPageState extends State<OverviewPage> {
  _Tab _tab = _Tab.pending;
  String _query = '';

  /// Waits for typing to pause before searching the batched tabs again.
  Timer? _searchDebounce;

  late final AppState _app;
  late final Map<_Tab, PagedFeed<FormItem>> _feeds;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _app = AppScope.of(context);
    PagedFeed<FormItem> feed(FormCategory kind) => PagedFeed<FormItem>(
      (offset) => _app.fetchMyForms(kind, query: _query, offset: offset),
    )..addListener(_onFeedChanged);
    _feeds = {
      _Tab.pending: feed(FormCategory.pending),
      _Tab.completed: feed(FormCategory.completed),
      _Tab.expired: feed(FormCategory.expired),
    };
    // All up front, so every tab shows a count.
    for (final f in _feeds.values) {
      f.reload();
    }
  }

  void _onFeedChanged() => setState(() {});

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (final f in _feeds.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _reloadFeeds);
  }

  Future<void> _reloadFeeds() =>
      Future.wait([for (final f in _feeds.values) f.reload()]);

  /// Pull-to-refresh: keeps the lists on screen while they reload.
  Future<void> _refreshFeeds() =>
      Future.wait([for (final f in _feeds.values) f.refresh()]);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nav = ShellNav.of(context);

    // Everyone, admins included, sees the published forms assigned to them,
    // filed by their own reply. Drafts and form-wide progress live in 表單管理.
    final me = app.me;
    final feed = _feeds[_tab]!;
    final forms = feed.items;

    final cards = Column(
      children: [
        for (final form in forms) ...[
          _FormCard(
            form: form,
            status: form.statusFor(me),
            expired: _tab == _Tab.expired,
            onView: () => nav.openForm(form),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );

    return ListPageBody(
      onNearEnd: feed.loadMore,
      // A failed batch shows its own retry button, so no toast here.
      onRefresh: _refreshFeeds,
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
              labels: const ['待完成', '已完成', '已截止'],
              counts: [for (final t in _Tab.values) _feeds[t]!.total ?? 0],
              selected: _tab.index,
              onChanged: (i) => setState(() => _tab = _Tab.values[i]),
            ),
            onQueryChanged: _onQueryChanged,
          ),
        ],
      ),
      list: forms.isEmpty && !feed.hasMore && feed.error == null
          ? const _EmptyState()
          : Column(
              children: [
                cards,
                PagedFeedFooter(feed, endText: '已經沒有更多表單了'),
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
    this.expired = false,
  });

  final FormItem form;

  /// [FormItem.status] as the viewer sees it; see [FormItem.statusFor].
  final FormStatus status;

  /// Never answered and no longer taking replies; see [FormItem.isExpiredFor].
  final bool expired;
  final VoidCallback onView;

  /// 已結案 in gray when an admin closed it, otherwise 已截止 in red.
  StatusBadge _badge() {
    if (!expired) return StatusBadge.forStatus(status);
    return form.status == FormStatus.closed
        ? StatusBadge.forStatus(FormStatus.closed)
        : const StatusBadge('已截止', tone: BadgeTone.destructive);
  }

  /// "剩 N 天" for open forms (orange when due within 3 days), otherwise
  /// the deadline date in gray.
  (String, bool urgent) _deadlineLabel() {
    final date = formatDate(form.deadline).substring(5).replaceAll('-', '/');
    if (expired) {
      return form.status == FormStatus.closed
          ? ('已結案・未回覆', false)
          : ('$date 截止・未回覆', false);
    }
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      // Faded: nothing left to do here.
                      color: expired ? context.colors.mutedForeground : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(height: 28, child: Center(child: _badge())),
            ],
          ),
          if (form.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              form.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: expired ? Icons.lock_outline : Icons.schedule,
                text: deadline,
                highlighted: urgent,
              ),
              if (!expired)
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
    final fg = highlighted
        ? context.colors.primaryDeep
        : context.colors.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted ? context.colors.primarySoft : context.colors.muted,
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
    return AppCard(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: context.colors.mutedForeground),
            SizedBox(height: 8),
            Text(
              '這裡目前沒有表單',
              style: TextStyle(
                color: context.colors.mutedForeground,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
