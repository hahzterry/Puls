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
    final t = context.puls;
    final trendPositive = market.trendIsPositive;
    final trendColor = trendPositive ? PulsColors.green : PulsColors.red;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 20, color: t.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Market'),
        actions: [
          IconButton(
            icon: Icon(
              appState.isWatchlisted(market.id)
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_rounded,
              size: 20,
              color: appState.isWatchlisted(market.id)
                  ? PulsColors.amber
                  : t.textSubtle,
            ),
            onPressed: () => appState.toggleWatchlist(market.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: market.tags
                .map((tag) => _Tag(label: tag, t: t))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(market.question,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(market.context,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: t.textMuted)),
          const SizedBox(height: 20),
          _PricePanel(market: market, t: t),
          const SizedBox(height: 14),
          _Section(
            title: 'Probability',
            t: t,
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: trendPositive
                    ? PulsColors.greenLight
                    : PulsColors.redLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${trendPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                style: TextStyle(
                  color: trendColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            child: MarketChart(values: market.history, color: trendColor),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatTile(label: 'Volume', value: market.volume, t: t),
              _StatTile(label: 'Liquidity', value: market.liquidity, t: t),
              _StatTile(label: 'Category', value: market.category, t: t),
              _StatTile(
                  label: 'Deadline',
                  value: _fmtDate(market.deadline),
                  t: t),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Market updates',
            t: t,
            child: Column(
              children: market.news
                  .map((n) => _NewsRow(
                      source: n.source, title: n.title, age: n.age, t: t))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Comments',
            t: t,
            child: Column(
              children: market.comments
                  .map((c) => _CommentRow(comment: c, t: t))
                  .toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: BoxDecoration(
            color: t.bg,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TradeBtn(
                  label: 'Buy Yes',
                  price: TradeMath.formatPrice(market.yesPrice),
                  bg: PulsColors.greenLight,
                  fg: PulsColors.green,
                  onPressed: () => showTradePreviewSheet(
                    context: context,
                    market: market,
                    side: MarketSide.yes,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TradeBtn(
                  label: 'Buy No',
                  price: TradeMath.formatPrice(market.noPrice),
                  bg: PulsColors.redLight,
                  fg: PulsColors.red,
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
  const _PricePanel({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _PriceCell(
                  label: 'Yes',
                  price: TradeMath.formatPrice(market.yesPrice),
                  color: PulsColors.green),
              Container(width: 1, height: 44, color: t.border),
              _PriceCell(
                  label: 'No',
                  price: TradeMath.formatPrice(market.noPrice),
                  color: PulsColors.red),
            ],
          ),
          const SizedBox(height: 12),
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
      ),
    );
  }
}

class _PriceCell extends StatelessWidget {
  const _PriceCell(
      {required this.label, required this.price, required this.color});
  final String label;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(price,
                style: TextStyle(
                    color: color,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.t,
    required this.child,
    this.trailing,
  });
  final String title;
  final PulsThemeColors t;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium),
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
  const _StatTile(
      {required this.label, required this.value, required this.t});
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
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
    required this.t,
  });
  final String source;
  final String title;
  final String age;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.article_outlined, color: t.brand, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text('$source · $age',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.t});
  final MarketComment comment;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final isYes = comment.sentiment == MarketSide.yes;
    final color = isYes ? PulsColors.green : PulsColors.red;
    final bg = isYes ? PulsColors.greenLight : PulsColors.redLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: bg,
            child: Text(
              comment.author.isEmpty ? '?' : comment.author[0],
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.author,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(comment.text,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeBtn extends StatelessWidget {
  const _TradeBtn({
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
      height: 50,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('$label $price',
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
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
              color: t.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}

String _fmtDate(DateTime v) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${m[v.month - 1]} ${v.day}';
}
