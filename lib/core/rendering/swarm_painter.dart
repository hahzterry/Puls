import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fast_trig.dart';

/// A node in the swarm graph — one AI agent.
class SwarmNode {
  SwarmNode({
    required this.id,
    required this.label,
    required this.role,
    this.balance = 0,
  });

  final String id;
  final String label;
  final String role; // 'trader' | 'creator'
  double balance;

  // Layout position (set by [SwarmPainter.layout] / the widget). Stored in
  // normalized 0..1 coordinates so the painter survives resize.
  double nx = 0.5;
  double ny = 0.5;
}

/// A directed payment pulse traveling from [from] → [to]. Spawned by x402
/// nanopayments (signal unlocks, tips, blog tips, streams).
class SwarmPulse {
  SwarmPulse({
    required this.from,
    required this.to,
    required this.amountUsdc,
    required this.color,
    this.speed = 1.0,
  });

  final String from;
  final String to;
  final double amountUsdc;
  final Color color;
  final double speed;

  double progress = 0; // 0..1 along the edge
  bool dead = false;
}

/// CustomPainter that renders the swarm as a live node graph with neon USDC
/// payment pulses traveling along the edges.
///
/// Perf design (Flutter Web / CanvasKit):
///   - All Paint objects are pre-allocated once in [SwarmRenderCache] and
///     mutated in-place — no per-frame Paint allocation.
///   - Geometry is recomputed only when the size or node set changes
///     ([_ensureGeometry] guards on size + node-count).
///   - Node positions use [FastTrig] (lookup table) instead of dart:math.sin.
///   - Pulses are drawn via [drawRawPoints] (Float32List) for the glow trail
///     and a single circle per pulse head.
///   - The painter subscribes directly to the animation via
///     `super(repaint: animation)` — no setState in the parent widget.
class SwarmPainter extends CustomPainter {
  SwarmPainter({
    required this.animation,
    required this.nodes,
    required this.pulses,
    required this.cache,
    this.bgColor = const Color(0xFF0A0E1A),
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<SwarmNode> nodes;
  final List<SwarmPulse> pulses;
  final SwarmRenderCache cache;
  final Color bgColor;

  // Brand palette
  static const _mint = Color(0xFF2DD4BF);
  static const _pink = Color(0xFFEC4899);
  static const _edgeDim = Color(0xFF1B2236);

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;
    cache.ensureGeometry(size, nodes);

    // ── Background fill (so the canvas isn't transparent) ──────────────
    canvas.drawRect(Offset.zero & size, cache.bgPaint..color = bgColor);

    final t = animation.value;

    // ── Advance pulse progress based on delta time ───────────────────
    // We approximate dt using the animation value's wrap-around (it
    // repeats 0..1 every 8s). Each pulse advances by its speed * dt.
    // Dead pulses are pruned.
    if (pulses.isNotEmpty) {
      final lastT = cache.lastT;
      var dt = t - lastT;
      if (dt < 0) dt += 1; // animation wrapped
      cache.lastT = t;
      final dtSec = dt * 8; // animation duration is 8s
      for (final p in pulses) {
        if (p.dead) continue;
        // Distance-based speed: ~0.15 progress/sec at speed=1.
        p.progress += p.speed * dtSec * 0.15;
        if (p.progress >= 1) p.dead = true;
      }
      pulses.removeWhere((p) => p.dead);
    }

    // ── Draw edges (faint connecting lines between adjacent nodes) ────
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      for (var j = i + 1; j < nodes.length; j++) {
        final b = nodes[j];
        // Only draw edges within a proximity band — keeps the graph readable
        // and avoids an O(n²) hairball.
        final dx = (a.nx - b.nx) * size.width;
        final dy = (a.ny - b.ny) * size.height;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > size.shortestSide * 0.45) continue;

        cache.edgePaint
          ..color = _edgeDim.withValues(alpha: 0.6)
          ..strokeWidth = 0.6;
        canvas.drawLine(
          Offset(a.nx * size.width, a.ny * size.height),
          Offset(b.nx * size.width, b.ny * size.height),
          cache.edgePaint,
        );
      }
    }

