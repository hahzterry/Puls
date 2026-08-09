import 'package:flutter/material.dart';

import '../motion.dart';

/// Paints [text] with the brand mint→pink gradient that slowly *flows*
/// horizontally — the signature Puls accent. Collapses to a static gradient
/// under reduce-motion. App-wide reusable (landing, headers, hero numbers…).
///
/// Perf: the gradient config is a single const and the slide is done by
/// shifting the shader bounds (no per-frame GradientTransform allocation),
/// and the resulting shader is cached by (bounds, offset) — so
/// static/reduce-motion instances build their shader exactly once instead of
/// once per animation tick.
class AnimatedGradientText extends StatefulWidget {
  const AnimatedGradientText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.animate = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool animate;

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Repeated mint→pink→mint so the sweep loops seamlessly.
  static const _colors = [
    Color(0xFF34E5C0),
    Color(0xFFF65FA9),
    Color(0xFF34E5C0),
  ];

  // ── Per-frame allocation budget ──────────────────────────────────────────
  // The gradient config is a single const — no per-frame LinearGradient or
  // GradientTransform objects. The slide is achieved by shifting the shader
  // bounds by -width*t (visually identical to a GradientTransform slide, but
  // with zero per-frame allocations).
  static const _gradient = LinearGradient(
    colors: _colors,
    tileMode: TileMode.mirror,
  );

  // Shader cache keyed by (bounds, slide offset). While the animation moves
  // the offset changes every tick, so the shader must be re-derived each
  // frame — but static/reduce-motion instances (offset fixed at 0) create
  // their shader exactly once instead of once per tick, and a bounds change
  // (font/scale) also triggers a single rebuild rather than a fresh shader
  // on every tick.
  Rect? _lastRect;
  double _lastT = -1;
  Shader? _cachedShader;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Shader _shaderFor(Rect bounds, double t) {
    final cached = _cachedShader;
    if (cached != null && _lastRect == bounds && _lastT == t) {
      return cached;
    }
    // Slide by shifting the shader bounds instead of a per-frame transform:
    // same visual, zero allocation beyond the shader itself.
    final shader =
        _gradient.createShader(bounds.shift(Offset(-bounds.width * t, 0)));
    _cachedShader = shader;
    _lastRect = bounds;
    _lastT = t;
    return shader;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion || !widget.animate;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // Read the offset inside the builder — this closure is re-invoked
          // on every tick, while the outer build() only runs on rebuilds.
          final t = reduce ? 0.0 : _c.value;
          return ShaderMask(
            shaderCallback: (r) => _shaderFor(r, t),
            child: child,
          );
        },
        child: Text(
          widget.text,
          textAlign: widget.textAlign,
          style: (widget.style ?? const TextStyle()).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
