import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import 'market_chart.dart';
import 'trade_preview_sheet.dart';

class MarketDetailScreen extends StatelessWidget {
  const MarketDetailScreen({required this.marketId, super.key});

  final String marketId;

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final market = appState.marketById(marketId);
    final trendColor = market.trendIsPositive ? PulsColors.green : PulsColors.coral;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market'),
        actions: [
          IconButton(
            onPressed: () => appState.toggleWatchlist(market.id),
            icon: Icon(
              appState.isWatchlisted(market.id)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: appState.isWatchlisted(market.id)
                  ? PulsColors.amber
                  : PulsColors.muted,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: market.tags.map((tag) => _Tag(label: tag)).toList(),
            ),
            const SizedBox(height: 16),
            Text(market.question, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(market.context, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 18),
            _PricePanel(market: market),
            const SizedBox(height: 18),
            _Section(
              title: 'Probability',
              trailing: Text(
                '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                style: TextStyle(
                  color: trendColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: MarketChart(values: market.history, color: trendColor),
            ),
            const SizedBox(height: 14),
            _StatsGrid(market: market),
            const SizedBox(height: 14),
            _Section(
              title: 'Market updates',
              child: Column(
                children: market.news
                    .map((item) => _NewsRow(source: item.source, title: item.title, age: item.age))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Comments',
              child: Column(
                children: market.comments
                    .map((comment) => _CommentRow(comment: comment))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: _TradeButton(
                  label: 'Buy Yes',
                  price: TradeMath.formatPrice(market.yesPrice),
                  color: PulsColors.green,
                  onPressed: () => showTradePreviewSheet(
                    context: context,
                    market: market,
                    side: MarketSide.yes,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TradeButton(
                  label: 'Buy No',
                  price: TradeMath.formatPrice(market.noPrice),
                  color: PulsColors.coral,
                  onPressed: () => showTradePreviewSheet(
                    context: context,
                    market: market,
                    side: MarketSide.no,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({required this.market});

  final Market market;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PulsColors.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PulsColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PriceCell(
                label: 'Yes',
                price: TradeMath.formatPrice(market.yesPrice),
                color: PulsColors.green,
              ),
              Container(width: 1, height: 42, color: PulsColors.border),
              _PriceCell(
                label: 'No',
                price: TradeMath.formatPrice(market.noPrice),
                color: PulsColors.coral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 9,
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
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell({
    required this.label,
    required this.price,
    required this.color,
  });

  final String label;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.market});

  final Market market;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.45,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatTile(label: 'Volume', value: market.volume),
        _StatTile(label: 'Liquidity', value: market.liquidity),
        _StatTile(label: 'Category', value: market.category),
        _StatTile(label: 'Deadline', value: _formatDate(market.deadline)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PulsColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PulsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: PulsColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({
    required this.source,
    required this.title,
    required this.age,
  });

  final String source;
  final String title;
  final String age;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.article_outlined, color: PulsColors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 3),
                Text('$source - $age', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final MarketComment comment;

  @override
  Widget build(BuildContext context) {
    final color = comment.sentiment == MarketSide.yes
        ? PulsColors.green
        : PulsColors.coral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Text(
              comment.author.isEmpty ? '?' : comment.author[0],
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.author, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeButton extends StatelessWidget {
  const _TradeButton({
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
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: PulsColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('$label $price'),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}';
}
