import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'common.dart' show paintSparkle;

/// The app's own icons, drawn with the same rounded bars and sparkles as the
/// Formfield logo.
enum BrandGlyph {
  // Pages: solid, outline and banner styles.
  forms,
  tracking,
  profile,
  create,
  fill,

  // Settings rows: solid only.
  bell,
  calendar,
  verified,
  swap,
  logout;

  /// Whether the glyph has its own outline and banner-edge drawings.
  bool get isPage => index <= BrandGlyph.fill.index;
}

/// Paints a [BrandGlyph] on a 24×24 grid.
///
/// [fill] runs from 0 (outline, for unselected navigation items) to 1 (solid
/// with cut-out details); values in between cross-fade, so it can be animated.
class BrandIcon extends StatelessWidget {
  const BrandIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.fill = 1,
    this.edgeColor,
  });

  final BrandGlyph glyph;
  final double size;

  /// Defaults to the ambient [IconTheme] color.
  final Color? color;
  final double fill;

  /// Adds a thin outline and brighter details on top of the solid glyph, so a
  /// faint icon (e.g. the banner's corner icon) still reads clearly.
  final Color? edgeColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BrandIconPainter(
        glyph,
        color ?? IconTheme.of(context).color ?? Colors.black,
        fill.clamp(0, 1),
        edgeColor,
      ),
    );
  }
}

class _BrandIconPainter extends CustomPainter {
  const _BrandIconPainter(this.glyph, this.color, this.fill, this.edgeColor);

