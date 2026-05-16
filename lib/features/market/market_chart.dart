import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MarketChart extends StatelessWidget {
  const MarketChart({
    required this.values,
    required this.color,
    super.key,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(
        painter: _MarketChartPainter(values: values, color: color),
      ),
    );
  }
}

class _MarketChartPainter extends CustomPainter {
  const _MarketChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final gridPaint = Paint()
      ..color = PulsColors.border.withOpacity(0.55)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(0.01, maxValue - minValue);

    Offset pointFor(int index, double value) {
      final x = size.width * index / (values.length - 1);
      final normalized = (value - minValue) / range;
      final y = size.height - normalized * size.height;
      return Offset(x, y);
    }

    final path = Path()..moveTo(0, pointFor(0, values.first).dy);
    for (var i = 1; i < values.length; i++) {
      final point = pointFor(i, values[i]);
      path.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.24), color.withOpacity(0.00)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final last = pointFor(values.length - 1, values.last);
    canvas.drawCircle(
      last,
      8,
      Paint()
        ..color = color.withOpacity(0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(last, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
