import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';
import '../shell/web_layout.dart';

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
    final t = context.puls;
    final categories = ['All', ...appState.categories];
    final markets = appState.markets.where((m) {
      final matchCat = _category == 'All' || m.category == _category;
      final matchQ = m.question.toLowerCase().contains(_query.toLowerCase()) ||
          m.context.toLowerCase().contains(_query.toLowerCase());
      return matchCat && matchQ;
    }).toList();

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  if (!kIsWeb) ...[
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ],
                  Text('Discover',
                      style: Theme.of(context).textTheme.displaySmall),
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.border),
                    ),
                    child: Icon(Icons.tune_rounded, color: t.textMuted, size: 17),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeIn(
              delay: const Duration(milliseconds: 80),
              child: TextField(
                style: TextStyle(color: t.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search markets…',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: t.textSubtle, size: 18),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 14),
            FadeIn(
              delay: const Duration(milliseconds: 120),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final sel = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? t.brand : t.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: sel ? t.brand : t.border),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: sel ? Colors.white : t.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeIn(
              delay: const Duration(milliseconds: 160),
              child: Row(
                children: [
                  Text('Trending now',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text('${markets.length} markets',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    final emptySliver = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyState(t: t),
      ),
    );

    final listSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList.builder(
        itemCount: markets.length,
        itemBuilder: (context, i) => FadeInUp(
          delay: Duration(milliseconds: 200 + i * 50),
          duration: const Duration(milliseconds: 350),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MarketCard(
              market: markets[i],
              t: t,
              isWatchlisted: appState.isWatchlisted(markets[i].id),
              onWatchlist: () => appState.toggleWatchlist(markets[i].id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MarketDetailScreen(marketId: markets[i].id),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gridSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.6,
        ),
        itemCount: markets.length,
        itemBuilder: (context, i) => _MarketCard(
          market: markets[i],
          t: t,
          isWatchlisted: appState.isWatchlisted(markets[i].id),
          onWatchlist: () => appState.toggleWatchlist(markets[i].id),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MarketDetailScreen(marketId: markets[i].id),
            ),
          ),
        ),
      ),
    );

    final scrollView = CustomScrollView(
      slivers: [
        header,
        if (markets.isEmpty)
          emptySliver
        else
          kIsWeb ? gridSliver : listSliver,
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: kIsWeb ? WebLayout(child: scrollView) : scrollView,
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.market,
    required this.t,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onTap,
  });

  final Market market;
  final PulsThemeColors t;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trendPositive = market.trendIsPositive;
    final trendColor = trendPositive ? PulsColors.green : PulsColors.red;
    final trendBg =
        trendPositive ? PulsColors.greenLight : PulsColors.redLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.brandSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    market.category,
                    style: TextStyle(
                      color: t.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onWatchlist,
                  child: Icon(
                    isWatchlisted
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_rounded,
                    size: 18,
                    color: isWatchlisted
                        ? PulsColors.amber
                        : t.textSubtle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(market.question,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PricePill(
                  label: 'Yes',
                  price: TradeMath.formatPrice(market.yesPrice),
                  bg: PulsColors.greenLight,
                  fg: PulsColors.green,
                ),
                const SizedBox(width: 8),
                _PricePill(
                  label: 'No',
                  price: TradeMath.formatPrice(market.noPrice),
                  bg: PulsColors.redLight,
                  fg: PulsColors.red,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trendBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${trendPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                    style: TextStyle(
                      color: trendColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({
    required this.label,
    required this.price,
    required this.bg,
    required this.fg,
  });
  final String label;
  final String price;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $price',
        style: TextStyle(
            color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: t.textSubtle, size: 32),
          const SizedBox(height: 12),
          Text('No markets found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Try another search or category.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