  final BrandGlyph glyph;
  final Color color;
  final double fill;
  final Color? edgeColor;

  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    // Each style is drawn opaque inside its own layer, then faded as a whole,
    // so overlapping parts and cut-outs never show through.
    final opaque = color.withValues(alpha: 1);
    if (fill < 1) {
      _layer(canvas, color.a * (1 - fill), () => _outline(canvas, opaque));
    }
    if (fill > 0) {
      _layer(canvas, color.a * fill, () => _solid(canvas, opaque));
    }
    final edge = edgeColor;
    if (edge != null) {
      _layer(canvas, edge.a, () => _edges(canvas, edge.withValues(alpha: 1)));
    }
    canvas.restore();
  }

  void _layer(Canvas canvas, double alpha, VoidCallback draw) {
    canvas.saveLayer(
      const Rect.fromLTWH(-4, -4, 32, 32),
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    draw();
    canvas.restore();
  }

  static final _clear = Paint()..blendMode = BlendMode.clear;

  static Paint _fillPaint(Color c) => Paint()..color = c;

  static Paint _strokePaint(Color c, [double w = _stroke]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static RRect _rr(double l, double t, double w, double h, double r) =>
      RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(r));

  // A form sheet with two text lines, used by forms / create / fill.
  static final _sheet = _rr(3, 3, 14, 18, 3);
  static final _sheetLines = [
    _rr(5.8, 7, 8.4, 2.2, 1.1),
    _rr(5.8, 11, 5.5, 2.2, 1.1),
  ];

  static const _checkPoints = [
    Offset(8.6, 12.2),
    Offset(10.9, 14.5),
    Offset(15.3, 9.9),
  ];

  Path get _check => Path()
    ..moveTo(_checkPoints[0].dx, _checkPoints[0].dy)
    ..lineTo(_checkPoints[1].dx, _checkPoints[1].dy)
    ..lineTo(_checkPoints[2].dx, _checkPoints[2].dy);

  // Pencil for the fill page: a rounded bar tilted over the sheet's corner.
  void _withPencil(Canvas canvas, void Function(RRect pencil) draw) {
    canvas.save();
    canvas.translate(17.2, 14.5);
    canvas.rotate(35 * math.pi / 180);
    draw(_rr(-2, -6.5, 4, 13, 2));
    canvas.restore();
  }

  void _solid(Canvas canvas, Color c) {
    final p = _fillPaint(c);
    switch (glyph) {
      case BrandGlyph.forms:
        canvas.drawRRect(
          _rr(7, 2.5, 13, 16, 3),
          _fillPaint(c.withValues(alpha: 0.45)),
        );
        final front = _rr(4, 5.5, 13, 16, 3);
        canvas.drawRRect(front.inflate(1.2), _clear);
        canvas.drawRRect(front, p);
        canvas.drawRRect(_rr(6.8, 9, 7.4, 2.2, 1.1), _clear);
        canvas.drawRRect(_rr(6.8, 13, 5, 2.2, 1.1), _clear);
      case BrandGlyph.tracking:
        const center = Offset(12, 12);
        canvas.drawCircle(
          center,
          8,
          _strokePaint(c.withValues(alpha: 0.45), 3.2),
        );
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 8),
          -math.pi / 2,
          math.pi * 2 * 0.72,
          false,
          _strokePaint(c, 3.2),
        );
        canvas.drawPath(_check, _strokePaint(c, 2.4));
      case BrandGlyph.profile:
        canvas.drawCircle(const Offset(11, 8), 4.2, p);
        canvas.drawRRect(_rr(3.5, 14, 15, 7.5, 3.75), p);
        paintSparkle(canvas, const Offset(20, 5.5), 3, p);
      case BrandGlyph.create:
        canvas.drawRRect(_sheet, p);
        for (final l in _sheetLines) {
          canvas.drawRRect(l, _clear);
        }
        paintSparkle(canvas, const Offset(19, 15), 5.4, _clear);
        paintSparkle(canvas, const Offset(19, 15), 4, p);
      case BrandGlyph.fill:
        canvas.drawRRect(_sheet, p);
        for (final l in _sheetLines) {
          canvas.drawRRect(l, _clear);
        }
        _withPencil(canvas, (pencil) {
          canvas.drawRRect(pencil.inflate(1.3), _clear);
          canvas.drawRRect(pencil, p);
        });
      case BrandGlyph.bell:
        canvas.drawPath(
          Path()
            ..moveTo(5, 17)
            ..lineTo(5, 11)
            ..arcTo(
              Rect.fromCircle(center: const Offset(11, 11), radius: 6),
              math.pi,
              math.pi,
              false,
            )
            ..lineTo(17, 17)
            ..close(),
          p,
        );
        canvas.drawRRect(_rr(3, 16, 16, 3.2, 1.6), p);
        canvas.drawCircle(const Offset(11, 21), 1.8, p);
        paintSparkle(canvas, const Offset(20, 4.5), 3.4, p);
      case BrandGlyph.calendar:
        canvas.drawRRect(_rr(3, 4, 18, 17, 3.5), p);
        for (final x in [7.0, 14.4]) {
          final ring = _rr(x, 2, 2.6, 5, 1.3);
          canvas.drawRRect(ring.inflate(1), _clear);
          canvas.drawRRect(ring, p);
        }
        canvas.drawRRect(_rr(6, 10, 12, 2.4, 1.2), _clear);
        canvas.drawRRect(_rr(6, 14.6, 7, 2.4, 1.2), _clear);
      case BrandGlyph.verified:
        _drawRounded(
          canvas,
          Path()
            ..moveTo(12, 2)
            ..lineTo(19.5, 5)
            ..lineTo(19.5, 11.2)
            ..cubicTo(19.5, 15.8, 16.3, 19.6, 12, 21.5)
            ..cubicTo(7.7, 19.6, 4.5, 15.8, 4.5, 11.2)
            ..lineTo(4.5, 5)
            ..close(),
          c,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8.6, 11.8)
            ..lineTo(11, 14.2)
            ..lineTo(15.4, 9.6),
          _strokePaint(c, 2.3)..blendMode = BlendMode.clear,
        );
      case BrandGlyph.swap:
        canvas.drawRRect(_rr(3, 5.5, 14, 3.4, 1.7), p);
        _drawRounded(canvas, _triangle(15, 3.2, 20, 7.2, 15, 11.2), c);
        canvas.drawRRect(_rr(7, 15.1, 14, 3.4, 1.7), p);
        _drawRounded(canvas, _triangle(9, 12.8, 4, 16.8, 9, 20.8), c);
      case BrandGlyph.logout:
        canvas.drawRRect(_rr(3, 3, 10, 18, 3), p);
        final bar = _rr(9, 10.3, 9, 3.4, 1.7);
        final head = _triangle(17, 7, 21.5, 12, 17, 17);
        canvas.drawRRect(bar.inflate(1.4), _clear);
        canvas.drawPath(
          head,
          _strokePaint(c, 1.2 + 2.8)..blendMode = BlendMode.clear,
        );
        canvas.drawRRect(bar, p);
        _drawRounded(canvas, head, c);
    }
  }

  /// Fills [path] and traces it with a thin round-joined stroke, which
  /// softens its sharp corners to match the rounded bars.
  static void _drawRounded(Canvas canvas, Path path, Color c) {
    canvas.drawPath(path, _fillPaint(c));
    canvas.drawPath(path, _strokePaint(c, 1.2));
  }

  static Path _triangle(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2)
    ..lineTo(x3, y3)
    ..close();

  void _outline(Canvas canvas, Color c) {
    if (!glyph.isPage) return _solid(canvas, c);
    final p = _fillPaint(c);
    final s = _strokePaint(c);
    switch (glyph) {
      case BrandGlyph.forms:
        canvas.drawRRect(_rr(7.5, 3, 12, 15, 3), s);
        final front = _rr(4.5, 6, 12, 15, 3);
        canvas.drawRRect(front, _clear);
        canvas.drawRRect(front, s);
        canvas.drawRRect(_rr(7.5, 10, 6, 2, 1), p);
        canvas.drawRRect(_rr(7.5, 14, 4, 2, 1), p);
      case BrandGlyph.tracking:
        canvas.drawCircle(const Offset(12, 12), 8, s);
        canvas.drawPath(_check, _strokePaint(c, 2.2));
      case BrandGlyph.profile:
        canvas.drawCircle(const Offset(11, 8), 3.6, s);
        canvas.drawRRect(_rr(4.5, 14.5, 13, 6.5, 3.25), s);
        paintSparkle(canvas, const Offset(20, 5.5), 2.6, p);
      case BrandGlyph.create:
        canvas.drawRRect(_rr(4, 4, 12, 16, 3), s);
        canvas.drawRRect(_rr(7, 8, 6, 2, 1), p);
        canvas.drawRRect(_rr(7, 12, 4, 2, 1), p);
        paintSparkle(canvas, const Offset(19, 15), 5.6, _clear);
        paintSparkle(canvas, const Offset(19, 15), 4, p);
      case BrandGlyph.fill:
        canvas.drawRRect(_rr(4, 4, 12, 16, 3), s);
        canvas.drawRRect(_rr(7, 8, 6, 2, 1), p);
        canvas.drawRRect(_rr(7, 12, 4, 2, 1), p);
        _withPencil(canvas, (pencil) {
          canvas.drawRRect(pencil.inflate(1.3), _clear);
          canvas.drawRRect(pencil.deflate(0.5), _strokePaint(c, 1.8));
        });
      default:
    }
  }

  /// Thin silhouette strokes plus the glyph's key detail (ring, sparkle,
  /// pencil) at partial strength, drawn over [_solid].
  void _edges(Canvas canvas, Color c) {
    if (!glyph.isPage) return;
    const w = 0.7;
    final s = _strokePaint(c, w);
    final detail = _fillPaint(c.withValues(alpha: 0.4));
    switch (glyph) {
      case BrandGlyph.forms:
        canvas.drawRRect(_rr(7, 2.5, 13, 16, 3), s);
        final front = _rr(4, 5.5, 13, 16, 3);
        canvas.drawRRect(front.inflate(1.2), _clear);
        canvas.drawRRect(front, s);
        canvas.drawRRect(_rr(6.8, 9, 7.4, 2.2, 1.1), s);
        canvas.drawRRect(_rr(6.8, 13, 5, 2.2, 1.1), s);
      case BrandGlyph.tracking:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12), radius: 8),
          -math.pi / 2,
          math.pi * 2 * 0.72,
          false,
          _strokePaint(c.withValues(alpha: 0.4), 3.2),
        );
        // The ring is a 3.2-wide stroke, so its silhouette is two circles.
        canvas.drawCircle(const Offset(12, 12), 9.6, s);
        canvas.drawCircle(const Offset(12, 12), 6.4, s);
        // Same for the 2.4-wide check: a wide stroke with its middle cleared.
        canvas.drawPath(_check, _strokePaint(c, 2.4 + w));
        canvas.drawPath(
          _check,
          _strokePaint(c, 2.4 - w)..blendMode = BlendMode.clear,
        );
        canvas.drawPath(
          _check,
          _strokePaint(c.withValues(alpha: 0.4), 2.4 - w),
        );
      case BrandGlyph.profile:
        canvas.drawCircle(const Offset(11, 8), 4.2, s);
        canvas.drawRRect(_rr(3.5, 14, 15, 7.5, 3.75), s);
        paintSparkle(canvas, const Offset(20, 5.5), 3, detail);
      case BrandGlyph.create:
        canvas.drawRRect(_sheet, s);
        for (final l in _sheetLines) {
          canvas.drawRRect(l, s);
        }
        paintSparkle(canvas, const Offset(19, 15), 5.4, _clear);
        paintSparkle(canvas, const Offset(19, 15), 4, detail);
      case BrandGlyph.fill:
        canvas.drawRRect(_sheet, s);
        for (final l in _sheetLines) {
          canvas.drawRRect(l, s);
        }
        _withPencil(canvas, (pencil) {
          canvas.drawRRect(pencil.inflate(1.3), _clear);
          canvas.drawRRect(pencil, detail);
          canvas.drawRRect(pencil, s);
        });
      default:
    }
  }

  @override
  bool shouldRepaint(_BrandIconPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.fill != fill ||
      old.edgeColor != edgeColor;
}
