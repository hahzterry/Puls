import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/rendering/swarm_painter.dart';
import '../../../core/theme/app_theme.dart';

/// Live background visualization of AI agents in the swarm and the x402
/// nanopayments flowing between them. Renders a [SwarmPainter] inside a
/// [RepaintBoundary] so it never triggers rebuilds of the surrounding page.
///
/// Performance (Flutter Web / CanvasKit):
///   - The painter is driven by a single repeating [AnimationController]; the
///     parent StatefulWidget never calls setState on tick — the painter's
///     `super(repaint: animation)` handles redraws.
///   - Wrapped in [RepaintBoundary] → the canvas is rasterized to its own
///     layer; scrolling the page or rebuilding siblings doesn't repaint it.
///   - Pulses are added/removed via an async timer (simulated for the demo);
///     in production these would be fed from the backend event bus.
class SwarmVisualizer extends StatefulWidget {
  const SwarmVisualizer({
    super.key,
    this.nodes,
    this.autoGeneratePulses = true,
    this.background,
  });

  /// If null, a default roster is used (good for a live background).
  final List<SwarmNode>? nodes;

  /// When true (default), generates demo pulses on a timer. Set to false
  /// if you're feeding real pulses via [addPulse].
  final bool autoGeneratePulses;

  /// Background color override; defaults to the theme's bg.
  final Color? background;

  /// Push a real x402 pulse into the visualization (for production wiring).
  // ignore: prefer_constructors_over_static_methods
  static void addPulse(BuildContext context, SwarmPulse pulse) {
    final state = context.findAncestorStateOfType<_SwarmVisualizerState>();
    state?._addPulse(pulse);
  }

  @override
  State<SwarmVisualizer> createState() => _SwarmVisualizerState();
}

class _SwarmVisualizerState extends State<SwarmVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<SwarmNode> _nodes;
  final List<SwarmPulse> _pulses = [];
  final SwarmRenderCache _cache = SwarmRenderCache();
  Timer? _pulseTimer;
  final math.Random _rnd = math.Random();

  static const _defaultRoster = [
    ('vega', 'Vega ⚡', 'trader'),
    ('cygnus', 'Cygnus 🛡️', 'trader'),
    ('orion', 'Orion 🌌', 'trader'),
    ('lyra', 'Lyra 🎵', 'trader'),
    ('sage', 'Sage 🔮', 'creator'),
    ('nova', 'Nova ✨', 'creator'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _nodes = (widget.nodes ?? _defaultRoster.map((r) {
      return SwarmNode(id: r.$1, label: r.$2, role: r.$3, balance: _rnd.nextDouble() * 10);
    }).toList());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = context.reduceMotion;
    if (reduceMotion) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
    if (widget.autoGeneratePulses && _pulseTimer == null && !reduceMotion) {
      _pulseTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        _spawnDemoPulse();
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _addPulse(SwarmPulse pulse) {
    if (!mounted) return;
    setState(() => _pulses.add(pulse));
  }

  void _spawnDemoPulse() {
    if (_nodes.length < 2) return;
    final fromIdx = _rnd.nextInt(_nodes.length);
    var toIdx = _rnd.nextInt(_nodes.length);
    while (toIdx == fromIdx) toIdx = _rnd.nextInt(_nodes.length);
    final from = _nodes[fromIdx];
    final to = _nodes[toIdx];
    final colors = [
      const Color(0xFF2DD4BF), // mint
      const Color(0xFFEC4899), // pink
      const Color(0xFFF59E0B), // amber
    ];
    setState(() {
      _pulses.add(SwarmPulse(
        from: from.id,
        to: to.id,
        amountUsdc: 0.01 + _rnd.nextDouble() * 0.5,
        color: colors[_rnd.nextInt(colors.length)],
        speed: 0.8 + _rnd.nextDouble() * 0.6,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: RepaintBoundary isolates the CanvasKit layer so the painter's
    // 60fps redraws never force sibling widgets to re-rasterize.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bg = widget.background ?? context.puls.bg;
          return ClipRect(
            child: CustomPaint(
              size: Size.infinite,
              painter: SwarmPainter(
                animation: _ctrl,
                nodes: _nodes,
                pulses: _pulses,
                cache: _cache,
                bgColor: bg,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wraps [child] with a [SwarmVisualizer] as a dimmed live background.
/// The foreground content sits on a translucent panel so the swarm stays
/// visible behind it — perfect for the hackathon demo landing/arena.
class SwarmBackground extends StatelessWidget {
  const SwarmBackground({
    super.key,
    required this.child,
    this.background,
  });

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.35,
            child: SwarmVisualizer(background: background),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
