import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'brand_icons.dart';

export 'brand_icons.dart';

const double kWideBreakpoint = 900;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// The Formfield mark: a 3D "F" made of rounded bars, plus sparkles.
/// Same geometry as the app icon (see the 100×100 grid in [_LogoPainter]).
class LogoMark extends StatelessWidget {
  const LogoMark({
    super.key,
    this.size = 36,
    this.bare = false,
    this.color = Colors.white,
  });

  final double size;

  /// Just the white F and sparkles, without the tile, cropped to the mark.
  /// For use directly on the brand gradient.
  final bool bare;

  /// Color of the bare mark, e.g. orange on a light background. The tile
  /// version is always white on orange.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _LogoPainter(bare: bare, color: bare ? color : Colors.white),
    );
  }
}

/// The F's parts on the 100×100 logo grid, shared by [LogoMark] and the
/// animated splash screen.
abstract final class LogoGeometry {
  /// Stem, top arm, middle arm.
  static const bars = [
    RRect.fromLTRBXY(24, 22, 37, 78, 6.5, 6.5),
    RRect.fromLTRBXY(42, 22, 76, 35, 6.5, 6.5),
    RRect.fromLTRBXY(42, 43, 76, 56, 6.5, 6.5),
  ];
  static const shadowOffset = Offset(4, 4);

  /// Centre and radius of the big and small sparkle.
  static const sparkles = [(Offset(70, 70), 8.0), (Offset(79, 60), 3.0)];

  /// The part of the grid the bare mark occupies (F, shadow and sparkles),
  /// so it fills its box instead of floating in tile padding.
  static const bareBounds = Rect.fromLTWH(18, 18, 66, 66);

  static const shadow = Color(0xFFC4501A);
  static const edge = Color(0xFFFFE3CF);
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.bare, required this.color});

  final bool bare;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (bare) {
      const bounds = LogoGeometry.bareBounds;
      canvas.scale(size.width / bounds.width);
      canvas.translate(-bounds.left, -bounds.top);
    } else {
      canvas.scale(size.width / 100);
      _paintTile(canvas);
    }

    const bars = LogoGeometry.bars;
    final mark = Paint()..color = color;

    // Drop shadow, then the F, then a light edge along each bar's top.
    final shadow = Paint()
      ..color = LogoGeometry.shadow.withValues(alpha: bare ? 0.4 : 0.35);
    for (final b in bars) {
      canvas.drawRRect(b.shift(LogoGeometry.shadowOffset), shadow);
    }
    for (final b in bars) {
      canvas.drawRRect(b, mark);
    }
    // Top highlight: the light peach on white, or a lighter tint of [color].
    final edge = Paint()
      ..color = color == Colors.white
          ? LogoGeometry.edge
          : Color.lerp(color, Colors.white, 0.35)!;
    for (final b in bars) {
      canvas.save();
      canvas.clipRRect(b);
      // The stem's edge sits in the top row only.
      canvas.drawRect(Rect.fromLTWH(b.left, b.top, b.width, 4.5), edge);
      canvas.restore();
    }

    for (final (c, r) in LogoGeometry.sparkles) {
      paintSparkle(canvas, c, r, mark);
    }
    canvas.restore();
  }

  /// Brand gradient tile with a top sheen and a corner glow.
  void _paintTile(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 100, 100);
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(23)));
    canvas.drawRect(
      rect,
      Paint()..shader = AppGradients.brand.createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.55],
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      const Offset(86, 12),
      26,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.bare != bare || oldDelegate.color != color;
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        LogoMark(size: 32, bare: true, color: AppColors.primary),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formfield',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '團隊表單中心',
              style: TextStyle(fontSize: 10, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ],
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppText.eyebrow.copyWith(color: color),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlighted = false,
    this.error = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  /// Red outline for a card holding invalid input; wins over [highlighted].
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.base);
    return Material(
      color: AppColors.card,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: error
                  ? AppColors.destructive
                  : highlighted
                  ? AppColors.primary
                  : AppColors.border,
              width: error ? 1.5 : (highlighted ? 1.3 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.foreground.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Validation message: always icon + text, so errors never rely on the red
/// alone (it sits close to the brand orange). Also usable as
/// `InputDecoration.error`.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key, this.fontSize = 11});

  final String message;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: fontSize + 2,
          color: AppColors.destructive,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            message,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: AppColors.destructive,
            ),
          ),
        ),
      ],
    );
  }
}

