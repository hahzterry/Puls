import 'package:flutter/widgets.dart';

import '../core/utils/trade_math.dart';
import '../data/mock/mock_market_repository.dart';
import '../data/models/market.dart';
import '../data/models/position.dart';

class PulsAppState extends ChangeNotifier {
  PulsAppState({required this.repository})
      : markets = repository.markets,
        categories = repository.categories,
        _watchlistIds = repository.initialWatchlistIds.toSet(),
        _positions = List<Position>.from(repository.initialPositions);

  final MockMarketRepository repository;
  final List<Market> markets;
  final List<String> categories;
  final Set<String> _watchlistIds;
  final List<Position> _positions;

  bool onboardingComplete = false;

  List<Position> get positions => List.unmodifiable(_positions);
  List<String> get watchlistIds => List.unmodifiable(_watchlistIds);

  List<Market> get feedMarkets =>
      markets.where((market) => market.isFeatured).toList(growable: false);

  List<Market> get watchlistMarkets => markets
      .where((market) => _watchlistIds.contains(market.id))
      .toList(growable: false);

  Market marketById(String id) {
    return markets.firstWhere((market) => market.id == id);
  }

  bool isWatchlisted(String marketId) => _watchlistIds.contains(marketId);

  void completeOnboarding() {
    onboardingComplete = true;
    notifyListeners();
  }

  void toggleWatchlist(String marketId) {
    if (_watchlistIds.contains(marketId)) {
      _watchlistIds.remove(marketId);
    } else {
      _watchlistIds.add(marketId);
    }
    notifyListeners();
  }

  Position addDemoPosition({
    required Market market,
    required MarketSide side,
    required double amount,
  }) {
    final price = side == MarketSide.yes ? market.yesPrice : market.noPrice;
    final shares = TradeMath.estimatedShares(amount: amount, price: price);
    final position = Position(
      id: 'pos-${DateTime.now().microsecondsSinceEpoch}',
      marketId: market.id,
      question: market.question,
      side: side,
      amount: amount,
      entryPrice: price,
      currentPrice: price,
      shares: shares,
      openedAt: DateTime.now(),
    );

    _positions.insert(0, position);
    notifyListeners();
    return position;
  }
}

class PulsStateScope extends InheritedNotifier<PulsAppState> {
  const PulsStateScope({
    required PulsAppState super.notifier,
    required super.child,
    super.key,
  });

  static PulsAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PulsStateScope>();
    assert(scope != null, 'PulsStateScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}
