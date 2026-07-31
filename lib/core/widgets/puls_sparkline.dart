import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_theme.dart';

/// The single sparkline used across the app (feed, discover, home, terminal).
///
/// Unifies three prior hand-rolled implementations so every mini-chart shares
/// the same curve, gradient fill, end-point dot and optional glow:
///  • normalized Y range (with padding) so flat or short series still render
///  • smooth quadratic curve
///  • theme-aware YES/NO stroke with a gradient area fill
///  • a highlighted last-point dot with a soft glow (adds "live" polish)
/// Honors reduce-motion by skipping the drawing animation.
class PulsSparkline extends StatelessWidget {
  const PulsSparkline({
    super.key,
    required this.prices,
    required this.color,
    this.height = 48,
    this.strokeWidth = 2,
    this.smoothness = 0.3,
    this.showLastDot = true,
    this.animate = true,
  });

  final List<double> prices;
  final Color color;

  /// Total widget height (line fills the whole box).
  final double height;
  final double strokeWidth;
  final double smoothness;

  /// Highlights the most recent point with a dot + glow.
  final bool showLastDot;

  /// Plays a subtle draw-in reveal (skipped under reduce-motion).
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (prices.length < 2) {
      return SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: context.puls.surface,
          ),
        ),
      );
    }

    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) < 0.01 ? 0.05 : (maxY - minY) * 0.2;
    final spots = prices
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final lastIndex = spots.length - 1;

    // Sparse series (few daily samples) need a softer curve to read as a
    // flowing line rather than a jagged polyline. Dense series keep the
    // default smoothness so they don't overshoot.
    final effectiveSmoothness =
        spots.length < 8 ? (smoothness + 0.15).clamp(0.0, 0.6) : smoothness;

    final chart = LineChart(
      duration: (!animate || context.reduceMotion)
          ? Duration.zero
          : const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      LineChartData(
        minY: (minY - pad).clamp(0, 1),
        maxY: (maxY + pad).clamp(0, 1),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: effectiveSmoothness,
            preventCurveOverShooting: true,
            color: color,
            barWidth: strokeWidth,
            // A dot ONLY on the final point. fl_chart's getDotPainter runs for
            // every spot when show:true, so without this guard a short series
            // renders as a string of circles instead of a smooth line.
            dotData: FlDotData(
              show: showLastDot,
              getDotPainter: (spot, percent, bar, index) {
                if (index != lastIndex) {
                  return FlDotCirclePainter(radius: 0);
                }
                return FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: context.puls.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: height,
      child: RepaintBoundary(child: chart),
    );
  }
}
