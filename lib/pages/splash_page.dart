import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Cold-start splash for a restored session: the same opening as the login
/// intro (the waves rise and the F assembles in the middle of the screen),
/// then [onDone] hands over to the app. Tap to skip.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  /// Timeline, in ms: waves 0–500, F assembles 150–950, holds until 1300.
  static const _ms = 1300;
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _ms),
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Respect "reduce motion": go straight to the app.
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progress of the step from [start] to [end] ms, eased by [curve].
  double _step(int start, int end, [Curve curve = Curves.easeOutCubic]) {
    final ms = _controller.value * _ms;
    return curve.transform(((ms - start) / (end - start)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _controller.value = 1,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            BrandBackdrop(
              waves: _step(0, 500, Curves.linear),
              decor: _step(500, 1000),
            ),
            Center(
              child: SizedBox.square(
                dimension: 92,
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
            ),
          ],
        ),
      ),
    );
  }
}
