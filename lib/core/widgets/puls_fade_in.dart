import 'package:flutter/material.dart';

import '../motion.dart';

/// A single, lightweight entrance animation for list items.
///
/// Fades + slides the child in ONCE when the widget first mounts. Unlike
/// wrapping every item in `flutter_animate`, this owns an explicit
/// [AnimationController] that is disposed with the element — so a recycled
/// list slot never inherits a stale half-finished animation (which left
/// feed cards invisible). Honors reduce-motion (renders the child as-is).
class PulsFadeIn extends StatefulWidget {
  const PulsFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.slideOffset = 0.05,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration duration;
  final double slideOffset;
  final Curve curve;

  @override
  State<PulsFadeIn> createState() => _PulsFadeInState();
}

class _PulsFadeInState extends State<PulsFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    if (!context.reduceMotion) {
      // Jump straight to the end so the child is fully visible immediately;
      // then animate to it anyway is a no-op. Reduce-motion = static child.
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.slideOffset),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
