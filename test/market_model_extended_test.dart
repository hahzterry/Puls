import 'package:flutter_test/flutter_test.dart';
import 'package:puls/data/models/market.dart';

Market _createMarket({
  String id = 'm1',
  String question = 'Will AI reach AGI?',
  String category = 'Technology',
  String context = 'Context info',
  double yesPrice = 0.6,
  double noPrice = 0.4,
  String volume = r'$1M',
  String liquidity = r'$500K',
  DateTime? deadline,
  double trend = 0.05,
  bool isFeatured = true,
  List<String>? tags,
  List<double>? history,
  List<MarketComment>? comments,
  List<MarketNews>? news,
  String slug = 'ai-agi',
  String? contractAddress,
  String imageUrl = '',
  double volume24hr = 0,
  double lastTradePrice = 0,
  double bestBid = 0,
  double bestAsk = 0,
  double spread = 0,
  String clobTokenId = '',
  double liquidityNum = 0,
  double competitive = 0,
  bool createdByAgent = false,
  double volumeNum = 0,
  int pulsTrades = 0,
  int pulsHolders = 0,
  double pulsVolume = 0,
  int commentsCount = 0,
}) {
  return Market(
    id: id,
    question: question,
    category: category,
    context: context,
    yesPrice: yesPrice,
    noPrice: noPrice,
    volume: volume,
    liquidity: liquidity,
    deadline: deadline ?? DateTime(2030, 1, 1),
    trend: trend,
    isFeatured: isFeatured,
    tags: tags ?? const ['AI', 'Tech'],
    history: history ?? const [0.5, 0.6],
    comments: comments ?? const [],
    news: news ?? const [],
    slug: slug,
    contractAddress: contractAddress,
    imageUrl: imageUrl,
    volume24hr: volume24hr,
    lastTradePrice: lastTradePrice,
    bestBid: bestBid,
    bestAsk: bestAsk,
    spread: spread,
    clobTokenId: clobTokenId,
    liquidityNum: liquidityNum,
    competitive: competitive,
    createdByAgent: createdByAgent,
    volumeNum: volumeNum,
    pulsTrades: pulsTrades,
    pulsHolders: pulsHolders,
    pulsVolume: pulsVolume,
    commentsCount: commentsCount,
  );
}

MarketComment _createComment({
  String author = 'Alice',
  String text = 'Looks promising',
  MarketSide sentiment = MarketSide.yes,
}) {
  return MarketComment(
    author: author,
    text: text,
    sentiment: sentiment,
  );
}

MarketNews _createNews({
  String source = 'TechCrunch',
  String title = 'AGI Breakthrough Announced',
  String age = '2h ago',
}) {
  return MarketNews(
    source: source,
    title: title,
    age: age,
  );
}

