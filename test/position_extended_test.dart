import 'package:flutter_test/flutter_test.dart';
import 'package:puls/data/models/market.dart';
import 'package:puls/data/models/position.dart';

Position _createPosition({
  String id = 'pos_123',
  String marketId = 'mkt_456',
  String question = 'Will ETH reach \$5,000?',
  MarketSide side = MarketSide.yes,
  double amount = 100.0,
  double entryPrice = 0.5,
  double currentPrice = 0.6,
  double shares = 200.0,
  DateTime? openedAt,
}) {
  return Position(
    id: id,
    marketId: marketId,
    question: question,
    side: side,
    amount: amount,
    entryPrice: entryPrice,
    currentPrice: currentPrice,
    shares: shares,
    openedAt: openedAt ?? DateTime(2024, 6, 15, 12, 0),
  );
}

void main() {
  group('Position Extended Tests', () {
    test('stores MarketSide.no correctly', () {
      final pos = _createPosition(side: MarketSide.no);
      expect(pos.side, equals(MarketSide.no));
    });

    test('marketValue is zero when shares is zero', () {
      final pos = _createPosition(shares: 0, currentPrice: 0.75);
      expect(pos.marketValue, closeTo(0.0, 1e-9));
    });

    test('marketValue is zero when currentPrice is zero', () {
      final pos = _createPosition(shares: 500, currentPrice: 0.0);
      expect(pos.marketValue, closeTo(0.0, 1e-9));
    });

    test('pnl handles very small precision amounts accurately', () {
      final pos = _createPosition(
        amount: 0.0001,
        shares: 0.0002,
        currentPrice: 0.75,
      );
      expect(pos.pnl, closeTo(0.00005, 1e-9));
    });

    test('pnlPercent represents 100% loss when currentPrice is zero', () {
      final pos = _createPosition(
        amount: 50.0,
        entryPrice: 0.5,
        currentPrice: 0.0,
        shares: 100.0,
      );
      expect(pos.pnlPercent, closeTo(-1.0, 1e-9));
    });

    test('pnlPercent represents 100% gain when price doubled from entry', () {
      final pos = _createPosition(
        amount: 40.0,
        entryPrice: 0.4,
        currentPrice: 0.8,
        shares: 100.0,
      );
      expect(pos.pnlPercent, closeTo(1.0, 1e-9));
    });

    test('accessors return expected initial values', () {
      final openedAtDate = DateTime(2024, 5, 20, 10, 30);
      final pos = _createPosition(
        id: 'pos_abc',
        marketId: 'mkt_xyz',
        question: 'Will SpaceX launch on time?',
        entryPrice: 0.42,
        openedAt: openedAtDate,
      );
      expect(pos.id, equals('pos_abc'));
      expect(pos.marketId, equals('mkt_xyz'));
      expect(pos.question, equals('Will SpaceX launch on time?'));
      expect(pos.entryPrice, closeTo(0.42, 1e-9));
      expect(pos.openedAt, equals(openedAtDate));
    });

    test('calculates marketValue and pnl accurately for large positions', () {
      final pos = _createPosition(
        amount: 25000.0,
        entryPrice: 0.50,
        currentPrice: 0.65,
        shares: 50000.0,
      );
      expect(pos.marketValue, closeTo(32500.0, 1e-9));
      expect(pos.pnl, closeTo(7500.0, 1e-9));
      expect(pos.pnlPercent, closeTo(0.3, 1e-9));
    });
  });
}
