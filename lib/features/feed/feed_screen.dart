import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import 'prediction_feed_card.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final markets = appState.feedMarkets;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _FeedHeader(),
            Expanded(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: markets.length,
                itemBuilder: (context, index) {
                  final market = markets[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: PredictionFeedCard(
                      market: market,
                      isWatchlisted: appState.isWatchlisted(market.id),
                      onWatchlist: () => appState.toggleWatchlist(market.id),
                      onDetails: () => _openDetails(context, market),
                      onChoose: (side) => showTradePreviewSheet(
                        context: context,
                        market: market,
                        side: side,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Market market) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketDetailScreen(marketId: market.id),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PulsColors.blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PulsColors.blue.withValues(alpha: 0.5)),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: PulsColors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puls Feed', style: Theme.of(context).textTheme.titleMedium),
              Text(
                'Swipe markets. Choose your side.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: PulsColors.panelSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PulsColors.border),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                color: PulsColors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
