import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../data/form_report.dart';
import '../data/models.dart';
import '../data/paged_feed.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form_renderer.dart';
import '../widgets/recipient_picker.dart';
import '../widgets/response_stats.dart';
import 'shell.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

enum _Tab { progress, timeline, drafts }

class _TrackingPageState extends State<TrackingPage> {
  _Tab _tab = _Tab.progress;
  String _query = '';
  String? _expandedId;

  /// Waits for typing to pause before searching the batched tabs again.
  Timer? _searchDebounce;

  late final AppState _app;

  /// 完成進度 and 最新回覆 grow without end, so they load a batch at a time
  /// as the list scrolls. 草稿 are few and load in one go.
  late final PagedFeed<FormItem> _forms;
  late final PagedFeed<ResponseEntry> _responses;
  bool _started = false;

  /// Forms changed here (新增填寫人員 / 延長截止日 / 結案) since their batch
  /// loaded; shown instead of the loaded copy until the list reloads.
  final _updated = <String, FormItem>{};

  /// Null until loaded.
  List<FormItem>? _drafts;
  ProgressSummary? _summary;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _app = AppScope.of(context);
    _forms = PagedFeed<FormItem>(
      (offset) => _app.fetchPublishedForms(query: _query, offset: offset),
    )..addListener(_onFeedChanged);
    _responses = PagedFeed<ResponseEntry>(
      (offset) => _app.fetchResponses(query: _query, offset: offset),
    )..addListener(_onFeedChanged);
    _reloadFeeds();
    _loadSummaryAndDrafts().catchError((Object e) {
      debugPrint('Could not load summary or drafts: $e');
    });
  }

  void _onFeedChanged() => setState(() {});

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _forms.dispose();
    _responses.dispose();
    super.dispose();
  }

  Future<void> _reloadFeeds() {
    _updated.clear();
    return Future.wait([_forms.reload(), _responses.reload()]);
  }

  Future<void> _loadSummaryAndDrafts() async {
    final (summary, drafts) = await (
      _app.fetchProgressSummary(),
      _app.fetchDrafts(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _drafts = drafts;
    });
  }

  /// Pull-to-refresh. A failed batch shows its own retry button, so only
  /// the rest toasts on failure.
  Future<void> _refresh() async {
    final feeds = _reloadFeeds();
    await runOrToast(
      context,
      () => (_loadSummaryAndDrafts(), _app.refreshMembers()).wait,
    );
    await feeds;
  }

  void _onQueryChanged(String v) {
    setState(() => _query = v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _reloadFeeds);
  }

  /// [form] changed on this page; the totals change with it.
  void _onFormChanged(FormItem form) {
    setState(() => _updated[form.id] = form);
    _app
        .fetchProgressSummary()
        .then((s) {
          if (mounted) setState(() => _summary = s);
        })
        .catchError((Object e) {
          debugPrint('Could not reload summary: $e');
        });
  }

  void _onDraftDeleted(FormItem form) =>
      setState(() => _drafts?.removeWhere((f) => f.id == form.id));

  @override
  Widget build(BuildContext context) {
    final nav = ShellNav.of(context);
    final wide = isWide(context);
    // Drafts have no replies yet, so they only show up under 草稿, filtered
    // here since they are all loaded.
    final drafts = _drafts
        ?.where((f) => f.title.contains(_query.trim()))
        .toList();

    return ListPageBody(
      onNearEnd: switch (_tab) {
        _Tab.progress => _forms.loadMore,
        _Tab.timeline => _responses.loadMore,
        _Tab.drafts => null,
      },
      onRefresh: _refresh,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: '表單管理',
            title: '把重要的事，問清楚',
            subtitle: '建立與編輯表單；點選一份表單查看已回覆與未回覆名單，再點選已回覆的人即可查看答案。',
            icon: BrandGlyph.tracking,
            // Narrow screens use the shell's floating button instead.
            action: wide
                ? HeaderAction(
                    icon: Icons.add,
                    label: '建立新表單',
                    onPressed: nav.openCreate,
                  )
                : null,
          ),
          const SizedBox(height: 12),
          // Totals across every published form, whatever the search and
          // however much of the list has loaded.
          _StatTiles(_summary),
          const SizedBox(height: 16),
          TabsWithSearch(
            tabs: SegmentedTabs(
              labels: const ['完成進度', '最新回覆', '草稿'],
              selected: _tab.index,
              onChanged: (i) => setState(() => _tab = _Tab.values[i]),
            ),
            onQueryChanged: _onQueryChanged,
          ),
        ],
      ),
      list: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (_tab) {
            _Tab.progress => _progressView(),
            _Tab.timeline => _Timeline(_responses),
            _Tab.drafts =>
              drafts == null
                  ? const SizedBox.shrink()
                  : _DraftList(drafts, onDeleted: _onDraftDeleted),
          },
          // Keep the last card clear of the floating 建立表單 button.
          if (!wide) const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _progressView() {
    final forms = [for (final f in _forms.items) _updated[f.id] ?? f];
    if (forms.isEmpty && !_forms.hasMore && _forms.error == null) {
      return const _EmptyNote('這裡目前沒有表單');
    }
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
            onChanged: _onFormChanged,
          ),
          const SizedBox(height: 10),
        ],
        PagedFeedFooter(_forms, endText: '已經沒有更多表單了'),
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
                  onChanged: _onFormChanged,
                ),
        ),
      ],
    );
  }
}

