import 'market.dart';

class Position {
  const Position({
    required this.id,
    required this.marketId,
    required this.question,
    required this.side,
    required this.amount,
    required this.entryPrice,
    required this.currentPrice,
    required this.shares,
    required this.openedAt,
  });

  final String id;
  final String marketId;
  final String question;
  final MarketSide side;
  final double amount;
  final double entryPrice;
  final double currentPrice;
  final double shares;
  final DateTime openedAt;

  double get marketValue => shares * currentPrice;
  double get pnl => marketValue - amount;
  double get pnlPercent => amount == 0 ? 0 : pnl / amount;
}
