import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../data/repositories/auth_repository.dart';
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

  /// Only admins can pick a department; members see theirs read-only.
  late String _dept = _app.department;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
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
        department: _app.isAdmin ? _dept : _app.department,
      ),
      failure: '儲存失敗，請稍後再試',
    );
    if (saved && mounted) showToast(context, '已儲存變更');
  }

  void _toggle(Future<void> Function() action) =>
      runOrToast(context, action, failure: '設定更新失敗，請稍後再試');

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) showToast(context, '密碼已更新');
  }

  Widget _departmentField(AppState app) {
    if (!app.isAdmin) {
      return TextFormField(
        initialValue: app.department.isEmpty ? '未設定' : app.department,
        readOnly: true,
        enabled: false,
        decoration: const InputDecoration(helperText: '部門由管理員設定'),
      );
    }
    final options = app.departments;
    return AppDropdownField<String>(
      // A department removed from the list shows as unselected.
      value: options.contains(_dept) ? _dept : null,
      hint: options.isEmpty ? '無法載入部門清單' : '請選擇部門',
      items: [for (final d in options) (d, d)],
      onChanged: (v) {
        if (v != null) setState(() => _dept = v);
      },
    );
  }

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
            _departmentField(app),
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
        title: '帳號安全',
        rows: [
          _SettingsRow(
            icon: BrandGlyph.lock,
            tone: _Tone.gray,
            title: '修改密碼',
            subtitle: '更新登入用的密碼',
            trailing: const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.mutedForeground,
            ),
            onTap: _changePassword,
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
    this.onTap,
  }) : centered = false,
       color = null;

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

/// Asks for the current password and a new one, twice. Pops `true` once the
/// password has changed. Errors show inside the dialog, where a toast would
/// sit under the barrier.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _fields = Listenable.merge([_current, _password, _confirm]);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _current.text.isNotEmpty &&
      _password.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

  String? _validate() {
    if (_password.text.length < 6) return '新密碼至少需要 6 個字元';
    if (_password.text != _confirm.text) return '兩次輸入的新密碼不一致';
    if (_password.text == _current.text) return '新密碼不能和目前的密碼相同';
    return null;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final problem = _validate();
    setState(() => _error = problem);
    if (problem != null) return;

    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await app.changePassword(
        currentPassword: _current.text,
        newPassword: _password.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('$e');
      if (mounted) setState(() => _error = '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('修改密碼', style: TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('目前的密碼'),
              PasswordField(
                controller: _current,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              const FieldLabel('新密碼'),
              PasswordField(
                controller: _password,
                newPassword: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              const FieldLabel('確認新密碼'),
              PasswordField(
                controller: _confirm,
                newPassword: true,
                onSubmitted: (_) => _submit(),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                FieldError(error, fontSize: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        ListenableBuilder(
          listenable: _fields,
          builder: (context, _) => FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('更新密碼'),
          ),
        ),
      ],
    );
  }
}
