import 'package:flutter/material.dart';

/// Sparse dot-grid backdrop used behind hero sections (landing + shell).
class DotGridPainter extends CustomPainter {
  const DotGridPainter({required this.color, this.radius = 0.75});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter old) =>
      old.color != color || old.radius != radius;
}