void main() {
  group('MarketSide Enum', () {
    test('contains expected values and names', () {
      expect(MarketSide.values.length, equals(2));
      expect(MarketSide.values, containsAll([MarketSide.yes, MarketSide.no]));
      expect(MarketSide.yes.name, equals('yes'));
      expect(MarketSide.no.name, equals('no'));
    });
  });

  group('Market Construction & Defaults', () {
    test('initializes with default optional fields when omitted', () {
      final market = Market(
        id: 'req_1',
        question: 'Will SpaceX land on Mars?',
        category: 'Space',
        context: 'Starship mission details',
        yesPrice: 0.7,
        noPrice: 0.3,
        volume: r'$500K',
        liquidity: r'$200K',
        deadline: DateTime(2028, 6, 1),
        trend: 0.1,
        isFeatured: false,
        tags: const ['Space', 'Mars'],
        history: const [0.65, 0.7],
        comments: const [],
        news: const [],
        slug: 'spacex-mars',
      );

      expect(market.contractAddress, isNull);
      expect(market.imageUrl, equals(''));
      expect(market.volume24hr, closeTo(0.0, 1e-9));
      expect(market.lastTradePrice, closeTo(0.0, 1e-9));
      expect(market.bestBid, closeTo(0.0, 1e-9));
      expect(market.bestAsk, closeTo(0.0, 1e-9));
      expect(market.spread, closeTo(0.0, 1e-9));
      expect(market.clobTokenId, equals(''));
      expect(market.liquidityNum, closeTo(0.0, 1e-9));
      expect(market.competitive, closeTo(0.0, 1e-9));
      expect(market.createdByAgent, isFalse);
      expect(market.volumeNum, closeTo(0.0, 1e-9));
      expect(market.pulsTrades, equals(0));
      expect(market.pulsHolders, equals(0));
      expect(market.pulsVolume, closeTo(0.0, 1e-9));
      expect(market.commentsCount, equals(0));
    });

    test('supports empty tags and history lists', () {
      final market = _createMarket(
        tags: const [],
        history: const [],
      );

      expect(market.tags, isEmpty);
      expect(market.history, isEmpty);
    });
  });

  group('Puls Score Calculations', () {
    test('calculates pulsScore with only holders (no trades, no comments)', () {
      final market = _createMarket(
        pulsHolders: 15,
        pulsTrades: 0,
        commentsCount: 0,
      );
      expect(market.pulsScore, equals(60));
    });

    test('calculates pulsScore with only comments (no holders, no trades)', () {
      final market = _createMarket(
        pulsHolders: 0,
        pulsTrades: 0,
        commentsCount: 20,
      );
      expect(market.pulsScore, equals(60));
    });

    test('calculates pulsScore with only trades (no holders, no comments)', () {
      final market = _createMarket(
        pulsHolders: 0,
        pulsTrades: 42,
        commentsCount: 0,
      );
      expect(market.pulsScore, equals(42));
    });

    test('calculates pulsScore correctly with large values', () {
      final market = _createMarket(
        pulsHolders: 10000,
        pulsTrades: 50000,
        commentsCount: 20000,
      );
      expect(market.pulsScore, equals(150000));
    });
  });

  group('Trend Boundaries', () {
    test('evaluates trendIsPositive accurately around boundaries', () {
      final negativeBoundaryMarket = _createMarket(trend: -0.001);
      final positiveBoundaryMarket = _createMarket(trend: 0.001);

      expect(negativeBoundaryMarket.trend, closeTo(-0.001, 1e-9));
      expect(negativeBoundaryMarket.trendIsPositive, isFalse);

      expect(positiveBoundaryMarket.trend, closeTo(0.001, 1e-9));
      expect(positiveBoundaryMarket.trendIsPositive, isTrue);
    });
  });

  group('Market.copyWith Full Preservation', () {
    test('preserves all fields when selectively overriding slug and contractAddress', () {
      final deadline = DateTime(2026, 12, 31, 23, 59);
      final comments = [_createComment()];
      final news = [_createNews()];

      final original = Market(
        id: 'mkt_full_1',
        question: 'Will ETH exceed \$10,000?',
        category: 'Crypto',
        context: 'Ethereum price prediction',
        yesPrice: 0.82,
        noPrice: 0.18,
        volume: r'$10M',
        liquidity: r'$2M',
        deadline: deadline,
        trend: 0.15,
        isFeatured: true,
        tags: const ['Crypto', 'ETH'],
        history: const [0.75, 0.82],
        comments: comments,
        news: news,
        slug: 'eth-10k',
        contractAddress: '0x1111111111111111111111111111111111111111',
        imageUrl: 'assets/images/eth.png',
        volume24hr: 150000.0,
        lastTradePrice: 0.81,
        bestBid: 0.80,
        bestAsk: 0.83,
        spread: 0.03,
        clobTokenId: 'clob_eth_10k',
        liquidityNum: 2000000.0,
        competitive: 0.92,
        createdByAgent: true,
        volumeNum: 10000000.0,
        pulsTrades: 300,
        pulsHolders: 120,
        pulsVolume: 50000.0,
        commentsCount: 25,
      );

      final copy = original.copyWith(
        slug: 'eth-10k-updated',
        contractAddress: '0x2222222222222222222222222222222222222222',
      );

      expect(copy.slug, equals('eth-10k-updated'));
      expect(copy.contractAddress, equals('0x2222222222222222222222222222222222222222'));

      expect(copy.id, equals(original.id));
      expect(copy.question, equals(original.question));
      expect(copy.category, equals(original.category));
      expect(copy.context, equals(original.context));
      expect(copy.yesPrice, closeTo(original.yesPrice, 1e-9));
      expect(copy.noPrice, closeTo(original.noPrice, 1e-9));
      expect(copy.volume, equals(original.volume));
      expect(copy.liquidity, equals(original.liquidity));
      expect(copy.deadline, equals(original.deadline));
      expect(copy.trend, closeTo(original.trend, 1e-9));
      expect(copy.isFeatured, equals(original.isFeatured));
      expect(copy.tags, equals(original.tags));
      expect(copy.history, equals(original.history));
      expect(copy.comments, equals(original.comments));
      expect(copy.news, equals(original.news));
      expect(copy.imageUrl, equals(original.imageUrl));
      expect(copy.volume24hr, closeTo(original.volume24hr, 1e-9));
      expect(copy.lastTradePrice, closeTo(original.lastTradePrice, 1e-9));
      expect(copy.bestBid, closeTo(original.bestBid, 1e-9));
      expect(copy.bestAsk, closeTo(original.bestAsk, 1e-9));
      expect(copy.spread, closeTo(original.spread, 1e-9));
      expect(copy.clobTokenId, equals(original.clobTokenId));
      expect(copy.liquidityNum, closeTo(original.liquidityNum, 1e-9));
      expect(copy.competitive, closeTo(original.competitive, 1e-9));
      expect(copy.createdByAgent, equals(original.createdByAgent));
      expect(copy.volumeNum, closeTo(original.volumeNum, 1e-9));
      expect(copy.pulsTrades, equals(original.pulsTrades));
      expect(copy.pulsHolders, equals(original.pulsHolders));
      expect(copy.pulsVolume, closeTo(original.pulsVolume, 1e-9));
      expect(copy.commentsCount, equals(original.commentsCount));
    });
  });

  group('MarketComment Model', () {
    test('constructs and provides field access for yes sentiment', () {
      final comment = _createComment(
        author: 'TraderJoe',
        text: 'Strong buy signal',
        sentiment: MarketSide.yes,
      );

      expect(comment.author, equals('TraderJoe'));
      expect(comment.text, equals('Strong buy signal'));
      expect(comment.sentiment, equals(MarketSide.yes));
    });

    test('constructs and provides field access for no sentiment', () {
      final comment = _createComment(
        author: 'SkepticalSam',
        text: 'Unlikely to happen',
        sentiment: MarketSide.no,
      );

      expect(comment.author, equals('SkepticalSam'));
      expect(comment.text, equals('Unlikely to happen'));
      expect(comment.sentiment, equals(MarketSide.no));
    });
  });

  group('MarketNews Model', () {
    test('constructs and provides field access', () {
      final news = _createNews(
        source: 'Bloomberg',
        title: 'Markets rally following announcement',
        age: '15m ago',
      );

      expect(news.source, equals('Bloomberg'));
      expect(news.title, equals('Markets rally following announcement'));
      expect(news.age, equals('15m ago'));
    });
  });
}
