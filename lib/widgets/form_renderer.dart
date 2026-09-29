import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Title block of a form (used on the fill page and in the create preview).
class FormHeading extends StatelessWidget {
  const FormHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.minutes,
    required this.deadline,
    this.recipientCount,
    this.showTitle = true,
  });

  /// False when the page's [PageHeader] already shows the title.
  final bool showTitle;
  final String eyebrow;
  final String title;
  final String description;
  final int minutes;
  final DateTime deadline;
  final int? recipientCount;

  @override
  Widget build(BuildContext context) {
    Widget meta(IconData icon, String text, Color bg, Color fg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
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
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Eyebrow(eyebrow),
          const SizedBox(height: 10),
          Text(
            title.isEmpty ? '未命名表單' : title,
            style: TextStyle(
              fontSize: isWide(context) ? 32 : 26,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            meta(
              Icons.schedule,
              '約 $minutes 分鐘',
              AppColors.muted,
              AppColors.mutedForeground,
            ),
            meta(
              Icons.calendar_today_outlined,
              '${formatDate(deadline)} 截止',
              AppColors.primarySoft,
              AppColors.primaryDeep,
            ),
            if (recipientCount != null)
              meta(
                Icons.group_outlined,
                '$recipientCount 位收件人',
                AppColors.muted,
                AppColors.mutedForeground,
              ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Divider(height: 1),
      ],
    );
  }
}

/// Renders the question cards and collects answers.
class QuestionList extends StatelessWidget {
  const QuestionList({
    super.key,
    required this.questions,
    required this.answers,
    required this.onChanged,
    this.showErrors = false,
    this.questionKeys,
  });

  final List<Question> questions;
  final Answers answers;
  final void Function(int index, Object value) onChanged;
  final bool showErrors;

  /// One key per question card, so a page can scroll to a given question.
  final List<GlobalKey>? questionKeys;

  static bool isAnswered(Object? v) {
    if (v == null) return false;
    if (v is Set) return v.isNotEmpty;
    // Choosing「其他」only counts once something has been typed.
    if (v is OtherAnswer) return v.text.trim().isNotEmpty;
    return v.toString().trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < questions.length; i++) ...[
          _QuestionCard(
            key: questionKeys?[i],
            index: i,
            question: questions[i],
            value: answers[i],
            onChanged: (v) => onChanged(i, v),
            answered: isAnswered(answers[i]),
            error:
                showErrors && questions[i].required && !isAnswered(answers[i]),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.value,
    required this.onChanged,
    required this.answered,
    required this.error,
  });

  final int index;
  final Question question;
  final Object? value;
  final ValueChanged<Object> onChanged;
  final bool answered;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(
          color: error ? AppColors.destructive : AppColors.border,
          width: error ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The number turns into a green check once answered.
              if (answered)
                Container(
                  width: 26,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.success,
                  ),
                )
              else
                NumberChip(index),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  question.title.isEmpty ? '未命名問題' : question.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                question.required ? '必填' : '選填',
                style: TextStyle(
                  fontSize: 11,
                  color: question.required
                      ? AppColors.primaryDeep
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildInput(context),
          if (error)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: FieldError('此題為必填'),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildInput(BuildContext context) {
    const indent = EdgeInsets.only(left: 4);
    switch (question.type) {
      case QuestionType.shortText:
        return [
          Padding(
            padding: indent,
            child: TextFormField(
              initialValue: value as String? ?? '',
              decoration: const InputDecoration(hintText: '簡答文字'),
              onChanged: onChanged,
            ),
          ),
        ];
      case QuestionType.paragraph:
        return [
          Padding(
            padding: indent,
            child: TextFormField(
              initialValue: value as String? ?? '',
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(hintText: '詳答文字'),
              onChanged: onChanged,
            ),
          ),
        ];
      case QuestionType.single:
        return [
          for (final opt in question.options)
            OptionTile(
              label: opt,
              selected: value == opt,
              multiple: false,
              outlined: true,
              onTap: () => onChanged(opt),
            ),
          if (question.allowOther)
            _OtherOption(
              value: value is OtherAnswer ? value as OtherAnswer : null,
              onChanged: onChanged,
            ),
        ];
      case QuestionType.multiple:
        final set = (value as Set<String>?) ?? <String>{};
        return [
          for (final opt in question.options)
            OptionTile(
              label: opt,
              selected: set.contains(opt),
              multiple: true,
              outlined: true,
              onTap: () {
                final next = {...set};
                next.contains(opt) ? next.remove(opt) : next.add(opt);
                onChanged(next);
              },
            ),
        ];
      case QuestionType.dropdown:
        // Options can change while previewing, so drop a stale value.
        final current = question.options.contains(value)
            ? value as String
            : null;
        return [
          Padding(
            padding: indent,
            child: AppDropdownField<String>(
              key: ValueKey(question.options.join('|')),
              value: current,
              hint: '請選擇',
              items: [for (final opt in question.options) (opt, opt)],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ];
      case QuestionType.date:
        return [
          Padding(
            padding: indent,
            child: _DateField(value: value as String?, onChanged: onChanged),
          ),
        ];
    }
  }
}

/// 日期: tap to open the picker; its pencil icon switches to typing the date.
class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<Object> onChanged;

  @override
  Widget build(BuildContext context) {
    final date = value == null ? null : DateTime.tryParse(value!);
    return SizedBox(
      width: 220,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? now,
            firstDate: DateTime(1900),
            lastDate: DateTime(now.year + 20),
            helpText: '選擇日期',
            fieldHintText: 'yyyy/mm/dd',
            fieldLabelText: '輸入日期',
          );
          if (picked != null) onChanged(formatDate(picked));
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            date == null ? '年 / 月 / 日' : formatDate(date),
            style: TextStyle(
              fontSize: AppText.inputSize,
              color: date == null
                  ? AppColors.mutedForeground
                  : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// 選擇題「其他」row: a radio plus an inline text field. Typing selects it.
class _OtherOption extends StatefulWidget {
  const _OtherOption({required this.value, required this.onChanged});

  final OtherAnswer? value;
  final ValueChanged<Object> onChanged;

  @override
  State<_OtherOption> createState() => _OtherOptionState();
}

class _OtherOptionState extends State<_OtherOption> {
  late final _text = TextEditingController(text: widget.value?.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.value != null;
    return OptionTile(
      label: '其他：',
      selected: selected,
      multiple: false,
      outlined: true,
      onTap: () => widget.onChanged(OtherAnswer(_text.text)),
      trailing: Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: TextField(
            controller: _text,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: '請填寫',
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: UnderlineInputBorder(),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (v) => widget.onChanged(OtherAnswer(v)),
          ),
        ),
      ),
    );
  }
}

/// Radio / checkbox row with the demo's minimal indicator style.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.multiple,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
    this.shrinkWrap = false,
    this.outlined = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  /// Size to the label instead of filling the row (for inline trailing fields).
  final bool shrinkWrap;

  /// Bordered, full-width answer row that turns orange when selected; used
  /// by question cards. Ignores [padding].
  final bool outlined;

  /// Placed after the label, e.g. the「其他」text field. Should be [Expanded].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final indicator = AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multiple ? BorderRadius.circular(4) : null,
        // primaryDark keeps the white check and the ring >= 3:1 on white.
        color: selected && multiple ? AppColors.primaryDark : Colors.white,
        border: Border.all(
          color: selected ? AppColors.primaryDark : AppColors.foreground,
          width: 1.4,
        ),
      ),
      child: selected
          ? multiple
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  )
          : null,
    );

    // Outlined rows fade the label to orange on the same timing as the row.
    final Widget text = outlined
        ? AnimatedDefaultTextStyle(
            duration: _duration,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontFamily: AppText.sans,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.primaryDeep : AppColors.foreground,
            ),
            child: Text(label),
          )
        : Text(label, style: const TextStyle(fontSize: 13));
    final row = Row(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        indicator,
        const SizedBox(width: 12),
        if (shrinkWrap || trailing != null) text else Expanded(child: text),
        ?trailing,
      ],
    );

    if (!outlined) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: padding, child: row),
      );
    }

    // Background, border and label animate together; no ink ripple, so the
    // row never flashes gray on top of the orange fill.
    final radius = BorderRadius.circular(AppRadius.sm);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: trailing == null ? 12 : 4,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.card,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: row,
        ),
      ),
    );
  }

  static const _duration = Duration(milliseconds: 180);
}
