import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_frame.dart';
import '../widgets/code_input.dart';
import '../widgets/common.dart';
import 'reset_password_page.dart';

/// What the emailed code is for.
enum CodePurpose { signUp, passwordReset }

/// Takes the code emailed for sign-up or a password reset. It checks itself
/// once every digit is in. A sign-up code signs in and lands in the app; a
/// reset code moves on to choosing the new password.
class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({
    super.key,
    required this.purpose,
    required this.email,
    this.codeJustSent = true,
  });

  final CodePurpose purpose;

  /// Where the code was sent.
  final String email;

  /// Whether a code went out just before this page opened. If so, resending
  /// waits out Supabase's one-per-minute limit; if not (signing in to an
  /// account whose sign-up was never finished) it's allowed right away.
  final bool codeJustSent;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  /// Supabase refuses a new code within 60 seconds of the last one.
  static const _resendWait = 60;

  final _code = TextEditingController();
  bool _busy = false;
  Timer? _timer;
  int _wait = 0;

  @override
  void initState() {
    super.initState();
    if (widget.codeJustSent) _startWait();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = _resendWait);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _wait--);
      if (_wait == 0) timer.cancel();
    });
  }

  String get _title => switch (widget.purpose) {
    CodePurpose.signUp => '註冊認證',
    CodePurpose.passwordReset => '忘記密碼認證',
  };

  String get _hint => widget.codeJustSent
      ? '驗證碼已寄送至 ${widget.email}'
      : '請輸入註冊時寄到 ${widget.email} 的驗證碼';

  Future<void> _verify(String code) async {
    if (_busy) return;
    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      switch (widget.purpose) {
        case CodePurpose.signUp:
          await app.verifySignUp(email: widget.email, code: code);
          // The app shell is already behind the login page; uncover it. Drop
          // any toast first: the login page and the splash both have a
          // Scaffold while they cross-fade, and a SnackBar in both trips the
          // duplicate Hero check.
          messenger.removeCurrentSnackBar();
          navigator.popUntil((route) => route.isFirst);
        case CodePurpose.passwordReset:
          await app.verifyRecoveryCode(email: widget.email, code: code);
          // The code is used up, so going back should skip this page.
          navigator.pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const ResetPasswordPage()),
          );
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      showToast(context, e.message);
      _code.clear();
    } catch (e) {
      debugPrint('$e');
      if (mounted) showToast(context, '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await switch (widget.purpose) {
        CodePurpose.signUp => app.resendSignUpCode(email: widget.email),
        CodePurpose.passwordReset => app.sendPasswordReset(email: widget.email),
      };
      if (!mounted) return;
      showToast(context, '已重新寄送驗證碼');
      _code.clear();
      _startWait();
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      debugPrint('$e');
      if (mounted) showToast(context, '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showHelp() async {
    final changeEmail = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('收不到驗證碼？', style: TextStyle(fontSize: 18)),
        content: Text(
          '・看看垃圾郵件匣或促銷郵件分類\n'
          '・確認信箱 ${widget.email} 沒有打錯\n'
          '・信件可能要一兩分鐘才會寄到，倒數結束後可以重新寄送',
          style: const TextStyle(fontSize: 13, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('修改信箱'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    // The previous page still holds the email for editing.
    if (changeEmail == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
          const FieldLabel('驗證碼'),
          CodeInput(controller: _code, enabled: !_busy, onCompleted: _verify),
          const SizedBox(height: 10),
          Text(
            _hint,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),
          Center(child: _busy ? _spinner() : _resendButton()),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _showHelp,
              child: const Text(
                '收不到驗證碼？',
                style: TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spinner() => const Padding(
    padding: EdgeInsets.all(12),
    child: SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget _resendButton() {
    final waiting = _wait > 0;
    return TextButton(
      onPressed: waiting ? null : _resend,
      child: Text(
        waiting ? '重新發送驗證碼（$_wait秒）' : '重新發送驗證碼',
        style: const TextStyle(
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
