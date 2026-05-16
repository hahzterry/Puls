import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';
import '../../data/models/position.dart';
import '../market/market_detail_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final positions = appState.positions;
    final totalValue = positions.fold<double>(
      0,
      (sum, position) => sum + position.marketValue,
    );
    final totalPnl = positions.fold<double>(0, (sum, position) => sum + position.pnl);

    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        children: [
          _PortfolioHero(totalValue: totalValue, totalPnl: totalPnl),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Positions', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('${positions.length} open', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (positions.isEmpty)
            const _EmptyPortfolio()
          else
            ...positions.map((position) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PositionCard(
                  position: position,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MarketDetailScreen(
                          marketId: position.marketId,
                        ),
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

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({required this.totalValue, required this.totalPnl});

  final double totalValue;
  final double totalPnl;

  @override
  Widget build(BuildContext context) {
    final pnlColor = totalPnl >= 0 ? PulsColors.green : PulsColors.coral;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PulsColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PulsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo portfolio value', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            '\$${totalValue.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                totalPnl >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: pnlColor,
              ),
              const SizedBox(width: 6),
              Text(
                '${totalPnl >= 0 ? '+' : ''}\$${totalPnl.toStringAsFixed(2)} all time',
                style: TextStyle(color: pnlColor, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position, required this.onTap});

  final Position position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sideColor =
        position.side == MarketSide.yes ? PulsColors.green : PulsColors.coral;
    final pnlColor = position.pnl >= 0 ? PulsColors.green : PulsColors.coral;
    final sideLabel = position.side == MarketSide.yes ? 'Yes' : 'No';

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sideColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    sideLabel,
                    style: TextStyle(
                      color: sideColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${position.pnl >= 0 ? '+' : ''}\$${position.pnl.toStringAsFixed(2)}',
                  style: TextStyle(color: pnlColor, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(position.question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                _PositionMetric(
                  label: 'Entry',
                  value: TradeMath.formatPrice(position.entryPrice),
                ),
                _PositionMetric(
                  label: 'Now',
                  value: TradeMath.formatPrice(position.currentPrice),
                ),
                _PositionMetric(
                  label: 'Shares',
                  value: position.shares.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionMetric extends StatelessWidget {
  const _PositionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: PulsColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

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
          const Icon(Icons.account_balance_wallet_outlined, color: PulsColors.muted),
          const SizedBox(height: 8),
          Text('No demo positions yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Choose Yes or No from the feed to add one.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
