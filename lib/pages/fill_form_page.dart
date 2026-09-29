import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form_renderer.dart';
import 'shell.dart';

class FillFormPage extends StatefulWidget {
  const FillFormPage({super.key, required this.form});

  final FormItem form;

  @override
  State<FillFormPage> createState() => _FillFormPageState();
}

class _FillFormPageState extends State<FillFormPage> {
  final Answers _answers = {};
  bool _showErrors = false;
  bool _submitted = false;
  late final _questionKeys = [
    for (final _ in widget.form.questions) GlobalKey(),
  ];

  List<int> get _missingRequired {
    final questions = widget.form.questions;
    return [
      for (var i = 0; i < questions.length; i++)
        if (questions[i].required && !QuestionList.isAnswered(_answers[i])) i,
    ];
  }

  int get _answeredCount => [
    for (var i = 0; i < widget.form.questions.length; i++)
      if (QuestionList.isAnswered(_answers[i])) i,
  ].length;

  void _submit() {
    final missing = _missingRequired;
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      showToast(context, '還有 ${missing.length} 題必填尚未回答');
      // Bring the first unanswered required question into view.
      final target = _questionKeys[missing.first].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    AppScope.of(context).submitResponse(widget.form, Map.of(_answers));
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _Done(form: widget.form);

    final form = widget.form;
    final total = form.questions.length;
    final answered = _answeredCount;
    return Column(
      children: [
        Expanded(
          child: PageBody(
            maxWidth: 680,
            bottomPadding: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  eyebrow: '已回答 $answered / $total 題',
                  title: form.title,
                  icon: BrandGlyph.fill,
                  leading: HeaderAction(
                    icon: Icons.arrow_back,
                    label: '回到表單總覽',
                    onPressed: ShellNav.of(context).closeSubPage,
                  ),
                  bottom: _BannerProgress(total == 0 ? 0 : answered / total),
                ),
                const SizedBox(height: 16),
                FormHeading(
                  showTitle: false,
                  eyebrow: 'Formfield · Assigned form',
                  title: form.title,
                  description: form.description,
                  minutes: form.estimatedMinutes,
                  deadline: form.deadline,
                ),
                const SizedBox(height: 20),
                QuestionList(
                  questions: form.questions,
                  answers: _answers,
                  showErrors: _showErrors,
                  questionKeys: _questionKeys,
                  onChanged: (i, v) => setState(() => _answers[i] = v),
                ),
              ],
            ),
          ),
        ),
        _submitBar(),
      ],
    );
  }

  /// Fixed bar: how many required questions are left, plus 送出回覆.
  Widget _submitBar() {
    final left = _missingRequired.length;
    // Neutral hint until a submit attempt fails, then it matches the red cards.
    final status = left == 0
        ? AppColors.success
        : _showErrors
        ? AppColors.destructive
        : AppColors.mutedForeground;
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
              constraints: const BoxConstraints(maxWidth: 680),
              child: Row(
                children: [
                  Icon(
                    left == 0
                        ? Icons.check_circle_outline
                        : _showErrors
                        ? Icons.error_outline
                        : Icons.info_outline,
                    size: 16,
                    color: status,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    left == 0 ? '可以送出了' : '還有 $left 題必填',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('送出回覆'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White progress line inside the header banner.
class _BannerProgress extends StatelessWidget {
  const _BannerProgress(this.value);

  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 4,
          backgroundColor: Colors.white.withValues(alpha: 0.35),
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Thank-you screen shown after submitting, with the next form to fill.
class _Done extends StatelessWidget {
  const _Done({required this.form});

  final FormItem form;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nav = ShellNav.of(context);
    final me = Member(app.displayName, app.department);
    final todo =
        app.forms
            .where(
              (f) =>
                  f != form &&
                  f.status == FormStatus.pending &&
                  !f.hasResponded(me),
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    final next = todo.isEmpty ? null : todo.first;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successSoft,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '已送出，謝謝你的回覆',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '「${form.title}」\n已送出 ${form.questions.length} 題回答',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.mutedForeground,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 22),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => nav.openForm(next),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '還有 ${todo.length} 份待填寫',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              next.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${formatDate(next.deadline).substring(5).replaceAll('-', '/')} 截止',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: nav.closeSubPage,
                      child: const Text('回到總覽'),
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => nav.openForm(next),
                        child: const Text('填下一份'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
