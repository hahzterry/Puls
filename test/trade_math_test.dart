import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/utils/trade_math.dart';

void main() {
  group('TradeMath', () {
    test('calculates estimated shares from amount and price', () {
      expect(
        TradeMath.estimatedShares(amount: 50, price: 0.25),
        closeTo(200, 0.001),
      );
    });

    test('returns zero for invalid amount or price', () {
      expect(TradeMath.estimatedShares(amount: 0, price: 0.25), 0);
      expect(TradeMath.estimatedShares(amount: 50, price: 0), 0);
    });

    test('formats prices as cents', () {
      expect(TradeMath.formatPrice(0.61), '61c');
    });
  });
}