/// Gray note for a list with nothing in it.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
        ),
      ),
    );
  }
}

/// 整體回覆率 / 已回覆 / 待回覆 across every published form; dashes until
/// the totals arrive.
class _StatTiles extends StatelessWidget {
  const _StatTiles(this.summary);

  final ProgressSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    String show(Object? v) => v == null ? '–' : '$v';

    Widget tile(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.mutedForeground,
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
        tile(
          '整體回覆率',
          s == null ? '–' : '${s.percent}%',
          context.colors.foreground,
        ),
        const SizedBox(width: 8),
        tile('已回覆', show(s?.responded), context.colors.success),
        const SizedBox(width: 8),
        tile('待回覆', show(s?.waiting), context.colors.accent),
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
            backgroundColor: context.colors.muted,
            color: done ? context.colors.success : context.colors.primaryDark,
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

/// 已結案, or 已截止 while people still haven't replied; null otherwise.
StatusBadge? _closedBadge(FormItem form) {
  if (form.status == FormStatus.closed) {
    return StatusBadge.forStatus(FormStatus.closed);
  }
  if (form.status == FormStatus.pending && form.isPastDeadline) {
    return const StatusBadge('已截止', tone: BadgeTone.destructive);
  }
  return null;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.form,
    required this.expanded,
    required this.showList,
    required this.onTap,
    required this.onChanged,
  });

  final FormItem form;
  final bool expanded;
  final bool showList;
  final VoidCallback onTap;
  final ValueChanged<FormItem> onChanged;

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
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (_closedBadge(form) case final badge?) ...[
              badge,
              const SizedBox(width: 6),
            ],
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: context.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(
          color: expanded ? context.colors.primary : context.colors.border,
          width: expanded ? 1.3 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            summary,
            if (showList) ...[
              Divider(height: 1, color: context.colors.muted),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: _RecipientList(
                  form,
                  onChanged: onChanged,
                  key: ValueKey(form.id),
                ),
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
  const _RecipientsPanel({
    required this.form,
    required this.onClose,
    required this.onChanged,
  });

  final FormItem form;
  final VoidCallback onClose;
  final ValueChanged<FormItem> onChanged;

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
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.mutedForeground,
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
          _RecipientList(form, onChanged: onChanged, key: ValueKey(form.id)),
        ],
      ),
    );
  }
}

enum _View { waiting, responded, stats }

/// 未回覆 / 已回覆 / 統計 toggle plus the matching people or the per-question
/// stats. Starts on 未回覆, since those are the people you usually need to
/// chase.
class _RecipientList extends StatefulWidget {
  const _RecipientList(this.form, {required this.onChanged, super.key});

  final FormItem form;

