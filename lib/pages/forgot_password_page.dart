import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_frame.dart';
import '../widgets/common.dart';
import 'reset_password_page.dart';

/// Asks for the work email and sends a password-reset code to it.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.email = ''});

  /// Pre-filled from the login form.
  final String email;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;

  /// The address the code went to; switches the card to its "sent" state.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _canSend => !_busy && _email.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    final email = _email.text.trim();
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      await app.sendPasswordReset(email: email);
      if (mounted) setState(() => _sentTo = email);
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      debugPrint('$e');
      if (mounted) showToast(context, '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enterCode(String email) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ResetPasswordPage(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return AuthFrame(child: sentTo == null ? _form() : _sent(sentTo));
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthHeading('忘記密碼', '我們會寄一組驗證碼到你的信箱，用來設定新密碼'),
        const SizedBox(height: 20),
        const FieldLabel('工作信箱'),
        TextField(
          controller: _email,
          autofocus: widget.email.isEmpty,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 20),
        // Rebuilds as the email is typed so the button enables itself.
        ListenableBuilder(
          listenable: _email,
          builder: (context, _) => AuthSubmitButton(
            label: '寄送驗證碼',
            icon: Icons.send_outlined,
            busy: _busy,
            onPressed: _canSend ? _send : null,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('想起來了？返回登入', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _sent(String email) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.successSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.success,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '請到信箱查收',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '如果 $email 有註冊帳號，驗證碼很快就會寄到。'
          '沒收到的話，也請看看垃圾郵件匣。',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),
        AuthSubmitButton(
          label: '輸入驗證碼',
          icon: Icons.arrow_forward,
          busy: false,
          onPressed: () => _enterCode(email),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _sentTo = null),
          child: const Text('換一個信箱', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
