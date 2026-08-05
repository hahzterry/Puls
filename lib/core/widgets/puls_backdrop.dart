import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// App-wide background texture: deep canvas + radial mesh-glow orbs +
/// a fixed film-grain overlay.
///
/// - Orbs are painted as radial gradients (no blur filters on scrolling
///   content — pure gradient shaders, GPU-cheap).
/// - The grain tile is rendered ONCE into a [ui.Image] and cached; the
///   [RepaintBoundary] keeps it from ever repainting.
/// - Everything is behind the content ([IgnorePointer]) and static, so
///   reduce-motion is unaffected.
class PulsBackdrop extends StatelessWidget {
  const PulsBackdrop({
    super.key,
    required this.child,
    this.orbs = true,
    this.grain = true,
  });

  final Widget child;
  final bool orbs;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(color: t.bg)),
        if (orbs) ...[
          _Orb(
            size: 680,
            top: -260,
            left: -220,
            color: PulsColors.brandMint,
            alpha: isDark ? 0.055 : 0.05,
          ),
          _Orb(
            size: 720,
            bottom: -300,
            right: -240,
            color: PulsColors.brandPinkDark,
            alpha: isDark ? 0.05 : 0.045,
          ),
          _Orb(
            size: 560,
            alignment: const Alignment(0.15, 0.85),
            color: const Color(0xFF6366F1),
            alpha: isDark ? 0.035 : 0.03,
            fractional: true,
          ),
        ],
        if (grain) const FilmGrain(),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.color,
    required this.alpha,
    this.top,
    this.left,
    this.bottom,
    this.right,
    this.fractional = false,
    this.alignment = Alignment.center,
  });

  final double size;
  final Color color;
  final double alpha;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final bool fractional;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final orb = FractionallySizedBox(
      widthFactor: fractional ? 0.5 : null,
      heightFactor: fractional ? 0.5 : null,
      child: Container(
        width: fractional ? null : size,
        height: fractional ? null : size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            radius: 0.5,
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
    return fractional
        ? Positioned.fill(
            child: Align(alignment: alignment, child: orb),
          )
        : Positioned(
            top: top, left: left, bottom: bottom, right: right, child: orb);
  }
}

/// Fixed film-grain overlay — a 128px noise tile rendered once and tiled.
/// Drop it into any Stack that needs a physical paper/film texture.
class FilmGrain extends StatefulWidget {
  const FilmGrain({super.key});

  @override
  State<FilmGrain> createState() => _FilmGrainState();
}

class _FilmGrainState extends State<FilmGrain> {
  ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rnd = math.Random(1337);
    final paint = Paint();
    for (int i = 0; i < 1800; i++) {
      final x = rnd.nextDouble() * 128;
      final y = rnd.nextDouble() * 128;
      final a = rnd.nextDouble() * 0.55 + 0.05;
      paint.color = Colors.white.withValues(alpha: a * 0.5);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(128, 128);
    picture.dispose();
    if (!mounted) return;
    setState(() => _tile = image);
  }

  @override
  void dispose() {
    _tile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile;
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _GrainPainter(
              tile: tile,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.tile, required this.isDark});

  final ui.Image? tile;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tile;
    if (t == null) return;
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.028)
          : Colors.black.withValues(alpha: 0.025);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final tileRect = Rect.fromLTWH(0, 0, t.width.toDouble(), t.height.toDouble());
    canvas.drawImageRect(t, tileRect, rect, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.tile != tile || old.isDark != isDark;
}
