import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form_renderer.dart';
import '../widgets/recipient_picker.dart';
import 'shell.dart';

/// Creates a new form, or edits an existing draft when [draft] is given.
class CreateFormPage extends StatefulWidget {
  const CreateFormPage({super.key, this.draft});

  final FormItem? draft;

  @override
  State<CreateFormPage> createState() => _CreateFormPageState();
}

class _CreateFormPageState extends State<CreateFormPage> {
  int _step = 0;

  // Step 1
  late final _title = TextEditingController(text: widget.draft?.title);
  late final _desc = TextEditingController(text: widget.draft?.description);
  late DateTime _deadline = widget.draft?.deadline ?? DateTime(2026, 10, 20);
  late List<Member> _recipients = widget.draft != null
      ? [...widget.draft!.recipients]
      : AppScope.of(context).members.take(3).toList();
  late bool _wholeCompany =
      widget.draft != null &&
      widget.draft!.recipients.length == AppScope.of(context).members.length;

  /// Who actually receives the form: everyone when 全公司 is chosen.
  List<Member> get _finalRecipients =>
      _wholeCompany ? [...AppScope.of(context).members] : _recipients;
  bool _step1Errors = false;

  // Step 2
  late final List<Question> _questions = widget.draft != null
      ? [for (final q in widget.draft!.questions) q.copy()]
      : [Question()];
  int? _editing = 0;
  bool _step2Errors = false;

