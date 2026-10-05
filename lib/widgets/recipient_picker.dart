import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'form_renderer.dart';

/// Groups members by department, keeping first-appearance order.
Map<String, List<Member>> groupByDepartment(List<Member> members) {
  final groups = <String, List<Member>>{};
  for (final m in members) {
    groups.putIfAbsent(m.department, () => []).add(m);
  }
  return groups;
}

/// "發送對象" section on the form page: 全公司 / 指定對象, the selected
/// chips, a "選擇對象" button and the total count.
class RecipientField extends StatelessWidget {
  const RecipientField({
    super.key,
    required this.allMembers,
    required this.selected,
    required this.wholeCompany,
    required this.onChanged,
  });

  final List<Member> allMembers;
  final List<Member> selected;
  final bool wholeCompany;
  final void Function(bool wholeCompany, List<Member> selected) onChanged;

  Future<void> _openSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => RecipientPickerSheet(
        allMembers: allMembers,
        initial: {for (final m in selected) m.id},
      ),
    );
    if (result != null) {
      onChanged(false, allMembers.where((m) => result.contains(m.id)).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    const compact = EdgeInsets.symmetric(vertical: 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('發送對象'),
        OptionTile(
          label: '全公司',
          selected: wholeCompany,
          multiple: false,
          padding: compact,
          onTap: () => onChanged(true, selected),
        ),
        OptionTile(
          label: '指定對象',
          selected: !wholeCompany,
          multiple: false,
          padding: compact,
          onTap: () => onChanged(false, selected),
        ),
        if (!wholeCompany) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selected.isEmpty)
                  const Text(
                    '尚未選擇對象',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  )
                else
                  Wrap(spacing: 6, runSpacing: 6, children: _chips()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openSheet(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('選擇對象'),
                    ),
                    const Spacer(),
                    Text(
                      '共 ${selected.length} 人',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Text(
              '共 ${allMembers.length} 人',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }

  /// A whole department collapses into one chip; otherwise one chip per person.
  List<Widget> _chips() {
    final ids = {for (final m in selected) m.id};
    return [
      for (final entry in groupByDepartment(allMembers).entries)
        if (entry.value.every((m) => ids.contains(m.id)))
          _Chip(
            icon: Icons.group_outlined,
            label: '${entry.key} (${entry.value.length})',
            department: true,
          )
        else
          for (final m in entry.value)
            if (ids.contains(m.id))
              _Chip(icon: Icons.person_outline, label: m.name),
    ];
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.department = false,
  });

  final IconData icon;
  final String label;
  final bool department;

  @override
  Widget build(BuildContext context) {
    final fg = department ? AppColors.primaryDeep : AppColors.foreground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: department ? AppColors.primarySoft : AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: department
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: departments with tri-state checkboxes that expand to show
/// their members. Pops with the selected member ids.
class RecipientPickerSheet extends StatefulWidget {
  const RecipientPickerSheet({
    super.key,
    required this.allMembers,
    required this.initial,
  });

  final List<Member> allMembers;
  final Set<String> initial;

  @override
  State<RecipientPickerSheet> createState() => _RecipientPickerSheetState();
}

class _RecipientPickerSheetState extends State<RecipientPickerSheet> {
  late final Set<String> _selected = {...widget.initial};
  final Set<String> _expanded = {};
  String _query = '';

  late final _groups = groupByDepartment(widget.allMembers);

  void _toggleDepartment(List<Member> members) {
    final all = members.every((m) => _selected.contains(m.id));
    setState(() {
      for (final m in members) {
        all ? _selected.remove(m.id) : _selected.add(m.id);
      }
    });
  }

  void _toggleMember(Member m) => setState(
    () =>
        _selected.contains(m.id) ? _selected.remove(m.id) : _selected.add(m.id),
  );

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final rows = <Widget>[];
    for (final entry in _groups.entries) {
      final dept = entry.key;
      final members = entry.value;
      final deptMatches = q.isEmpty || dept.contains(q);
      final visibleMembers = deptMatches
          ? members
          : members.where((m) => m.name.contains(q)).toList();
      if (visibleMembers.isEmpty) continue;

      // While searching by name, expand departments so matches are visible.
      final expanded =
          _expanded.contains(dept) || (q.isNotEmpty && !deptMatches);
      rows.add(
        _DepartmentRow(
          name: dept,
          members: members,
          selected: _selected,
          expanded: expanded,
          onToggleSelect: () => _toggleDepartment(members),
          onToggleExpand: () => setState(
            () => _expanded.contains(dept)
                ? _expanded.remove(dept)
                : _expanded.add(dept),
          ),
        ),
      );
      if (expanded) {
        for (final m in visibleMembers) {
          rows.add(
            _MemberRow(
              member: m,
              selected: _selected.contains(m.id),
              onTap: () => _toggleMember(m),
            ),
          );
        }
      }
    }

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Text(
                  '選擇對象',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => setState(_selected.clear),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDeep,
                  ),
                  child: const Text('清除'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: '搜尋部門或人員',
                prefixIcon: Icon(Icons.search, size: 18),
                prefixIconConstraints: BoxConstraints(minWidth: 36),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      '找不到符合的部門或人員',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  )
                : ListView(children: rows),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Row(
                children: [
                  Text(
                    '已選 ${_selected.length} 人',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('確定'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentRow extends StatelessWidget {
  const _DepartmentRow({
    required this.name,
    required this.members,
    required this.selected,
    required this.expanded,
    required this.onToggleSelect,
    required this.onToggleExpand,
  });

  final String name;
  final List<Member> members;
  final Set<String> selected;
  final bool expanded;
  final VoidCallback onToggleSelect;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final count = members.where((m) => selected.contains(m.id)).length;
    final all = count == members.length;
    final summary = all
        ? '全部'
        : count > 0
        ? '$count/${members.length} 人'
        : '${members.length} 人';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        onTap: onToggleExpand,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            children: [
              Checkbox(
                tristate: true,
                value: all ? true : (count > 0 ? null : false),
                onChanged: (_) => onToggleSelect(),
              ),
              const Icon(
                Icons.group_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 12,
                  color: count > 0
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sidebar,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(34, 2, 16, 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onTap()),
              Text(member.name, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
