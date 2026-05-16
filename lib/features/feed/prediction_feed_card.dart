import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';

class PredictionFeedCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final trendColor = market.trendIsPositive ? PulsColors.green : PulsColors.coral;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PulsColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PulsColors.border),
        boxShadow: [
          BoxShadow(
            color: PulsColors.blue.withOpacity(0.10),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PulsColors.panelElevated,
                      PulsColors.panel,
                      PulsColors.ink.withOpacity(0.96),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Tag(label: market.category),
                      const SizedBox(width: 8),
                      _Tag(label: market.volume),
                      const Spacer(),
                      IconButton(
                        onPressed: onWatchlist,
                        tooltip: isWatchlisted ? 'Remove watch' : 'Add watch',
                        icon: Icon(
                          isWatchlisted
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isWatchlisted
                              ? PulsColors.amber
                              : PulsColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    market.question,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    market.context,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: PulsColors.muted,
                        ),
                  ),
                  const SizedBox(height: 18),
                  _OddsBar(market: market),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Signal(
                        icon: Icons.trending_up_rounded,
                        label:
                            '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                        color: trendColor,
                      ),
                      const SizedBox(width: 10),
                      _Signal(
                        icon: Icons.water_drop_outlined,
                        label: 'Liq ${market.liquidity}',
                        color: PulsColors.cyan,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onDetails,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Details'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SideButton(
                          label: 'YES',
                          price: TradeMath.formatPrice(market.yesPrice),
                          color: PulsColors.green,
                          onPressed: () => onChoose(MarketSide.yes),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SideButton(
                          label: 'NO',
                          price: TradeMath.formatPrice(market.noPrice),
                          color: PulsColors.coral,
                          onPressed: () => onChoose(MarketSide.no),
                        ),
                      ),
                    ],
                  ),
                ],
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
            Text(
              'Yes ${TradeMath.formatPrice(market.yesPrice)}',
              style: const TextStyle(
                color: PulsColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              'No ${TradeMath.formatPrice(market.noPrice)}',
              style: const TextStyle(
                color: PulsColors.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (market.yesPrice * 100).round(),
                  child: Container(color: PulsColors.green),
                ),
                Expanded(
                  flex: (market.noPrice * 100).round(),
                  child: Container(color: PulsColors.coral),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.price,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String price;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color.withOpacity(0.16),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.66)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: PulsColors.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PulsColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PulsColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
