import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.playIntro = false, this.onIntroDone});

  /// Plays the opening animation (on a cold start): the waves rise, the F
  /// assembles in the middle of the screen and glides into its place in the
  /// layout, then the headline, pill and card float up. Tap to skip.
  final bool playIntro;
  final VoidCallback? onIntroDone;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Sign-up mode adds 顯示名稱 and 確認密碼 fields and creates the account.
  bool _signUp = false;
  bool _busy = false;

  static final _softWhite = Colors.white.withValues(alpha: 0.85);

  /// Intro timeline, in ms: waves 0–500, F assembles 150–950, glides into
  /// place 1000–1500, content floats up 1250–1800.
  static const _introMs = 1800;
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );
  bool _introStarted = false;
  bool get _introDone => _intro.isCompleted;

  /// Where the F sits in the layout; the intro glides the mark onto it.
  final _logoSlot = GlobalKey();
  final _stack = GlobalKey();

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      setState(() {}); // Swap the moving mark for the real one.
      widget.onIntroDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    // Respect "reduce motion" and skip straight to the end.
    if (widget.playIntro && !MediaQuery.disableAnimationsOf(context)) {
      _intro.forward();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Progress of the intro step from [start] to [end] ms, eased by [curve].
  double _step(int start, int end, [Curve curve = Curves.easeOutCubic]) {
    final ms = _intro.value * _introMs;
    return curve.transform(((ms - start) / (end - start)).clamp(0.0, 1.0));
  }

  /// Fades [child] in and lifts it 14px during the intro step.
  Widget _reveal(int start, int end, Widget child) {
    return AnimatedBuilder(
      animation: _intro,
      child: child,
      builder: (context, child) {
        final t = _step(start, end);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  /// The F's place in the layout. Empty while the intro's mark is moving.
  Widget _logo(double size) {
    return SizedBox.square(
      key: _logoSlot,
      dimension: size,
      child: _introDone ? LogoMark(size: size, bare: true) : null,
    );
  }

  String? _validate(String name, String email, String password) {
    if (_signUp && name.isEmpty) return '請輸入顯示名稱';
    if (email.isEmpty) return '請輸入工作信箱';
    if (password.isEmpty) return '請輸入密碼';
    if (_signUp && password.length < 6) return '密碼至少需要 6 個字元';
    if (_signUp && password != _confirm.text) return '兩次輸入的密碼不一致';
    return null;
  }

  Future<void> _enter() async {
    if (_busy) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final problem = _validate(name, email, password);
    if (problem != null) {
      showToast(context, problem);
      return;
    }

    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      _signUp
          ? await app.signUp(
              email: email,
              password: password,
              displayName: name,
            )
          : await app.login(email: email, password: password);
    } on AuthFailure catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      debugPrint('$e');
      if (mounted) showToast(context, '連線失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(email: _email.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Scaffold(
      body: Stack(
        key: _stack,
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _intro,
            builder: (context, _) => BrandBackdrop(
              waves: _step(0, 500, Curves.linear),
              decor: _step(500, 1000),
            ),
          ),
          SafeArea(
            child: wide
                ? Row(
                    children: [
                      Expanded(child: _introColumn()),
                      Expanded(
                        child: Center(child: _reveal(1400, 1800, _card())),
                      ),
                    ],
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                      child: Column(
                        children: [
                          _welcome(),
                          const SizedBox(height: 24),
                          _reveal(1400, 1800, _card()),
                        ],
                      ),
                    ),
                  ),
          ),
          if (!_introDone)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _intro.value = 1,
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => _movingMark(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The intro's F: assembled large in the middle of the screen, then
  /// shrunk and moved onto [_logoSlot].
  Widget _movingMark() {
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final slot = _logoSlot.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return const SizedBox.shrink();

    final start = Rect.fromCenter(
      center: stack.size.center(Offset.zero),
      width: 92,
      height: 92,
    );
    final end = slot != null && slot.hasSize
        ? slot.localToGlobal(Offset.zero, ancestor: stack) & slot.size
        : start;
    final rect = Rect.lerp(
      start,
      end,
      _step(1000, 1500, Curves.easeInOutCubic),
    )!;

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: CustomPaint(
            painter: AssemblingMark(
              stem: _step(150, 450, Curves.easeOutBack),
              arm1: _step(300, 600, Curves.easeOutBack),
              arm2: _step(450, 750, Curves.easeOutBack),
              shadow: _step(650, 850),
              spark1: _step(650, 950, Curves.easeOutBack),
              spark2: _step(700, 950, Curves.easeOutBack),
            ),
          ),
        ),
      ],
    );
  }

  /// Centered logo + headline above the card on narrow screens.
  Widget _welcome() {
    return Column(
      children: [
        _logo(72),
        const SizedBox(height: 16),
        _reveal(
          1250,
          1600,
          const Text(
            '讓每一份回覆，都有去處',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _reveal(1350, 1700, const BrandPill()),
      ],
    );
  }

  /// Left column on wide screens.
  Widget _introColumn() {
    const headline = TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      height: 1.3,
    );
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logo(40),
              const SizedBox(width: 14),
              _reveal(1350, 1700, const BrandPill()),
            ],
          ),
          const Spacer(),
          _reveal(
            1250,
            1600,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('讓每一份回覆，', style: headline),
                const Text('都有去處。', style: headline),
                const SizedBox(height: 18),
                Text(
                  'FormFlow 把發送、填寫與追蹤放在同一個安靜的工作空間。\n少一點來回確認，多一點真正完成的事情。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: _softWhite,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          _reveal(
            1400,
            1800,
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Northstar Studio · 內部工作區',
                  style: TextStyle(fontSize: 12, color: _softWhite),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.base + 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_signUp) ...[
              const FieldLabel('顯示名稱'),
              TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 18),
            ],
            const FieldLabel('工作信箱'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 18),
            const FieldLabel('密碼'),
            PasswordField(
              controller: _password,
              newPassword: _signUp,
              textInputAction: _signUp ? TextInputAction.next : null,
              onSubmitted: _signUp ? null : (_) => _enter(),
            ),
            if (_signUp) ...[
              const SizedBox(height: 18),
              const FieldLabel('確認密碼'),
              PasswordField(
                controller: _confirm,
                newPassword: true,
                onSubmitted: (_) => _enter(),
              ),
            ],
            if (!_signUp) ...[
              const SizedBox(height: 10),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: _busy ? null : _forgotPassword,
                  borderRadius: BorderRadius.circular(4),
                  child: const Text(
                    '忘記密碼？',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _enter,
                iconAlignment: IconAlignment.end,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward, size: 16),
                label: Text(_signUp ? '建立帳號' : '登入'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _signUp = !_signUp),
                child: Text(
                  _signUp ? '已經有帳號了？登入' : '還沒有帳號？建立帳號',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
