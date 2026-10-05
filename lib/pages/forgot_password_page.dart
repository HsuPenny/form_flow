import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/repositories/auth_repository.dart';
import '../widgets/auth_frame.dart';
import '../widgets/common.dart';
import 'verify_code_page.dart';

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
      if (mounted) _enterCode(email);
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
        builder: (_) =>
            VerifyCodePage(purpose: CodePurpose.passwordReset, email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      child: Column(
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
      ),
    );
  }
}
