import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Primary pill CTA with the "button-in-button" trailing icon chip:
/// the arrow lives inside its own circular well, flush with the pill's right
/// padding, and drifts diagonally on hover while the whole button presses
/// down 2% — kinetic tension inside a single control.
///
/// Motion is transform/opacity-only and collapses under reduce-motion.
class PulsButton extends StatefulWidget {
  const PulsButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon = Icons.arrow_outward_rounded,
    this.trailing = true,
    this.loading = false,
    this.enabled = true,
    this.glow = true,
    this.compact = false,
    this.gradient,
  });

  final String label;
  final VoidCallback? onTap;

  /// Hairline arrow glyph in the nested icon well.
  final IconData icon;
  final bool trailing;
  final bool loading;
  final bool enabled;

  /// Custom fill gradient; defaults to the brand pulse gradient.
  final LinearGradient? gradient;

  /// Neon glow halo on hover (dark theme).
  final bool glow;
  final bool compact;

  @override
  State<PulsButton> createState() => _PulsButtonState();
}

class _PulsButtonState extends State<PulsButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null && !widget.loading;

  void _down() {
    if (!_active) return;
    setState(() => _pressed = true);
  }

  void _up() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onTap?.call();
    hapticLight();
  }

  void _exit() {
    if (mounted) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    final padding = widget.compact ? 12.0 : 18.0;
    final chipSize = widget.compact ? 26.0 : 30.0;

    final chip = Container(
      width: chipSize,
      height: chipSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: widget.loading
          ? SizedBox(
              width: chipSize * 0.5,
              height: chipSize * 0.5,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : AnimatedScale(
              scale: reduce || !_hovered ? 1.0 : 1.08,
              duration: const Duration(milliseconds: 260),
              curve: PulsCurves.easeOutMagical,
              child: AnimatedSlide(
                offset: reduce || !_hovered ? Offset.zero : const Offset(0.08, -0.08),
                duration: const Duration(milliseconds: 260),
                curve: PulsCurves.easeOutMagical,
                child: Icon(widget.icon, size: chipSize * 0.55, color: Colors.white),
              ),
            ),
    );

    final button = AnimatedScale(
      scale: reduce || !_pressed ? 1.0 : 0.98,
      duration: const Duration(milliseconds: 140),
      curve: PulsCurves.easeOutMagical,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: PulsCurves.easeOutMagical,
        height: widget.compact ? 46 : 54,
        alignment: Alignment.center,
        padding: EdgeInsets.only(left: padding, right: widget.trailing ? padding - 4 : padding),
        decoration: BoxDecoration(
          gradient: widget.gradient ?? PulsColors.pulseGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: widget.glow && _hovered && !reduce
              ? [
                  BoxShadow(
                    color: PulsColors.brandPink.withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: PulsColors.brandMint.withValues(alpha: 0.22),
                    blurRadius: 40,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 13 : 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            if (widget.trailing) ...[
              SizedBox(width: padding - 6),
              chip,
            ],
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: _active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: _active ? (_) => setState(() => _hovered = true) : null,
      onExit: (_) {
        _hovered = false;
        _exit();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active ? (_) => _down() : null,
        onTapUp: _active ? (_) => _up() : null,
        onTapCancel: _exit,
        child: AnimatedOpacity(
          opacity: _active ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: button,
        ),
      ),
    );
  }
}
