import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import '../app/puls_app_state.dart';

/// Accessibility helper for honoring the platform "reduce motion" setting.
///
/// iOS *Reduce Motion*, Android *Remove animations*, macOS/Windows reduce-motion
/// and several browsers surface this through `MediaQueryData.disableAnimations`.
/// Decorative loops (shimmer, pulsing halos, confetti) and value tweens should
/// collapse to their end state when this is on — never trap motion-sensitive
/// users in perpetual animation.
/// An InheritedWidget to override the platform/app "reduce motion" setting.
/// When wrapped around a widget tree, [PulsMotion.reduceMotion] will return `false`.
class OverrideReduceMotion extends InheritedWidget {
  const OverrideReduceMotion({
    super.key,
    required super.child,
  });

  static bool shouldOverride(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OverrideReduceMotion>() != null;
  }

  @override
  bool updateShouldNotify(OverrideReduceMotion oldWidget) => false;
}

/// Accessibility helper for honoring the platform "reduce motion" setting.
///
/// iOS *Reduce Motion*, Android *Remove animations*, macOS/Windows reduce-motion
/// and several browsers surface this through `MediaQueryData.disableAnimations`.
/// Decorative loops (shimmer, pulsing halos, confetti) and value tweens should
/// collapse to their end state when this is on — never trap motion-sensitive
/// users in perpetual animation.
extension PulsMotion on BuildContext {
  /// True when motion should be minimized. Off by default — motion is enabled;
  /// only an explicit in-app override (Settings → Reduce motion) turns it on.
  bool get reduceMotion =>
      !OverrideReduceMotion.shouldOverride(this) &&
      (PulsAppState.instance?.reduceMotionOverride ??
          PulsStateScope.maybeOf(this)?.reduceMotionOverride ??
          false);

  /// [normal] unless reduce-motion is on, in which case [Duration.zero] so
  /// implicit animations resolve instantly.
  Duration motionDuration(Duration normal) =>
      reduceMotion ? Duration.zero : normal;
}

// ── AgentBond dramatic effects ───────────────────────────────────────────────
//
// Two one-shot effects for when an AI agent wins or loses USDC:
//
//   • GlitchEffect     — an RGB-split + jitter flash fired when an agent WINS
//     (bond returned or a winning call). Celebratory neon energy.
//
//   • CameraShake      — a translated-container shake fired when an agent is
//     SLASHED (bond lost). Impacts the whole viewport via triggerCameraShake().
//
// Both honor reduce-motion: they collapse to a no-op so motion-sensitive
// viewers see the result without the dramatic animation.

/// One-shot RGB-split glitch overlay. Wrap the celebratory content; set
/// [play] to true to fire. Auto-resets when [play] returns to false.
class GlitchEffect extends StatefulWidget {
  const GlitchEffect({
    super.key,
    required this.child,
    required this.play,
    this.color = const Color(0xFF2DD4BF),
    this.duration = const Duration(milliseconds: 900),
  });

  final Widget child;
  final bool play;
  final Color color;
  final Duration duration;

  @override
  State<GlitchEffect> createState() => _GlitchEffectState();
}

class _GlitchEffectState extends State<GlitchEffect>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  bool _fired = false;
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
    if (widget.play) _fire();
  }

  @override
  void didUpdateWidget(covariant GlitchEffect old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _fire();
    if (!widget.play && old.play) _reset();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    if (_reduceMotion == true) return;
    _ctrl ??= AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _fired = false);
        }
      });
    _ctrl!.forward(from: 0);
  }

  void _reset() {
    _ctrl?.stop();
    if (mounted) setState(() => _fired = false);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_fired || _reduceMotion == true) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final t = _ctrl!.value;
        // Decaying jitter: strong at start, fades to zero.
        final decay = (1 - t).clamp(0.0, 1.0);
        final jitter = (math.sin(t * 38) + math.cos(t * 27)) * 3 * decay;
        // RGB split distance peaks early then resolves.
        final split = 4 * decay;
        return Stack(
          children: [
            Transform.translate(
              offset: Offset(-split + jitter, 0),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  widget.color.withValues(alpha: 0.5 * decay),
                  BlendMode.srcIn,
                ),
                child: child,
              ),
            ),
            Transform.translate(
              offset: Offset(split - jitter, 0),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  const Color(0xFFEC4899).withValues(alpha: 0.5 * decay),
                  BlendMode.srcIn,
                ),
                child: child,
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Wraps a subtree and exposes a [triggerCameraShake] method via its state.
/// Use [CameraShake.of] to grab the state from anywhere in the subtree, then
/// call `shake()` when an agent bond is slashed.
///
/// Place this high in the tree (above the Scaffold body) so the shake
/// displaces the visible viewport.
class CameraShake extends StatefulWidget {
  const CameraShake({super.key, required this.child});

  final Widget child;

  static _CameraShakeState? of(BuildContext context) {
    return context.findAncestorStateOfType<_CameraShakeState>();
  }

  @override
  State<CameraShake> createState() => _CameraShakeState();
}

class _CameraShakeState extends State<CameraShake>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  bool _reduceMotion = false;
  double _intensity = 14;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = context.reduceMotion;
  }

  /// Fire the shake. Safe to call repeatedly — re-triggers from the start.
  /// [intensity] scales the displacement in logical pixels (default 14).
  void shake({double intensity = 14}) {
    if (_reduceMotion) return;
    _ctrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {}); // rebuild back to identity
      }
    });
    // Decaying sinusoidal shake: high-frequency, fading amplitude. The offset
    // is computed directly from `_ctrl.value` in the builder below.
    _intensity = intensity;
    if (mounted) setState(() {});
    _ctrl!.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null || !_ctrl!.isAnimating) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final t = _ctrl!.value;
        final decay = (1 - t).clamp(0.0, 1.0);
        // ~5 oscillations across the duration, decaying.
        final dx = math.sin(t * math.pi * 10) * _intensity * decay;
        final dy = math.cos(t * math.pi * 8) * _intensity * decay * 0.7;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Convenience: trigger a CameraShake wrapping the current context.
/// Returns true if a shake was triggered, false if none found / reduce-motion.
bool triggerCameraShake(BuildContext context, {double intensity = 14}) {
  final state = CameraShake.of(context);
  if (state == null) return false;
  state.shake(intensity: intensity);
  return true;
}