  // Step 3 preview answers (interactive, not saved)
  final Answers _previewAnswers = {};

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
        setState(() => _step1Errors = true);
        return;
      }
    } else if (_step == 1) {
      final invalid = _questions.indexWhere(_questionInvalid);
      if (invalid >= 0) {
        setState(() {
          _step2Errors = true;
          _editing = invalid;
        });
        showToast(context, '請完成第 ${invalid + 1} 題的內容');
        return;
      }
    }
    setState(() => _step++);
  }

  bool _questionInvalid(Question q) =>
      q.title.trim().isEmpty ||
      (q.type.hasOptions &&
          q.options.where((o) => o.trim().isNotEmpty).length < 2);

  Future<void> _finish({required bool publish}) async {
    final draft = widget.draft;
    final form = FormItem(
      id: draft?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _desc.text.trim(),
      deadline: _deadline,
      status: publish ? FormStatus.pending : FormStatus.draft,
      questions: [
        for (final q in _questions)
          q.copy()
            ..options = q.type.hasOptions
                ? q.options.where((o) => o.trim().isNotEmpty).toList()
                : []
            ..allowOther = q.type == QuestionType.single && q.allowOther,
      ],
      recipients: [..._finalRecipients],
    );
    final app = AppScope.of(context);
    final saved = await runOrToast(
      context,
      () => app.saveForm(form),
      failure: '儲存失敗，請稍後再試',
    );
    if (!saved || !mounted) return;
    showToast(context, publish ? '表單已發佈' : (draft == null ? '已儲存草稿' : '已更新草稿'));
    ShellNav.of(context).closeSubPage();
  }

  /// Saves what's there so far; only a title is required for a draft.
  void _saveDraft() {
    if (_title.text.trim().isEmpty) {
      setState(() {
        _step = 0;
        _step1Errors = true;
      });
      showToast(context, '請先填寫表單名稱，再儲存草稿');
      return;
    }
    _finish(publish: false);
  }

  static const _stepLabels = ['基本資料與收件人', '設計問題', '預覽與發佈'];
  static const _stepHints = [
    '先從目的開始，再決定要問什麼。你可以隨時儲存草稿，稍後繼續。',
    '收合已完成的題目，只專注編輯目前這一題。',
    '這裡會使用和實際填寫頁相同的表單呈現樣式。',
  ];
  static const _contentWidth = 540.0;

  @override
  Widget build(BuildContext context) {
    final flow = widget.draft == null ? '建立表單' : '編輯草稿';
    return Column(
      children: [
        Expanded(
          child: PageBody(
            bottomPadding: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  eyebrow: '$flow · 步驟 ${_step + 1} / ${_stepLabels.length}',
                  title: _stepLabels[_step],
                  subtitle: _stepHints[_step],
                  icon: BrandGlyph.create,
                  leading: HeaderAction(
                    icon: Icons.close,
                    label: '取消',
                    onPressed: ShellNav.of(context).closeSubPage,
                  ),
                  bottom: _StepSegments(step: _step, count: _stepLabels.length),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _contentWidth),
                    child: switch (_step) {
                      0 => _stepContext(),
                      1 => _stepQuestions(),
                      _ => _stepPreview(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        _actionBar(),
      ],
    );
  }

  /// Fixed bar with the step's two actions, always within thumb reach.
  Widget _actionBar() {
    final tall = OutlinedButton.styleFrom(minimumSize: const Size(0, 40));
    final (Widget secondary, Widget primary) = switch (_step) {
      0 => (
        OutlinedButton.icon(
          style: tall,
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('儲存草稿'),
        ),
        FilledButton.icon(
          onPressed: _next,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('下一步'),
        ),
      ),
      1 => (
        OutlinedButton.icon(
          style: tall,
          onPressed: () => setState(() => _step--),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('上一步'),
        ),
        FilledButton.icon(
          onPressed: _next,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('查看預覽'),
        ),
      ),
      _ => (
        OutlinedButton.icon(
          style: tall,
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('儲存草稿'),
        ),
        FilledButton.icon(
          onPressed: _finalRecipients.isEmpty
              ? null
              : () => _finish(publish: true),
          icon: const Icon(Icons.send_outlined, size: 16),
          label: const Text('立即發佈'),
        ),
      ),
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentWidth),
              child: Row(
                children: [
                  secondary,
                  const SizedBox(width: 10),
                  Expanded(child: primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Step 1 ----------

  Widget _stepContext() {
    final titleError = _step1Errors && _title.text.trim().isEmpty
        ? '請填寫表單名稱'
        : null;
    final descError = _step1Errors && _desc.text.trim().isEmpty
        ? '請補上表單說明'
        : null;
    final wide = isWide(context);

    final deadlineField = _PickerField(
      text: formatDate(_deadline),
      icon: Icons.calendar_today_outlined,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _deadline,
          firstDate: DateTime(2026),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _deadline = picked);
      },
    );

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('表單名稱'),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '例如：2026 Q3 產品策略工作坊回饋',
              error: titleError == null ? null : FieldError(titleError),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('簡短說明'),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '讓填寫的人知道為什麼要回答，以及大約需要多久。',
              error: descError == null ? null : FieldError(descError),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: wide ? 240 : double.infinity,
            child: _labeled('回覆截止日', deadlineField),
          ),
          const SizedBox(height: 16),
          RecipientField(
            allMembers: AppScope.of(context).members,
            selected: _recipients,
            wholeCompany: _wholeCompany,
            onChanged: (whole, selected) => setState(() {
              _wholeCompany = whole;
              _recipients = selected;
            }),
          ),
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [FieldLabel(label), child],
  );

  // ---------- Step 2 ----------

  Widget _stepQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _questions.length; i++) ...[
          _QuestionEditor(
            key: ObjectKey(_questions[i]),
            index: i,
            question: _questions[i],
            expanded: _editing == i,
            showErrors: _step2Errors,
            canDelete: _questions.length > 1,
            onToggle: () => setState(() => _editing = _editing == i ? null : i),
            onDelete: () => setState(() {
              _questions.removeAt(i);
              _editing = null;
            }),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 10),
        ],
        _DashedBox(
          color: AppColors.primary.withValues(alpha: 0.55),
          onTap: () => setState(() {
            _questions.add(Question());
            _editing = _questions.length - 1;
          }),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: AppColors.primaryDeep),
                SizedBox(width: 6),
                Text(
                  '新增問題',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Step 3 ----------

  Widget _stepPreview() {
    final minutes = (_questions.length * 1.2).ceil().clamp(1, 60);

    Widget tile(String label, String value) => Expanded(
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
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            tile('收件人', '${_finalRecipients.length} 人'),
            const SizedBox(width: 8),
            tile('題數', '${_questions.length} 題'),
            const SizedBox(width: 8),
            tile('截止', formatDate(_deadline).substring(5).replaceAll('-', '/')),
          ],
        ),
        if (_finalRecipients.isEmpty) ...[
          const SizedBox(height: 8),
          const FieldError('還沒有收件人，請回到步驟 1 選擇後再發佈。', fontSize: 12),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                '填寫者會看到的樣子',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _step = 1),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDeep,
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('編輯問題'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _DashedBox(
          color: AppColors.input,
          fill: AppColors.card,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormHeading(
                  eyebrow: 'Formfield · Preview',
                  title: _title.text.trim(),
                  description: _desc.text.trim(),
                  minutes: minutes,
                  deadline: _deadline,
                  recipientCount: _finalRecipients.length,
                ),
                const SizedBox(height: 16),
                QuestionList(
                  questions: _questions,
                  answers: _previewAnswers,
                  onChanged: (i, v) => setState(() => _previewAnswers[i] = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Segmented progress bar shown inside the header banner.
class _StepSegments extends StatelessWidget {
  const _StepSegments({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i <= step ? 1 : 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Rounded box with a dashed outline, optionally tappable.
class _DashedBox extends StatelessWidget {
  const _DashedBox({
    required this.color,
    required this.child,
    this.fill,
    this.onTap,
  });

  final Color color;
  final Color? fill;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.base);
    return CustomPaint(
      foregroundPainter: _DashPainter(color),
      child: Material(
        color: fill ?? Colors.transparent,
        borderRadius: radius,
        child: InkWell(borderRadius: radius, onTap: onTap, child: child),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(AppRadius.base),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        decoration: InputDecoration(suffixIcon: Icon(icon, size: 18)),
        child: Text(text, style: const TextStyle(fontSize: AppText.inputSize)),
      ),
    );
  }
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({
    super.key,
    required this.index,
    required this.question,
    required this.expanded,
    required this.showErrors,
    required this.canDelete,
    required this.onToggle,
    required this.onDelete,
    required this.onChanged,
  });

  final int index;
  final Question question;
  final bool expanded;
  final bool showErrors;
  final bool canDelete;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final _title = TextEditingController(text: widget.question.title);
  late final List<TextEditingController> _options = [
    for (final o in widget.question.options) TextEditingController(text: o),
  ];

  Question get q => widget.question;

  @override
  void dispose() {
    _title.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncOptions() {
    q.options = [for (final c in _options) c.text];
    widget.onChanged();
  }

  /// Leading marker that mirrors how the option will look to respondents.
  Widget _optionMarker(int i) => SizedBox(
    width: 22,
    child: switch (q.type) {
      QuestionType.multiple => const Icon(
        Icons.check_box_outline_blank,
        size: 18,
        color: AppColors.input,
      ),
      QuestionType.dropdown => Text(
        '${i + 1}.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
      ),
      _ => const Icon(
        Icons.radio_button_unchecked,
        size: 18,
        color: AppColors.input,
      ),
    },
  );

  @override
  Widget build(BuildContext context) {
    final titleError = widget.showErrors && q.title.trim().isEmpty
        ? '請輸入問題標題'
        : null;
    final optionError =
        widget.showErrors &&
        q.type.hasOptions &&
        q.options.where((o) => o.trim().isNotEmpty).length < 2;
    final hasError = titleError != null || optionError;

    return AppCard(
      padding: const EdgeInsets.all(14),
      highlighted: widget.expanded,
      error: hasError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Row(
              children: [
                NumberChip(widget.index),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.title.trim().isEmpty ? '未命名問題' : q.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Collapsed cards still say what's wrong, not just
                      // turn red.
                      if (hasError && !widget.expanded)
                        const FieldError('此題尚未完成', fontSize: 10)
                      else
                        Text(
                          '${q.type.label} · ${q.required ? '必填' : '選填'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.expanded && widget.canDelete)
                  IconButton(
                    tooltip: '刪除問題',
                    onPressed: widget.onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.destructive,
                    ),
                  ),
                Icon(
                  widget.expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
          if (widget.expanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const FieldLabel('問題標題'),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                hintText: '請輸入問題',
                error: titleError == null ? null : FieldError(titleError),
              ),
              onChanged: (v) {
                q.title = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 14),
            const FieldLabel('題型'),
            _TypePicker(
              value: q.type,
              onChanged: (t) {
                q.type = t;
                if (t.hasOptions && _options.isEmpty) {
                  _options.addAll([
                    TextEditingController(text: '選項一'),
                    TextEditingController(text: '選項二'),
                  ]);
                }
                _syncOptions();
              },
            ),
            const SizedBox(height: 12),
            if (!q.type.hasOptions)
              _TypeHint(q.type)
            else ...[
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 6),
                  child: Row(
                    children: [
                      _optionMarker(i),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _options[i],
                          onChanged: (_) => _syncOptions(),
                          decoration: const InputDecoration(
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          onPressed: () {
                            _options.removeAt(i).dispose();
                            _syncOptions();
                          },
                          icon: const Icon(Icons.close, size: 16),
                        ),
                    ],
                  ),
                ),
              if (optionError)
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 4),
                  child: FieldError('至少需要兩個選項'),
                ),
              if (q.type == QuestionType.single && q.allowOther)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 6),
                  child: Row(
                    children: [
                      _optionMarker(_options.length),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(
                            fillColor: AppColors.muted,
                          ),
                          child: Text(
                            '其他…（填答者可自行輸入）',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '移除「其他」',
                        onPressed: () {
                          q.allowOther = false;
                          widget.onChanged();
                        },
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _options.add(
                        TextEditingController(text: '選項${_options.length + 1}'),
                      );
                      _syncOptions();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增選項'),
                  ),
                  if (q.type == QuestionType.single && !q.allowOther)
                    TextButton(
                      onPressed: () {
                        q.allowOther = true;
                        widget.onChanged();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDeep,
                      ),
                      child: const Text('新增「其他」'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.muted),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '必填',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppSwitch(
                    value: q.required,
                    onChanged: (v) {
                      q.required = v;
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grid of question types (3 per row) instead of a dropdown.
class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.value, required this.onChanged});

  final QuestionType value;
  final ValueChanged<QuestionType> onChanged;

  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    const types = QuestionType.values;
    return Column(
      children: [
        for (var start = 0; start < types.length; start += _perRow) ...[
          if (start > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var i = start; i < start + _perRow; i++) ...[
                if (i > start) const SizedBox(width: 6),
                Expanded(
                  child: i < types.length
                      ? _tile(types[i])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _tile(QuestionType t) {
    final on = t == value;
    final fg = on ? AppColors.primaryDeep : AppColors.mutedForeground;
    return Material(
      color: on ? AppColors.primarySoft : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () => onChanged(t),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: on ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(t.icon, size: 18, color: fg),
              const SizedBox(height: 3),
              Text(
                t.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains what respondents see for types without an option list.
class _TypeHint extends StatelessWidget {
  const _TypeHint(this.type);

  final QuestionType type;

  @override
  Widget build(BuildContext context) {
    final text = switch (type) {
      QuestionType.shortText => '填答者會看到單行文字欄，適合姓名、電話、電子郵件。',
      QuestionType.paragraph => '填答者會看到多行文字框，適合意見回饋或心得。',
      QuestionType.date => '填答者可以從日曆點選，或切換成直接輸入年月日。',
      _ => '',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(type.icon, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