    // ── Draw pulses (neon USDC payments traveling along edges) ────────
    for (final p in pulses) {
      if (p.dead) continue;
      final fromIdx = nodes.indexWhere((n) => n.id == p.from);
      final toIdx = nodes.indexWhere((n) => n.id == p.to);
      if (fromIdx < 0 || toIdx < 0) {
        p.dead = true;
        continue;
      }
      final from = nodes[fromIdx];
      final to = nodes[toIdx];
      final fx = from.nx * size.width;
      final fy = from.ny * size.height;
      final tx = to.nx * size.width;
      final ty = to.ny * size.height;

      // Pulse head position.
      final px = fx + (tx - fx) * p.progress;
      final py = fy + (ty - fy) * p.progress;

      // Trailing glow: a few points behind the head, fading out.
      const trailLen = 6;
      for (var k = 0; k < trailLen; k++) {
        final back = p.progress - k * 0.02;
        if (back < 0) break;
        final bx = fx + (tx - fx) * back;
        final by = fy + (ty - fy) * back;
        final alpha = (1 - k / trailLen) * 0.7;
        cache.pulseGlowPaint
          ..color = p.color.withValues(alpha: alpha)
          ..strokeWidth = 2 + k * 0.3;
        canvas.drawCircle(Offset(bx, by), 2.5 - k * 0.25, cache.pulseGlowPaint);
      }

      // Bright head.
      cache.pulseHeadPaint
        ..color = p.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), 3.5, cache.pulseHeadPaint);

      // Outer halo.
      cache.pulseGlowPaint
        ..color = p.color.withValues(alpha: 0.3)
        ..strokeWidth = 0;
      canvas.drawCircle(Offset(px, py), 8, cache.pulseGlowPaint);
    }

    // ── Draw nodes (agents) ───────────────────────────────────────────
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final x = n.nx * size.width;
      final y = n.ny * size.height;
      final isCreator = n.role == 'creator';
      final nodeColor = isCreator ? _pink : _mint;
      final pulse = 1 + FastTrig.sinTurns(t + i * 0.17) * 0.12;
      final r = (isCreator ? 7 : 5.5) * pulse;

      // Outer glow.
      cache.nodeGlowPaint.color = nodeColor.withValues(alpha: 0.18);
      canvas.drawCircle(Offset(x, y), r * 2.4, cache.nodeGlowPaint);

      // Node fill.
      cache.nodeFillPaint
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), r, cache.nodeFillPaint);

      // Inner highlight (gives a 3D feel).
      cache.nodeInnerPaint.color = Colors.white.withValues(alpha: 0.4);
      canvas.drawCircle(Offset(x - r * 0.3, y - r * 0.3), r * 0.35, cache.nodeInnerPaint);

      // Label (only if there's room — keep canvas fast on web). The laid-out
      // TextPainter is cached per label; only the paint offset changes per frame.
      if (size.width > 280) {
        final tp = cache.labelPainter(n.label);
        tp.paint(canvas, Offset(x - tp.width / 2, y + r + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant SwarmPainter old) =>
      old.nodes != nodes || old.pulses != pulses || old.cache != cache;
}

/// Pre-allocated Paint objects + geometry cache for [SwarmPainter].
/// Reused across frames to avoid GC pressure under CanvasKit.
class SwarmRenderCache {
  SwarmRenderCache() {
    // Lay out nodes in a loose orbit + center cluster pattern.
  }

  final Paint bgPaint = Paint();
  final Paint edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint pulseHeadPaint = Paint()..style = PaintingStyle.fill;
  final Paint pulseGlowPaint = Paint()..style = PaintingStyle.fill;
  final Paint nodeFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint nodeGlowPaint = Paint()..style = PaintingStyle.fill;
  final Paint nodeInnerPaint = Paint()..style = PaintingStyle.fill;

  Size _size = Size.zero;
  int _nodeCount = -1;
  double lastT = 0; // for delta-time pulse advancement

  // Node labels are static per node (only their paint offset moves every
  // frame). TextPainter.layout() — glyph shaping — is expensive, so cache one
  // laid-out painter per label instead of rebuilding it on every animation
  // frame. Label strings are bounded (agent names), so this map stays tiny.
  final Map<String, TextPainter> _labelPainters = {};

  TextPainter labelPainter(String label) {
    final cached = _labelPainters[label];
    if (cached != null) return cached;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'DM Sans',
          letterSpacing: 0.3,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    _labelPainters[label] = tp;
    return tp;
  }

  /// Position nodes in an orbital layout: creators on an inner ring,
  /// traders on an outer ring. Stable across frames (no jittering).
  void ensureGeometry(Size size, List<SwarmNode> nodes) {
    if (_size == size && _nodeCount == nodes.length) return;
    _size = size;
    _nodeCount = nodes.length;

    final creators = nodes.where((n) => n.role == 'creator').toList();
    final traders = nodes.where((n) => n.role != 'creator').toList();

    const cx = 0.5;
    const cy = 0.5;
    const innerR = 0.18;
    const outerR = 0.36;

    for (var i = 0; i < creators.length; i++) {
      final angle = (i / creators.length) * math.pi * 2 - math.pi / 2;
      creators[i].nx = cx + FastTrig.cosRadians(angle) * innerR;
      creators[i].ny = cy + FastTrig.sinRadians(angle) * innerR;
    }
    for (var i = 0; i < traders.length; i++) {
      final angle = (i / traders.length) * math.pi * 2 - math.pi / 2 + 0.3;
      traders[i].nx = cx + FastTrig.cosRadians(angle) * outerR;
      traders[i].ny = cy + FastTrig.sinRadians(angle) * outerR;
    }
  }
}
