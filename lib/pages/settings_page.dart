import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppState _app = AppScope.of(context);
  late final _name = TextEditingController(text: _app.displayName);
  late final _email = TextEditingController(text: _app.email);
  late final _dept = TextEditingController(text: _app.department);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _dept.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast(context, '顯示名稱不能空白');
      return;
    }
    final saved = await runOrToast(
      context,
      () => _app.updateProfile(
        name: _name.text.trim(),
        department: _dept.text.trim(),
      ),
      failure: '儲存失敗，請稍後再試',
    );
    if (saved && mounted) showToast(context, '已儲存變更');
  }

  void _toggle(Future<void> Function() action) =>
      runOrToast(context, action, failure: '設定更新失敗，請稍後再試');

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final wide = isWide(context);

    final profileGroup = _SettingsGroup(
      title: '基本資訊',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('顯示名稱'),
            TextField(controller: _name),
            const SizedBox(height: 14),
            const FieldLabel('工作信箱'),
            // The sign-in email; changing it would need a confirmation flow.
            TextField(controller: _email, readOnly: true, enabled: false),
            const SizedBox(height: 14),
            const FieldLabel('工作部門'),
            TextField(controller: _dept),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('儲存變更'),
              ),
            ),
          ],
        ),
      ),
    );

    final otherGroups = [
      _SettingsGroup(
        title: '通知',
        rows: [
          _SettingsRow(
            icon: BrandGlyph.bell,
            tone: _Tone.orange,
            title: '表單提醒',
            subtitle: '有新的指派表單時通知我',
            trailing: AppSwitch(
              value: app.notifyAssigned,
              onChanged: (v) => _toggle(() => app.setNotifyAssigned(v)),
            ),
          ),
          _SettingsRow(
            icon: BrandGlyph.calendar,
            tone: _Tone.blue,
            title: '每週摘要',
            subtitle: '每週一收到工作區進度摘要',
            trailing: AppSwitch(
              value: app.weeklyDigest,
              onChanged: (v) => _toggle(() => app.setWeeklyDigest(v)),
            ),
          ),
        ],
      ),
      _SettingsGroup(
        title: '身份',
        rows: [
          _SettingsRow(
            icon: BrandGlyph.verified,
            tone: _Tone.green,
            title: '目前身份',
            subtitle: app.department,
            trailing: StatusBadge(app.role!.label),
          ),
        ],
      ),
      _SettingsGroup(
        rows: [
          _SettingsRow.centered(
            icon: BrandGlyph.logout,
            title: '登出工作區',
            color: AppColors.destructive,
            onTap: app.logout,
          ),
        ],
      ),
    ];

    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileBanner(app: app),
          const SizedBox(height: 8),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: profileGroup),
                const SizedBox(width: 20),
                Expanded(child: Column(children: otherGroups)),
              ],
            )
          else ...[
            profileGroup,
            ...otherGroups,
          ],
        ],
      ),
    );
  }
}

/// Page banner that shows who is signed in instead of a page title.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final soft = Colors.white.withValues(alpha: 0.85);
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );

    return BrandBanner(
      icon: BrandGlyph.profile,
      padding: wide
          ? const EdgeInsets.fromLTRB(24, 22, 24, 22)
          : const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: wide ? 56 : 48,
                height: wide ? 56 : 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Text(
                  app.initials,
                  style: TextStyle(
                    fontSize: wide ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: wide ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      app.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: soft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip(app.role!.label),
              if (app.department.isNotEmpty) chip(app.department),
            ],
          ),
        ],
      ),
    );
  }
}

/// Titled white group of settings, iOS-style.
///
/// Pass either [rows] (separated by dividers) or a free-form [child].
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({this.title, this.rows, this.child});

  final String? title;
  final List<Widget>? rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
            child: Text(
              title!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: AppColors.border),
          ),
          child:
              child ??
              Column(
                children: [
                  for (var i = 0; i < rows!.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.muted,
                      ),
                    rows![i],
                  ],
                ],
              ),
        ),
      ],
    );
  }
}

enum _Tone { orange, blue, green, gray }

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.trailing,
    this.subtitle,
  }) : centered = false,
       color = null,
       onTap = null;

  /// A single centered action, e.g. 登出.
  const _SettingsRow.centered({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  }) : centered = true,
       tone = _Tone.gray,
       subtitle = null,
       trailing = null;

  final BrandGlyph icon;
  final _Tone tone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool centered;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (centered) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandIcon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final (bg, fg) = switch (tone) {
      _Tone.orange => (AppColors.primarySoft, AppColors.primaryDeep),
      _Tone.blue => (AppColors.accentSoft, AppColors.accent),
      _Tone.green => (AppColors.successSoft, AppColors.success),
      _Tone.gray => (AppColors.muted, AppColors.mutedForeground),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: BrandIcon(icon, size: 18, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing!,
          ],
        ),
      ),
    );
  }
}
