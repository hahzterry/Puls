import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../../data/polymarket/price_history_service.dart';

class PredictionFeedCard extends StatefulWidget {
  const PredictionFeedCard({
    required this.market,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onDetails,
    required this.onChoose,
    super.key,
  });

  final Market market;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onDetails;
  final ValueChanged<MarketSide> onChoose;

  @override
  State<PredictionFeedCard> createState() => _PredictionFeedCardState();
}

class _PredictionFeedCardState extends State<PredictionFeedCard> {
  double _dragX = 0;
  List<double> _sparkline = [];

  @override
  void initState() {
    super.initState();
    PriceHistoryService.fetch(widget.market.clobTokenId).then((prices) {
      if (mounted) setState(() => _sparkline = prices);
    });
  }

  void _reset() {
    if (mounted) setState(() => _dragX = 0);
  }

  void _commit(MarketSide side) {
    _reset();
    widget.onChoose(side);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final market = widget.market;
    final progress = (_dragX.abs() / 140).clamp(0.0, 1.0);
    final side = _dragX >= 0 ? MarketSide.yes : MarketSide.no;
    final swipeColor = side == MarketSide.yes ? PulsColors.green : PulsColors.red;
    final hasImage = market.imageUrl.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) =>
          setState(() => _dragX = (_dragX + d.delta.dx).clamp(-180.0, 180.0)),
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_dragX > 82 || v > 700) {
          _commit(MarketSide.yes);
        } else if (_dragX < -82 || v < -700) {
          _commit(MarketSide.no);
        } else {
          _reset();
        }
      },
      onHorizontalDragCancel: _reset,
      child: Transform.translate(
        offset: Offset(_dragX, 0),
        child: Transform.rotate(
          angle: _dragX / 2400,
          child: Container(
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: progress > 0.1
                    ? swipeColor.withValues(alpha: progress * 0.5)
                    : t.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Swipe tint overlay
                if (progress > 0)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: progress * 0.08,
                      duration: const Duration(milliseconds: 60),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: swipeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                // Card content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top row: tags + swipe badge + bookmark
                      Row(
                              children: [
                                _Tag(label: market.category, t: t),
                                const SizedBox(width: 8),
                                _Tag(label: market.volume, t: t),
                                const Spacer(),
                                if (progress > 0.2)
                                  AnimatedOpacity(
                                    opacity: ((progress - 0.2) / 0.8)
                                        .clamp(0, 1),
                                    duration:
                                        const Duration(milliseconds: 80),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: swipeColor,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        side == MarketSide.yes
                                            ? 'YES'
                                            : 'NO',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: widget.onWatchlist,
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    size: 20,
                                    color: widget.isWatchlisted
                                        ? PulsColors.amber
                                        : t.textSubtle,
                                  ),
                                ),
                              ],
                            ),
                      // Image inside card — hidden to keep card compact
                      const SizedBox(height: 4),
                      const SizedBox(height: 12),
                      // Question
                            Text(
                              market.question,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium,
                              maxLines: hasImage ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!hasImage && market.context.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                market.context,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Odds bar
                            _OddsBar(market: market),
                            const SizedBox(height: 8),
                            // Sparkline — always 48px, shows shimmer while loading
                            SizedBox(
                              height: 48,
                              child: _sparkline.length >= 2
                                  ? _CardSparkline(
                                      prices: _sparkline,
                                      isUp: _sparkline.last >= _sparkline.first,
                                    )
                                  : DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: context.puls.surface,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            // Stats + details
                            Row(
                              children: [
                                _Stat(
                                  icon: Icons.trending_up_rounded,
                                  label: '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                                  color: market.trendIsPositive ? PulsColors.green : PulsColors.red,
                                ),
                                const SizedBox(width: 8),
                                if (market.volume24hr > 0)
                                  _Stat(
                                    icon: Icons.bar_chart_rounded,
                                    label: _fmtVol(market.volume24hr),
                                    color: t.textMuted,
                                  )
                                else
                                  _Stat(
                                    icon: Icons.water_drop_outlined,
                                    label: market.liquidity,
                                    color: t.textMuted,
                                  ),
                                if (market.spread > 0) ...[
                                  const SizedBox(width: 8),
                                  _Stat(
                                    icon: Icons.compare_arrows_rounded,
                                    label: 'Spread ${(market.spread * 100).toStringAsFixed(0)}¢',
                                    color: t.textMuted,
                                  ),
                                ],
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: widget.onDetails,
                                  child: Row(
                                    children: [
                                      Text('Details',
                                          style: TextStyle(
                                              color: t.brand,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 2),
                                      Icon(Icons.arrow_forward_rounded,
                                          size: 14, color: t.brand),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // YES / NO buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _SideBtn(
                                    label: 'YES',
                                    price: TradeMath.formatPrice(
                                        market.yesPrice),
                                    bg: PulsColors.greenLight,
                                    fg: PulsColors.green,
                                    onPressed: () =>
                                        widget.onChoose(MarketSide.yes),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SideBtn(
                                    label: 'NO',
                                    price: TradeMath.formatPrice(
                                        market.noPrice),
                                    bg: PulsColors.redLight,
                                    fg: PulsColors.red,
                                    onPressed: () =>
                                        widget.onChoose(MarketSide.no),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Swipe right for Yes · left for No',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.04, duration: 200.ms, curve: Curves.easeOut);
  }

  String _fmtVol(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _CardSparkline extends StatelessWidget {
  const _CardSparkline({required this.prices, required this.isUp});
  final List<double> prices;
  final bool isUp;

  @override
  Widget build(BuildContext context) {
    final color = isUp ? PulsColors.green : PulsColors.red;
    final spots = prices.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) < 0.01 ? 0.05 : (maxY - minY) * 0.2;

    return SizedBox(
      height: 48,
      child: LineChart(
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
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OddsBar extends StatelessWidget {
  const _OddsBar({required this.market});
  final Market market;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('Yes ${TradeMath.formatPrice(market.yesPrice)}',
                style: const TextStyle(
                    color: PulsColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const Spacer(),
            Text('No ${TradeMath.formatPrice(market.noPrice)}',
                style: const TextStyle(
                    color: PulsColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(
                  flex: (market.yesPrice * 100).round(),
                  child: const ColoredBox(color: PulsColors.green),
                ),
                Expanded(
                  flex: (market.noPrice * 100).round(),
                  child: const ColoredBox(color: PulsColors.red),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideBtn extends StatelessWidget {
  const _SideBtn({
    required this.label,
    required this.price,
    required this.bg,
    required this.fg,
    required this.onPressed,
  });
  final String label;
  final String price;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
            Text(price,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: fg.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.t});
  final String label;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(label,
          style: TextStyle(
              color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
