import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
  late final _email = TextEditingController(text: 'lisa.wang@northstar.co');
  Role _role = Role.admin;

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
    _email.dispose();
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

  void _enter() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      showToast(context, '請輸入工作信箱');
      return;
    }
    AppScope.of(context).login(email, _role);
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
            painter: _AssemblingMark(
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
            const FieldLabel('工作信箱'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _enter(),
            ),
            const SizedBox(height: 18),
            const FieldLabel('登入身份'),
            _RoleSwitch(
              value: _role,
              onChanged: (r) => setState(() => _role = r),
            ),
            const SizedBox(height: 8),
            Text(
              _role.hint,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _enter,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('使用示範身份進入'),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                '你的資料只保存在這個裝置中',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-option segmented control for picking the demo role.
///
/// Like [SegmentedTabs]: one white indicator slides between the options and
/// the label colors animate on the same timing. Fading each option's own
/// background instead leaves both half-white mid-way, which reads as a flash.
class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.value, required this.onChanged});

  final Role value;
  final ValueChanged<Role> onChanged;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  static IconData _icon(Role r) => switch (r) {
    Role.admin => Icons.admin_panel_settings_outlined,
    Role.member => Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    const roles = Role.values;
    final index = roles.indexOf(value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: _duration,
              curve: _curve,
              alignment: Alignment(-1 + 2 * index / (roles.length - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / roles.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.foreground.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final r in roles)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(r),
                    child: TweenAnimationBuilder<Color?>(
                      duration: _duration,
                      curve: _curve,
                      tween: ColorTween(
                        end: r == value
                            ? AppColors.primaryDeep
                            : AppColors.mutedForeground,
                      ),
                      builder: (context, color, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_icon(r), size: 16, color: color),
                            const SizedBox(width: 6),
                            Text(
                              r.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The bare white [LogoMark], drawn part by part so the intro can animate
/// each piece.
class _AssemblingMark extends CustomPainter {
  const _AssemblingMark({
    required this.stem,
    required this.arm1,
    required this.arm2,
    required this.shadow,
    required this.spark1,
    required this.spark2,
  });

  final double stem, arm1, arm2, shadow, spark1, spark2;

  @override
  void paint(Canvas canvas, Size size) {
    const bounds = LogoGeometry.bareBounds;
    canvas.save();
    canvas.scale(size.width / bounds.width);
    canvas.translate(-bounds.left, -bounds.top);

    const bars = LogoGeometry.bars;
    if (shadow > 0) {
      final paint = Paint()
        ..color = LogoGeometry.shadow.withValues(alpha: 0.4 * shadow);
      for (final b in bars) {
        canvas.drawRRect(b.shift(LogoGeometry.shadowOffset), paint);
      }
    }

    // Stem grows up from its bottom edge.
    if (stem > 0) {
      final b = bars[0];
      canvas.save();
      canvas.translate(0, b.bottom);
      canvas.scale(1, stem);
      canvas.translate(0, -b.bottom);
      _bar(canvas, b, 1);
      canvas.restore();
    }
    // Arms slide in from the right while fading in.
    for (final (b, t) in [(bars[1], arm1), (bars[2], arm2)]) {
      if (t <= 0) continue;
      _bar(canvas, b.shift(Offset(30 * (1 - t), 0)), t.clamp(0, 1));
    }

    // Sparkles pop in with a quarter turn.
    for (final ((c, r), t) in [
      (LogoGeometry.sparkles[0], spark1),
      (LogoGeometry.sparkles[1], spark2),
    ]) {
      if (t <= 0) continue;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-math.pi / 2 * (1 - t));
      canvas.scale(t);
      paintSparkle(canvas, Offset.zero, r, Paint()..color = Colors.white);
      canvas.restore();
    }
    canvas.restore();
  }

  /// A white bar with the logo's light top edge.
  void _bar(Canvas canvas, RRect b, double opacity) {
    canvas.drawRRect(
      b,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    canvas.save();
    canvas.clipRRect(b);
    canvas.drawRect(
      Rect.fromLTWH(b.left, b.top, b.width, 4.5),
      Paint()..color = LogoGeometry.edge.withValues(alpha: opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AssemblingMark old) =>
      old.stem != stem ||
      old.arm1 != arm1 ||
      old.arm2 != arm2 ||
      old.shadow != shadow ||
      old.spark1 != spark1 ||
      old.spark2 != spark2;
}