/// A button shown inside [PageHeader].
class HeaderAction {
  const HeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// Orange gradient banner that opens every page: small label + title, with an
/// optional back/close button on the left and one action on the right.
///
/// On narrow screens the subtitle is hidden so the banner stays short; pages
/// there should put their main action in a floating button instead.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.icon,
    this.subtitle,
    this.leading,
    this.action,
    this.bottom,
  });

  final String eyebrow;
  final String title;

  /// Drawn large and faint in the bottom-right corner.
  final BrandGlyph icon;
  final String? subtitle;
  final HeaderAction? leading;
  final HeaderAction? action;

  /// Shown under the title row, e.g. a step progress bar.
  final Widget? bottom;

  static final _labelColor = Colors.white.withValues(alpha: 0.85);

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(fontSize: wide ? 12 : 11, color: _labelColor),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: wide ? 22 : 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.35,
          ),
        ),
        if (wide && subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13, color: _labelColor, height: 1.5),
          ),
        ],
      ],
    );

    final row = Row(
      children: [
        if (leading != null) ...[
          _leadingButton(leading!),
          SizedBox(width: wide ? 14 : 10),
        ],
        Expanded(child: text),
        if (action != null) ...[
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDeep,
            ),
            onPressed: action!.onPressed,
            icon: Icon(action!.icon, size: 18),
            label: Text(action!.label),
          ),
        ],
      ],
    );

    return BrandBanner(
      icon: icon,
      padding: wide
          ? const EdgeInsets.fromLTRB(24, 20, 24, 20)
          : const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: bottom == null
          ? row
          : Column(
              children: [
                row,
                SizedBox(height: wide ? 14 : 10),
                bottom!,
              ],
            ),
    );
  }

  Widget _leadingButton(HeaderAction a) {
    return Tooltip(
      message: a.label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: a.onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(a.icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Brand gradient card with waves, sparkles and a large translucent [icon]
/// in the bottom-right corner. [PageHeader] and the settings profile banner
/// use it.
class BrandBanner extends StatelessWidget {
  const BrandBanner({
    super.key,
    required this.icon,
    required this.padding,
    required this.child,
  });

  final BrandGlyph icon;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _BannerPainter())),
          Positioned(
            right: -8,
            bottom: wide ? -22 : -18,
            child: BrandIcon(
              icon,
              size: wide ? 108 : 80,
              color: Colors.white.withValues(alpha: 0.32),
              edgeColor: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// "Formfield · 團隊表單中心" in a translucent pill with a white outline.
class BrandPill extends StatelessWidget {
  const BrandPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'FormFlow · 團隊表單中心',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Full-screen waves and sparkles on the brand gradient, used behind the
/// login page and the splash screen (which animates it in).
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, this.waves = 1, this.decor = 1});

  /// 0 = both waves below the screen, 1 = in place. The back wave leads.
  final double waves;

  /// Opacity of the corner glow, sparkles and dots.
  final double decor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.brand),
      child: CustomPaint(painter: _BackdropPainter(waves, decor)),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.waves, this.decor);

  final double waves;
  final double decor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Paint fill(double alpha) =>
        Paint()..color = Colors.white.withValues(alpha: alpha);

    // Each wave rises from just below the screen; the front one starts late.
    double drop(double start) =>
        (1 -
            Curves.easeOutCubic.transform(
              ((waves - start) / (1 - start)).clamp(0, 1),
            )) *
        h *
        0.3;

    canvas.save();
    canvas.translate(0, drop(0));
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.78)
        ..cubicTo(w * 0.3, h * 0.68, w * 0.55, h * 0.92, w, h * 0.8)
        ..lineTo(w, h * 1.3)
        ..lineTo(0, h * 1.3)
        ..close(),
      fill(0.1),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(0, drop(0.2));
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.25, h * 1.3)
        ..lineTo(w * 0.25, h)
        ..cubicTo(w * 0.5, h * 0.88, w * 0.75, h * 0.93, w, h * 0.88)
        ..lineTo(w, h * 1.3)
        ..close(),
      fill(0.12),
    );
    canvas.restore();

    if (decor <= 0) return;
    canvas.drawCircle(
      Offset(w * 0.95, h * 0.04),
      size.shortestSide * 0.3,
      fill(0.08 * decor),
    );
    final star = fill(0.85 * decor);
    paintSparkle(canvas, Offset(w * 0.84, h * 0.13), 9, star);
    paintSparkle(canvas, Offset(w * 0.84 + 13, h * 0.13 - 11), 4, star);
    paintSparkle(canvas, Offset(w * 0.84 + 12, h * 0.13 + 12), 2.6, star);
    paintSparkle(canvas, Offset(w * 0.14, h * 0.09), 4.5, star);
    paintSparkle(canvas, Offset(w * 0.72, h * 0.9), 5, star);
    canvas.drawCircle(Offset(w * 0.55, h * 0.06), 2, fill(0.6 * decor));
    canvas.drawCircle(Offset(w * 0.12, h * 0.9), 1.8, fill(0.6 * decor));
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.waves != waves || old.decor != decor;
}

