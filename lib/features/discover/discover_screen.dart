import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final categories = ['All', ...appState.categories];
    final markets = appState.markets.where((market) {
      final matchesCategory = _category == 'All' || market.category == _category;
      final matchesQuery =
          market.question.toLowerCase().contains(_query.toLowerCase()) ||
              market.context.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search markets',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: categories.length,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Trending now', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('${markets.length} markets', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (markets.isEmpty)
            const _EmptyDiscover()
          else
            ...markets.map((market) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MarketListCard(
                  market: market,
                  isWatchlisted: appState.isWatchlisted(market.id),
                  onWatchlist: () => appState.toggleWatchlist(market.id),
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

class _MarketListCard extends StatelessWidget {
  const _MarketListCard({
    required this.market,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onTap,
  });

  final Market market;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trendColor = market.trendIsPositive ? PulsColors.green : PulsColors.coral;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PulsColors.panelSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PulsColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  market.category,
                  style: const TextStyle(
                    color: PulsColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onWatchlist,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isWatchlisted
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isWatchlisted ? PulsColors.amber : PulsColors.muted,
                  ),
                ),
              ],
            ),
            Text(market.question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniPrice(
                  label: 'Yes',
                  price: TradeMath.formatPrice(market.yesPrice),
                  color: PulsColors.green,
                ),
                const SizedBox(width: 8),
                _MiniPrice(
                  label: 'No',
                  price: TradeMath.formatPrice(market.noPrice),
                  color: PulsColors.coral,
                ),
                const Spacer(),
                Text(
                  '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                  style: TextStyle(color: trendColor, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPrice extends StatelessWidget {
  const _MiniPrice({
    required this.label,
    required this.price,
    required this.color,
  });

  final String label;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label $price',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsColors.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PulsColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: PulsColors.muted),
          const SizedBox(height: 8),
          Text('No markets found', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Try another search or category.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
