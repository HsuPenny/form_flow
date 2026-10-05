import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/repositories/auth_repository.dart';
import '../widgets/auth_frame.dart';
import '../widgets/common.dart';

/// Takes the code from the reset email and a new password. On success the
/// user is signed in and lands in the app.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.email});

  /// Where the code was sent.
  final String email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _fields = Listenable.merge([_code, _password, _confirm]);
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _code.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

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
    setState(() => _busy = true);
    try {
      await app.resetPassword(
        email: widget.email,
        code: _code.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      showToast(context, '密碼已更新');
      // The app shell is already behind the login page; uncover it.
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

  Future<void> _resend() async {
    final sent = await runOrToast(
      context,
      () => AppScope.of(context).sendPasswordReset(email: widget.email),
    );
    if (sent && mounted) showToast(context, '已重新寄送驗證碼');
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthHeading('重設密碼', '輸入寄到 ${widget.email} 的驗證碼，並設定新密碼'),
          const SizedBox(height: 20),
          const FieldLabel('驗證碼'),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            // Supabase sends 6 digits by default; projects can raise it.
            maxLength: 10,
            decoration: const InputDecoration(counterText: ''),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text('沒收到驗證碼？重新寄送', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
