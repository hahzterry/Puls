import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final markets = appState.watchlistMarkets;

    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        children: [
          const _AlertsPanel(),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Saved markets',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('${markets.length} saved',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (markets.isEmpty)
            const _EmptyWatchlist()
          else
            ...markets.map((market) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WatchCard(
                  market: market,
                  onRemove: () => appState.toggleWatchlist(market.id),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MarketDetailScreen(marketId: market.id),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel();

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PulsColors.blue.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: PulsColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3 mock alerts armed',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'Price movement and deadline alerts are simulated.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({
    required this.market,
    required this.onRemove,
    required this.onTap,
  });

  final Market market;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    final trendColor =
        market.trendIsPositive ? PulsColors.green : PulsColors.coral;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.panelSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(market.question,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Yes ${TradeMath.formatPrice(market.yesPrice)}',
                        style: const TextStyle(
                          color: PulsColors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.bookmark_remove_rounded,
                  color: PulsColors.amber),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist();

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          Icon(Icons.bookmark_border_rounded, color: tokens.muted),
          const SizedBox(height: 8),
          Text('No saved markets',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap the bookmark on any market to watch it.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