  /// Gets the form back from the backend after it was changed here.
  final ValueChanged<FormItem> onChanged;

  @override
  State<_RecipientList> createState() => _RecipientListState();
}

class _RecipientListState extends State<_RecipientList> {
  late _View _view = widget.form.respondedCount < widget.form.totalCount
      ? _View.waiting
      : _View.responded;

  /// Hands the replies to the share sheet as a CSV (a download on the web).
  /// [button] anchors the sheet's popover on iPad and macOS.
  Future<void> _exportCsv(BuildContext button) async {
    final form = widget.form;
    final box = button.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final name = csvFileName(form);
    await runOrToast(
      context,
      () => SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(formToCsv(form)),
              name: name,
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [name],
          subject: form.title,
          sharePositionOrigin: origin,
        ),
      ),
      failure: '匯出失敗，請稍後再試',
    );
  }

  /// Runs a change to the form and hands the updated form to the page;
  /// false (after a toast) when it failed.
  Future<bool> _update(
    Future<FormItem> Function() change, {
    required String failure,
  }) async {
    final ok = await runOrToast(
      context,
      () async => widget.onChanged(await change()),
      failure: failure,
    );
    return ok;
  }

  /// Picks people who aren't recipients yet and adds them to the form.
  Future<void> _addRecipients() async {
    final app = AppScope.of(context);
    final form = widget.form;
    final picked = await showRecipientPicker(
      context,
      allMembers: [
        for (final m in app.members)
          if (!form.recipients.contains(m)) m,
      ],
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final added = await _update(
      () => app.addRecipients(form, picked),
      failure: '新增失敗，請稍後再試',
    );
    if (!added || !mounted) return;
    setState(() => _view = _View.waiting);
    showToast(context, '已新增 ${picked.length} 位填寫人員');
  }

  /// Picks a later deadline; reopens the form if the old one had passed.
  Future<void> _extendDeadline() async {
    final app = AppScope.of(context);
    final form = widget.form;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayAfter = form.deadline.add(const Duration(days: 1));
    final earliest = dayAfter.isAfter(today) ? dayAfter : today;
    final picked = await showDatePicker(
      context: context,
      helpText: '延長截止日',
      initialDate: earliest,
      firstDate: earliest,
      lastDate: DateTime(earliest.year + 3, 12, 31),
    );
    if (picked == null || !mounted) return;
    final saved = await _update(
      () => app.extendDeadline(form, picked),
      failure: '延長失敗，請稍後再試',
    );
    if (saved && mounted) {
      showToast(context, '截止日已延到 ${formatDate(picked)}');
    }
  }

  /// 結案 after confirming; it can't be undone.
  Future<void> _close() async {
    final form = widget.form;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: const Text('結案這份表單？', style: TextStyle(fontSize: 18)),
        content: Text(
          '「${form.title}」結案後就不能再填寫或修改回覆，'
          '也無法延長截止日或新增填寫人員。這個動作無法復原。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('結案'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final app = AppScope.of(context);
    final closed = await _update(
      () => app.closeForm(form),
      failure: '結案失敗，請稍後再試',
    );
    if (closed && mounted) showToast(context, '已結案');
  }

  /// What an admin can still do with this form: add people until the
  /// deadline, extend it while replies are missing, close it once published,
  /// and export the replies once there are any.
  Widget? _actions() {
    final form = widget.form;
    final app = AppScope.of(context);
    Widget action(
      IconData icon,
      String label,
      void Function(BuildContext button) onPressed,
    ) => Builder(
      builder: (button) => TextButton.icon(
        onPressed: () => onPressed(button),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
    final actions = [
      if (form.isOpen && !app.members.every(form.recipients.contains))
        action(Icons.person_add_alt, '新增填寫人員', (_) => _addRecipients()),
      if (form.canExtendDeadline)
        action(Icons.event_outlined, '延長截止日', (_) => _extendDeadline()),
      if (form.isPublished) action(Icons.lock_outline, '結案', (_) => _close()),
      if (form.responses.isNotEmpty)
        action(Icons.file_download_outlined, '匯出 CSV', _exportCsv),
    ];
    if (actions.isEmpty) return null;
    return Wrap(spacing: 4, runSpacing: 4, children: actions);
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final actions = _actions();
    if (form.recipients.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?actions,
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '這份表單尚未指派收件人',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
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
    final people = _view == _View.waiting ? waiting : responded;

    Widget toggle(String label, _View view, Color bg, Color fg) {
      final on = _view == view;
      // Background, border and text color share one timing so nothing
      // flashes; the weight stays fixed so the pill doesn't change width.
      const duration = Duration(milliseconds: 180);
      return GestureDetector(
        onTap: () => setState(() => _view = view),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: on ? bg : bg.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? bg : context.colors.border),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: AppText.sans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: on ? fg : context.colors.mutedForeground,
            ),
            child: Text(label),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (actions != null) ...[
          actions,
          Divider(height: 16, color: context.colors.muted),
        ],
        Row(
          children: [
            toggle(
              '未回覆 ${waiting.length}',
              _View.waiting,
              context.colors.accentSoft,
              context.colors.accent,
            ),
            const SizedBox(width: 6),
            toggle(
              '已回覆 ${responded.length}',
              _View.responded,
              context.colors.successSoft,
              context.colors.success,
            ),
            const SizedBox(width: 6),
            toggle(
              '統計',
              _View.stats,
              context.colors.primarySoft,
              context.colors.primaryDeep,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_view == _View.stats)
          ResponseStats(widget.form)
        else ...[
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _view == _View.waiting ? '所有人都回覆了' : '還沒有人回覆',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.mutedForeground,
                  ),
                ),
              ),
            ),
          for (final m in people) _row(m),
        ],
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
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (response == null)
              Text(
                '未回覆',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.mutedForeground,
                ),
              )
            else ...[
              Text(
                formatDateTime(response.submittedAt).substring(5),
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.mutedForeground,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.mutedForeground,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 草稿: unpublished forms. Tap one to keep editing it.
class _DraftList extends StatelessWidget {
  const _DraftList(this.drafts, {required this.onDeleted});

  final List<FormItem> drafts;
  final ValueChanged<FormItem> onDeleted;

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) return const _EmptyNote('目前沒有草稿');

    final nav = ShellNav.of(context);
    return Column(
      children: [
        for (final form in drafts) ...[
          AppCard(
            onTap: () => nav.openEdit(form),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
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
                        '${form.questions.length} 題 · '
                        '${form.totalCount} 人',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const StatusBadge('草稿', tone: BadgeTone.muted),
                IconButton(
                  tooltip: '刪除',
                  onPressed: () => _confirmDelete(context, form),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: context.colors.destructive,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, FormItem form) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: const Text('刪除表單？', style: TextStyle(fontSize: 18)),
        content: Text('「${form.title}」會被移除，這個動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final app = AppScope.of(context);
    final deleted = await runOrToast(
      context,
      () => app.deleteForm(form),
      failure: '刪除失敗，請稍後再試',
    );
    if (!deleted || !context.mounted) return;
    onDeleted(form);
    showToast(context, '已刪除表單');
  }
}

/// 最新回覆: every reply across the forms, newest first, grouped by day
/// (今天 / 昨天 / date). Loads a batch at a time as the list scrolls.
class _Timeline extends StatelessWidget {
  const _Timeline(this.feed);

  final PagedFeed<ResponseEntry> feed;

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
    final rows = feed.items;
    if (rows.isEmpty && !feed.hasMore && feed.error == null) {
      return const _EmptyNote('尚無回覆');
    }

    // Batches arrive newest first, so a day split across two batches still
    // lands in one group.
    final groups = <String, List<ResponseEntry>>{};
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.mutedForeground,
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
        PagedFeedFooter(feed, endText: '已經沒有更多回覆了'),
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
                    color: context.colors.border,
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: context.colors.mutedForeground,
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
                            color: context.colors.mutedForeground,
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
      backgroundColor: context.colors.card,
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
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.mutedForeground,
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
                  color: context.colors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(form.title, style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: AnswerList(
                    questions: form.questions,
                    answers: response.answers,
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
