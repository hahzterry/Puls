class TradeMath {
  static double estimatedShares({
    required double amount,
    required double price,
  }) {
    if (amount <= 0 || price <= 0) {
      return 0;
    }
    return amount / price;
  }

  static double estimatedPayout({
    required double amount,
    required double price,
  }) {
    return estimatedShares(amount: amount, price: price);
  }

  static double estimatedProfit({
    required double amount,
    required double price,
  }) {
    return estimatedPayout(amount: amount, price: price) - amount;
  }

  static String formatPrice(double price) {
    return '${(price * 100).round()}¢';
  }

  static String formatPercent(double value) {
    return '${(value * 100).round()}%';
  }
}
