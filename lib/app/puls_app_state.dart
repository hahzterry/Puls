import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart' show backendUrl;
import '../core/utils/trade_math.dart';
import '../data/mock/mock_market_repository.dart';
import '../data/models/market.dart';
import '../data/models/position.dart';
import '../data/polymarket/polymarket_repository.dart';

enum FeedStatus { loading, loaded, error }

class PulsAppState extends ChangeNotifier {
  PulsAppState({required this.mockRepo}) {
    _positions = List<Position>.from(mockRepo.initialPositions);
    _watchlistIds = mockRepo.initialWatchlistIds.toSet();
    _loadMarkets();
  }

  final MockMarketRepository mockRepo;
  final _polymarket = PolymarketRepository();

  List<Market> _markets = [];
  List<Position> _positions = [];
  Set<String> _watchlistIds = {};

  FeedStatus feedStatus = FeedStatus.loading;
  String? feedError;

  bool onboardingComplete = false;
  ThemeMode themeMode = ThemeMode.light;
  bool fastBuyEnabled = false;
  double fastBuyAmount = 1.0;

  List<Market> get markets => List.unmodifiable(_markets);
  List<Position> get positions => List.unmodifiable(_positions);
  List<String> get watchlistIds => List.unmodifiable(_watchlistIds);

  List<String> get categories {
    final cats = _markets.map((m) => m.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<Market> get feedMarkets {
    final tradedIds = _positions.map((p) => p.marketId).toSet();
    final fresh = _markets.where((m) => !tradedIds.contains(m.id)).toList();
    // If all traded (unlikely), show all
    return fresh.isNotEmpty ? fresh : _markets;
  }

  List<Market> get watchlistMarkets =>
      _markets.where((m) => _watchlistIds.contains(m.id)).toList();

  Market marketById(String id) =>
      _markets.firstWhere((m) => m.id == id);

  bool isWatchlisted(String marketId) => _watchlistIds.contains(marketId);

  Future<void> _loadMarkets() async {
    feedStatus = FeedStatus.loading;
    notifyListeners();
    try {
      debugPrint('[Puls] Fetching Polymarket markets…');
      final fetched = await _polymarket.fetchMarkets(limit: 100);

      // Attempt to load the live contract market from backend
      try {
        final res = await http.get(Uri.parse('$backendUrl/api/market/info')).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final deadlineSeconds = data['deadline'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
          final contractAddr = data['contractAddress'] as String? ?? '0x6c1f21fe9d5dff9a2feabd9c760cb9296aa48072';
          final liveMarket = Market(
            id: contractAddr,
            question: data['question'] as String? ?? 'Will Bitcoin close above \$100k this quarter?',
            category: 'Crypto',
            context: 'This market is backed by a smart contract deployed on the Arc Testnet.',
            yesPrice: (data['yesPrice'] as num?)?.toDouble() ?? 0.5,
            noPrice: (data['noPrice'] as num?)?.toDouble() ?? 0.5,
            volume: '\$${(data['totalVolume'] as num?)?.toStringAsFixed(1) ?? "20.0"}',
            liquidity: '\$${(data['poolYes'] as num?)?.toStringAsFixed(1) ?? "10.0"}',
            deadline: DateTime.fromMillisecondsSinceEpoch(deadlineSeconds * 1000),
            trend: 0.0,
            isFeatured: true,
            tags: const ['Live Chain', 'Crypto'],
            history: const [],
            comments: const [],
            news: const [],
          );

          // Prepend the live market to the list!
          _markets = [liveMarket, ...fetched];
        } else {
          _markets = fetched;
        }
      } catch (e) {
        debugPrint('[Puls] Live market info fetch failed: $e');
        _markets = fetched;
      }

      debugPrint('[Puls] Loaded ${_markets.length} markets');
      feedStatus = FeedStatus.loaded;
    } catch (e, st) {
      debugPrint('[Puls] Fetch error: $e\n$st');
      feedError = e.toString();
      feedStatus = FeedStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => _loadMarkets();

  void completeOnboarding() {
    onboardingComplete = true;
    notifyListeners();
  }

  void toggleThemeMode() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void toggleFastBuy() {
    fastBuyEnabled = !fastBuyEnabled;
    notifyListeners();
  }

  void setFastBuyAmount(double amount) {
    fastBuyAmount = amount;
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
    final scope =
        context.dependOnInheritedWidgetOfExactType<PulsStateScope>();
    assert(scope != null, 'PulsStateScope not found');
    return scope!.notifier!;
  }
}
