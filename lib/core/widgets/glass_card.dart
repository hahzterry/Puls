import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A glassmorphic surface: blurred backdrop + semi-transparent fill + hairline
/// border. Gives the UI depth over dark navy backgrounds.
///
/// Perf notes for Flutter Web / CanvasKit:
///   - BackdropFilter is expensive; this widget is intentionally simple (no
///     nested shadows, no clipped animations) so it composites in one pass.
///   - Place a [RepaintBoundary] around any animated sibling so the glass
///     doesn't re-rasterize when unrelated state changes.
///   - [elevation] is drawn as a subtle gradient rim, not a BoxShadow, to
///     avoid the saveLayer that shadows trigger under CanvasKit.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10,
    this.radius = 16,
    this.elevation = 0,
    this.borderAlpha = 0.12,
    this.fillAlpha = 0.05,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final double blur;
  final double radius;
  final double elevation;
  final double borderAlpha;
  final double fillAlpha;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    // On dark navy we tint the glass toward brand-mint for an icy neon edge;
    // on light we keep it neutral so it reads as frosted acrylic.
    final fill = isDark
        ? PulsColors.brandMint.withValues(alpha: fillAlpha)
        : Colors.white.withValues(alpha: fillAlpha);
    final border = isDark
        ? PulsColors.brandMint.withValues(alpha: borderAlpha)
        : Colors.white.withValues(alpha: borderAlpha * 1.6);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: 0.6),
              gradient: elevation > 0
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        fill,
                        t.surface.withValues(alpha: fillAlpha * 0.6),
                      ],
                    )
                  : null,
            ),
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          ),
        ),
      ),
    );
  }
}

/// A glass chip variant — smaller radius, tighter padding, for tags/badges.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.puls.brand;
    return GlassCard(
      radius: 10,
      blur: 6,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              fontFamily: PulsColors.fontSans,
            ),
          ),
        ],
      ),
    );
  }
}