/// Draws a four-point sparkle ("✦") of radius [r] centred on [c].
void paintSparkle(Canvas canvas, Offset c, double r, Paint paint) {
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close(),
    paint,
  );
}

/// Soft waves and sparkles behind [BrandBanner].
///
/// Drawn on a 320×68 design grid anchored to the right edge and scaled by
/// height, so wide banners keep the same look instead of stretching.
class _BannerPainter extends CustomPainter {
  const _BannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 68;
    Offset p(double x, double y) => Offset(size.width - (320 - x) * s, y * s);
    Paint fill(double alpha) =>
        Paint()..color = Colors.white.withValues(alpha: alpha);

    Path wave(List<double> v) {
      final a = p(v[0], v[1]);
      final c1 = p(v[2], v[3]), c2 = p(v[4], v[5]), e1 = p(v[6], v[7]);
      final c3 = p(v[8], v[9]), c4 = p(v[10], v[11]), e2 = p(v[12], v[13]);
      return Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e1.dx, e1.dy)
        ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, e2.dx, e2.dy)
        ..lineTo(size.width + 10 * s, size.height)
        ..close();
    }

    canvas.drawPath(
      wave([140, 68, 190, 40, 230, 70, 270, 34, 310, -2, 320, 10, 330, 0]),
      fill(0.12),
    );
    canvas.drawPath(
      wave([200, 68, 240, 50, 270, 62, 300, 44, 330, 26, 330, 30, 330, 30]),
      fill(0.12),
    );
    canvas.drawCircle(p(300, 8), 26 * s, fill(0.1));

    void sparkle(double x, double y, double r) =>
        paintSparkle(canvas, p(x, y), r * s, fill(0.85));

    sparkle(175, 14, 5);
    sparkle(292, 56, 4);
    canvas.drawCircle(p(198, 54), 2 * s, fill(0.7));
    canvas.drawCircle(p(150, 24), 1.6 * s, fill(0.6));

    // A "✨" cluster: one big star with two small ones beside it.
    sparkle(226, 13, 6);
    sparkle(234, 6, 2.6);
    sparkle(233, 20, 1.8);
  }

  @override
  bool shouldRepaint(_BannerPainter oldDelegate) => false;
}

