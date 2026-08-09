import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MarketChart extends StatefulWidget {
  const MarketChart({
    required this.values,
    required this.color,
    super.key,
  });

  final List<double> values;
  final Color color;

  @override
  State<MarketChart> createState() => _MarketChartState();
}

class _MarketChartState extends State<MarketChart> {
  // Memoized spots: rebuilt only when the values actually change, instead of
  // on every parent rebuild.
  late List<FlSpot> _spots;

  @override
  void initState() {
    super.initState();
    _spots = _buildSpots(widget.values);
  }

  @override
  void didUpdateWidget(MarketChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.values, widget.values) &&
        !listEquals(oldWidget.values, widget.values)) {
      _spots = _buildSpots(widget.values);
    }
  }

  List<FlSpot> _buildSpots(List<double> values) => values
      .asMap()
      .entries
      .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
      .toList();

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    final spots = _spots;

    // Draw-in reveal: the line sweeps in from the left on first build. A
    // ClipRect-based reveal (instead of a ShaderMask with BlendMode.dstIn)
    // costs nothing once the reveal completes — a full-size clip is a no-op,
    // whereas a ShaderMask re-runs its shader callback on every repaint.
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.values.length),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, reveal, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: reveal,
          child: child,
        ),
      ),
      child: _chart(tokens, spots),
    );
  }

  Widget _chart(PulsThemeColors tokens, List<FlSpot> spots) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (_) => FlLine(
              color: tokens.border.withValues(alpha: 0.55),
              strokeWidth: 1,
            ),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: widget.color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: widget.color.withValues(alpha: 0.16),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
