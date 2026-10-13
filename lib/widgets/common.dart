import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
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

/// Select field that looks like an input and opens its options in a
/// bottom sheet, with the current value checked.
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

  int get _selectedIndex => items.indexWhere((e) => e.$1 == value);

  Future<void> _openSheet(BuildContext context) async {
    // Returns an index rather than the value, so a null option (e.g.
    // "全部表單") is distinguishable from dismissing the sheet.
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SelectSheet(
        title: hint ?? '請選擇',
        labels: [for (final (_, text) in items) text],
        selected: _selectedIndex,
      ),
    );
    if (picked != null && picked != _selectedIndex) {
      onChanged(items[picked].$1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex;
    final text = index < 0 ? null : items[index].$2;

    return InkWell(
      onTap: items.isEmpty ? null : () => _openSheet(context),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InputDecorator(
        isEmpty: text == null,
        decoration: InputDecoration(
          fillColor: fillColor,
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: AppColors.mutedForeground),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          suffixIcon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.mutedForeground,
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40),
        ),
        child: Text(
          text ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Option list shown by [AppDropdownField]; pops the tapped index.
class _SelectSheet extends StatelessWidget {
  const _SelectSheet({
    required this.title,
    required this.labels,
    required this.selected,
  });

  final String title;
  final List<String> labels;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              // `useSafeArea` leaves the bottom edge alone, so clear the
              // home indicator here as well.
              padding: EdgeInsets.only(
                bottom: 32 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: labels.length,
              itemBuilder: (context, i) {
                final isSelected = i == selected;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedColor: AppColors.primaryDeep,
                  selectedTileColor: AppColors.primarySoft,
                  title: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(context, i),
                );
              },
            ),
          ),
        ],
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

  factory StatusBadge.forStatus(FormStatus status, {bool tracking = false}) {
    // 草稿 and 已結案 gray (nothing left to do), 待完成 blue, 已完成 green.
    return switch (status) {
      FormStatus.draft => const StatusBadge('草稿', tone: BadgeTone.muted),
      FormStatus.pending => StatusBadge(
        tracking ? '進行中' : '待完成',
        tone: BadgeTone.accent,
      ),
      FormStatus.completed => const StatusBadge('已完成', tone: BadgeTone.success),
      FormStatus.closed => const StatusBadge('已結案', tone: BadgeTone.muted),
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

/// A password [TextField] with an eye button that shows or hides the text.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.newPassword = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Lets password managers suggest a new password instead of filling one.
  final bool newPassword;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_visible,
      textInputAction: widget.textInputAction,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          onPressed: () => setState(() => _visible = !_visible),
          tooltip: _visible ? '隱藏密碼' : '顯示密碼',
          color: AppColors.mutedForeground,
          iconSize: 18,
          icon: Icon(
            _visible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
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

/// Like [PageBody], but only [list] scrolls: [header] stays put above it.
/// Pulling the list down calls [onRefresh].
class ListPageBody extends StatelessWidget {
  const ListPageBody({
    super.key,
    required this.header,
    required this.list,
    required this.onRefresh,
    this.maxWidth = 1100,
  });

  final Widget header;
  final Widget list;
  final RefreshCallback onRefresh;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final side = wide ? 40.0 : 16.0;
    Widget constrained(Widget child) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(side, wide ? 36 : 20, side, 16),
          child: constrained(header),
        ),
        Expanded(
          child: CustomRefreshIndicator(
            onRefresh: onRefresh,
            builder: (context, child, controller) =>
                _PullToRefreshFrame(controller: controller, child: child),
            child: SingleChildScrollView(
              // Pullable even when the list is too short to scroll.
              physics: const AlwaysScrollableScrollPhysics(),
              // Room for the floating bottom navigation on narrow screens.
              padding: EdgeInsets.fromLTRB(side, 0, side, wide ? 48 : 110),
              child: constrained(list),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slides the list down while pulling and lines up sparkles above it: they
/// pop in one by one as the pull arms, then hop in a wave while refreshing.
class _PullToRefreshFrame extends StatefulWidget {
  const _PullToRefreshFrame({required this.controller, required this.child});

  final IndicatorController controller;
  final Widget child;

  @override
  State<_PullToRefreshFrame> createState() => _PullToRefreshFrameState();
}

class _PullToRefreshFrameState extends State<_PullToRefreshFrame>
    with SingleTickerProviderStateMixin {
  static const _extent = 80.0;

  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  IndicatorController get _c => widget.controller;
  bool get _busy => _c.isSettling || _c.isLoading;

  @override
  void didUpdateWidget(_PullToRefreshFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_busy && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!_busy && _loop.isAnimating) {
      // Let the current hop land instead of freezing mid-air.
      _loop.forward().then((_) => _loop.reset());
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pull = _c.value.clamp(0.0, 1.0);
    // Keep every sparkle out from release until the indicator has gone away.
    final shown = _c.isDragging || _c.isArmed || _c.isCanceling ? pull : 1.0;
    final label = switch (_c.state) {
      IndicatorState.armed => '放開以重新整理',
      IndicatorState.settling || IndicatorState.loading => '更新中…',
      IndicatorState.complete || IndicatorState.finalizing => '已更新',
      _ => '下拉重新整理',
    };

    return ClipRect(
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, _extent * pull),
            child: widget.child,
          ),
          if (!_c.isIdle)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _extent * pull,
              child: OverflowBox(
                maxHeight: _extent,
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: Curves.easeIn.transform(pull),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _loop,
                        builder: (context, _) => CustomPaint(
                          size: const Size(_SparkleRowPainter.width, 30),
                          painter: _SparkleRowPainter(
                            shown: shown,
                            loop: _loop.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row of sparkles, popped in up to [shown] (0–1) and hopping with [loop].
class _SparkleRowPainter extends CustomPainter {
  const _SparkleRowPainter({required this.shown, required this.loop});

  final double shown;
  final double loop;

  /// Radius of each sparkle, big and small in turn like the logo's pair.
  static const _radii = [5.0, 8.0, 5.0, 8.0, 5.0];
  static const _gap = 22.0;
  static const width = _gap * 4 + 16;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [AppColors.primary, AppColors.primaryDark];
    final baseline = size.height - 9;

    for (var i = 0; i < _radii.length; i++) {
      // Each sparkle pops over its own slice of the pull, left to right.
      final from = i * 0.15;
      final t = ((shown - from) / 0.4).clamp(0.0, 1.0);
      final pop = Curves.elasticOut.transform(t);
      if (pop <= 0) continue;

      final phase = loop - i * 0.12;
      final hop = math.max(0.0, math.sin(2 * math.pi * phase));
      final twinkle = loop == 0 ? 1.0 : 1 + 0.25 * hop;
      final center = Offset(8 + _gap * i, baseline - 12 * hop);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.pi / 2 * hop);
      paintSparkle(
        canvas,
        Offset.zero,
        _radii[i] * pop * twinkle,
        Paint()..color = colors[i % 2],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparkleRowPainter old) =>
      old.shown != shown || old.loop != loop;
}

/// [tabs] with a 搜尋表單名稱 box: beside them on wide screens, behind a
/// toggle icon on narrow ones. Closing the box clears the query.
class TabsWithSearch extends StatefulWidget {
  const TabsWithSearch({
    super.key,
    required this.tabs,
    required this.onQueryChanged,
  });

  final Widget tabs;
  final ValueChanged<String> onQueryChanged;

  @override
  State<TabsWithSearch> createState() => _TabsWithSearchState();
}

class _TabsWithSearchState extends State<TabsWithSearch> {
  final _search = TextEditingController();
  bool _searchOpen = false; // narrow screens only

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final search = SizedBox(
      width: wide ? 240 : double.infinity,
      child: TextField(
        controller: _search,
        autofocus: !wide,
        onChanged: widget.onQueryChanged,
        decoration: const InputDecoration(
          hintText: '搜尋表單名稱',
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.search, size: 18),
          prefixIconConstraints: BoxConstraints(minWidth: 36),
        ),
      ),
    );
    if (wide) return Row(children: [widget.tabs, const Spacer(), search]);

    final searchToggle = Material(
      color: _searchOpen ? AppColors.primarySoft : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: () {
          setState(() => _searchOpen = !_searchOpen);
          if (!_searchOpen) {
            _search.clear();
            widget.onQueryChanged('');
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: _searchOpen ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Icon(
            _searchOpen ? Icons.close : Icons.search,
            size: 18,
            color: _searchOpen ? AppColors.primaryDeep : AppColors.foreground,
          ),
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: widget.tabs,
              ),
            ),
            const SizedBox(width: 8),
            searchToggle,
          ],
        ),
        if (_searchOpen) ...[const SizedBox(height: 10), search],
      ],
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [action]; if it throws, shows [failure] as a toast. Returns whether
/// it succeeded.
Future<bool> runOrToast(
  BuildContext context,
  Future<void> Function() action, {
  String failure = '連線失敗，請稍後再試',
}) async {
  try {
    await action();
    return true;
  } catch (e) {
    debugPrint('$e');
    if (context.mounted) showToast(context, failure);
    return false;
  }
}

/// The bare white [LogoMark], drawn part by part so the login intro and the
/// splash screen can animate each piece.
class AssemblingMark extends CustomPainter {
  const AssemblingMark({
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
  bool shouldRepaint(AssemblingMark old) =>
      old.stem != stem ||
      old.arm1 != arm1 ||
      old.arm2 != arm2 ||
      old.shadow != shadow ||
      old.spark1 != spark1 ||
      old.spark2 != spark2;
}
