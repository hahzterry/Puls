import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The single sparkline used across the app (feed, discover, home).
///
/// A hand-rolled `CustomPainter` — not fl_chart — so we own every pixel:
///  • a Catmull-Rom spline (turned into cubic Béziers) gives a genuinely
///    smooth, flowing curve even for sparse daily samples, never a jagged
///    polyline or a string of dots
///  • theme-aware YES/NO stroke with a gradient area fill
///  • a single soft dot on the last point only
class PulsSparkline extends StatelessWidget {
  const PulsSparkline({
    super.key,
    required this.prices,
    required this.color,
    this.height,
    this.strokeWidth = 2,
    this.showLastDot = true,
    this.fillAlpha = 0.22,
  });

  final List<double> prices;
  final Color color;

  /// Total widget height. When `null` the sparkline fills the available space
  /// (e.g. inside an `Expanded` in a grid card). Defaults to 48px otherwise.
  final double? height;
  final double strokeWidth;

  /// Highlights the most recent point with a dot + soft ring.
  final bool showLastDot;

  /// Max opacity of the gradient fill under the line.
  final double fillAlpha;

  @override
  Widget build(BuildContext context) {
    final surface = context.puls.surface;

    final painter = _SparklinePainter(
      prices: prices,
      color: color,
      surface: surface,
      strokeWidth: strokeWidth,
      showLastDot: showLastDot,
      fillAlpha: fillAlpha,
    );

    if (height == null) {
      // Fill the available space (e.g. inside an Expanded grid cell). If the
      // incoming height is unbounded (a plain Column row), falling back to a
      // fixed height avoids a RenderFlex infinite-height crash.
      return LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : _fallbackHeight;
          return SizedBox(
            height: h,
            width: double.infinity,
            child: RepaintBoundary(child: CustomPaint(painter: painter)),
          );
        },
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(child: CustomPaint(painter: painter)),
    );
  }

  static const _fallbackHeight = 48.0;
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.prices,
    required this.color,
    required this.surface,
    required this.strokeWidth,
    required this.showLastDot,
    required this.fillAlpha,
  });

  final List<double> prices;
  final Color color;
  final Color surface;
  final double strokeWidth;
  final bool showLastDot;
  final double fillAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2 || size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;

    // ── Normalize Y so the line fills most of the box ─────────────────────
    var minY = prices[0];
    var maxY = prices[0];
    for (final p in prices) {
      if (p < minY) minY = p;
      if (p > maxY) maxY = p;
    }
    final range = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
    // Slight vertical inset (10% top/bottom) so the curve never touches the
    // box edges.
    final usableH = h * 0.8;
    final yOffset = h * 0.1;

    // Map each sample to a point.
    final pts = <Offset>[];
    for (var i = 0; i < prices.length; i++) {
      final x = i * (w / (prices.length - 1));
      final norm = (prices[i] - minY) / range;
      final y = h - (norm * usableH + yOffset);
      pts.add(Offset(x, y));
    }

    // ── Build a smooth Catmull-Rom path (cubic Béziers) ──────────────────
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      // Straight line between two points is already as smooth as it gets.
      path.lineTo(pts.last.dx, pts.last.dy);
    } else {
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i > 0 ? i - 1 : i];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];

        // Catmull-Rom → cubic Bézier control points.
        final c1 = Offset(
          p1.dx + (p2.dx - p0.dx) / 6,
          p1.dy + (p2.dy - p0.dy) / 6,
        );
        final c2 = Offset(
          p2.dx - (p3.dx - p1.dx) / 6,
          p2.dy - (p3.dy - p1.dy) / 6,
        );
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }
    }

    // ── Gradient area fill under the line ────────────────────────────────
    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, h)
      ..lineTo(pts.first.dx, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: fillAlpha),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // ── The line itself ──────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // ── Soft end dot (last point only) ───────────────────────────────────
    if (showLastDot) {
      final end = pts.last;
      canvas.drawCircle(
        end,
        5.0,
        Paint()..color = color.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        end,
        3.0,
        Paint()..color = color,
      );
      canvas.drawCircle(
        end,
        3.0,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = surface,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.prices != prices ||
      old.color != color ||
      old.surface != surface ||
      old.strokeWidth != strokeWidth ||
      old.showLastDot != showLastDot ||
      old.fillAlpha != fillAlpha;
}
