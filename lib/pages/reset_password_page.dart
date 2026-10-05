import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/repositories/auth_repository.dart';
import '../widgets/auth_frame.dart';
import '../widgets/common.dart';

/// Sets a new password once the reset code has been verified. On success the
/// user is signed in and lands in the app; backing out cancels the reset.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _fields = Listenable.merge([_password, _confirm]);
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && _password.text.isNotEmpty && _confirm.text.isNotEmpty;

  String? _validate() {
    if (_password.text.length < 6) return '密碼至少需要 6 個字元';
    if (_password.text != _confirm.text) return '兩次輸入的密碼不一致';
    return null;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final problem = _validate();
    if (problem != null) {
      showToast(context, problem);
      return;
    }

    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await app.resetPassword(newPassword: _password.text);
      _done = true;
      // The app shell is already behind the login page; uncover it. Drop
      // any toast first: the login page and the splash both have a
      // Scaffold while they cross-fade, and a SnackBar in both trips the
      // duplicate Hero check.
      messenger.removeCurrentSnackBar();
      navigator.popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      debugPrint('$e');
      if (mounted) showToast(context, '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Left without a new password: don't stay signed in by the code.
        if (didPop && !_done) AppScope.of(context).cancelPasswordReset();
      },
      child: AuthFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading('設定新密碼', '驗證完成，請設定新的登入密碼'),
            const SizedBox(height: 20),
            const FieldLabel('新密碼'),
            PasswordField(
              controller: _password,
              newPassword: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            const FieldLabel('確認新密碼'),
            PasswordField(
              controller: _confirm,
              newPassword: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: _fields,
              builder: (context, _) => AuthSubmitButton(
                label: '更新密碼',
                icon: Icons.check,
                busy: _busy,
                onPressed: _canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