/// Dropdown field whose opened menu lines up exactly with the field.
///
/// Flutter sizes the menu from the inner button and then pads it 16px/24px
/// outward, so with the field's own content padding the menu overhangs the
/// field. Here the button fills the field (the horizontal padding moves into
/// the button) and `alignedDropdown` drops that extra margin.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.icon,
    this.fillColor,
  });

  final T? value;

  /// (value, label) pairs.
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  /// Shown before the selected value, e.g. a filter icon.
  final IconData? icon;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    Widget label(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

    return ButtonTheme(
      alignedDropdown: true,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: InputDecoration(
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        hint: hint == null
            ? null
            : Text(
                hint!,
                style: const TextStyle(
                  fontSize: AppText.inputSize,
                  color: AppColors.mutedForeground,
                ),
              ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        dropdownColor: Colors.white,
        selectedItemBuilder: icon == null
            ? null
            : (context) => [
                for (final (_, text) in items)
                  Row(
                    children: [
                      Icon(icon, size: 18, color: AppColors.mutedForeground),
                      const SizedBox(width: 8),
                      Expanded(child: label(text)),
                    ],
                  ),
              ],
        items: [
          for (final (v, text) in items)
            DropdownMenuItem<T>(value: v, child: label(text)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// Compact on/off switch. Material 3's default (52×32) looks oversized next
/// to our 12–13px text, so this lays it out at 3/4 size.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _scale = 0.75;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52 * _scale,
      height: 32 * _scale,
      child: FittedBox(
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

enum BadgeTone { primary, success, accent, muted, destructive }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.primary});

  factory StatusBadge.forForm(FormItem form, {bool tracking = false}) {
    // One color per status: 草稿 gray, 待完成 blue, 已完成 green.
    return switch (form.status) {
      FormStatus.draft => const StatusBadge('草稿', tone: BadgeTone.muted),
      FormStatus.pending => StatusBadge(
        tracking ? '進行中' : '待完成',
        tone: BadgeTone.accent,
      ),
      FormStatus.completed => const StatusBadge('已完成', tone: BadgeTone.success),
    };
  }

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.primary => (AppColors.primarySoft, AppColors.primaryDeep),
      BadgeTone.success => (AppColors.successSoft, AppColors.success),
      BadgeTone.accent => (AppColors.accentSoft, AppColors.accent),
      BadgeTone.muted => (AppColors.muted, AppColors.mutedForeground),
      BadgeTone.destructive => (
        AppColors.destructiveSoft,
        AppColors.destructive,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 32, this.dimmed = false});

  final String initials;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dimmed ? AppColors.muted : AppColors.primarySoft,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: dimmed ? AppColors.mutedForeground : AppColors.primaryDeep,
        ),
      ),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine(this.value, {super.key, this.width});

  final double value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 5,
        backgroundColor: AppColors.muted,
        color: AppColors.primaryDark,
      ),
    );
    return width == null ? bar : SizedBox(width: width, child: bar);
  }
}

const _tabDuration = Duration(milliseconds: 220);
const _tabCurve = Curves.easeOutCubic;

/// Pill-style segmented control (全部 / 已完成 / 待完成, 完成進度 / 最新回覆).
///
/// Items share one width so a single white indicator can slide between them;
/// text and badge colors animate on the same timing, so nothing flickers.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.counts,
  });

  final List<String> labels;
  final List<int>? counts;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: _tabDuration,
                curve: _tabCurve,
                alignment: Alignment(
                  n == 1 ? 0 : -1 + 2 * selected / (n - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
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
                for (var i = 0; i < n; i++) Expanded(child: _item(context, i)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i) {
    final active = i == selected;
    final base = DefaultTextStyle.of(context).style;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: _tabDuration,
              curve: _tabCurve,
              style: base.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
              ),
              child: Text(labels[i]),
            ),
            if (counts != null) ...[
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: _tabDuration,
                curve: _tabCurve,
                padding: const EdgeInsets.fromLTRB(6, 1, 6, 3),
                decoration: BoxDecoration(
                  color: active ? AppColors.primarySoft : AppColors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: _tabDuration,
                  curve: _tabCurve,
                  style: base.copyWith(
                    fontSize: 10,
                    color: active
                        ? AppColors.primaryDeep
                        : AppColors.mutedForeground,
                  ),
                  child: Text('${counts![i]}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Small "01" chip used to number questions.
class NumberChip extends StatelessWidget {
  const NumberChip(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        (index + 1).toString().padLeft(2, '0'),
        style: AppText.mono.copyWith(
          fontSize: 10,
          color: AppColors.primaryDeep,
        ),
      ),
    );
  }
}

/// Constrains page content and adds consistent page padding.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.bottomPadding,
  });

  final Widget child;
  final double maxWidth;

  /// Defaults to leaving room for the floating bottom navigation.
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        wide ? 40 : 16,
        wide ? 36 : 20,
        wide ? 40 : 16,
        bottomPadding ?? (wide ? 48 : 110),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
