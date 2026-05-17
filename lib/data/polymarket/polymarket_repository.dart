import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../models/market.dart';

class PolymarketRepository {
  static const _gamma = 'https://gamma-api.polymarket.com';
  int _offset = 0;

  Future<List<Market>> fetchMarkets({int limit = 100}) async {
    // Fetch two pages of 50 in parallel for 100 total, rotating offset each refresh
    final off1 = _offset;
    final off2 = _offset + 50;
    _offset = (_offset + 100) % 500; // cycle through top 500

    final results = await Future.wait([
      _fetch(50, off1),
      _fetch(50, off2),
    ]);

    final markets = [...results[0], ...results[1]];
    markets.shuffle(Random());
    return markets;
  }

  Future<List<Market>> _fetch(int limit, int offset) async {
    final uri = Uri.parse(
      '$_gamma/markets?limit=$limit&active=true&closed=false'
      '&order=volume&ascending=false&offset=$offset',
    );
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final list = json.decode(res.body) as List<dynamic>;
    return list
        .map((j) => _parse(j as Map<String, dynamic>))
        .whereType<Market>()
        .toList();
  }

  Market? _parse(Map<String, dynamic> j) {
    try {
      final rawPrices = j['outcomePrices'] as String? ?? '["0.5","0.5"]';
      final prices = (json.decode(rawPrices) as List)
          .map((p) => double.tryParse(p.toString()) ?? 0.5)
          .toList();
      if (prices.length < 2) return null;

      String category = 'General';
      final events = j['events'] as List<dynamic>?;
      if (events != null && events.isNotEmpty) {
        final ev = events.first as Map<String, dynamic>;
        final tags = ev['tags'] as List<dynamic>?;
        if (tags != null && tags.isNotEmpty) {
          category = (tags.first as Map)['label'] as String? ?? 'General';
        }
      }

      final volNum = (j['volumeNum'] as num?)?.toDouble() ??
          double.tryParse(j['volume']?.toString() ?? '0') ?? 0;
      final liqNum = (j['liquidityNum'] as num?)?.toDouble() ??
          double.tryParse(j['liquidity']?.toString() ?? '0') ?? 0;
      final trend = (j['oneDayPriceChange'] as num?)?.toDouble() ?? 0.0;
      final endRaw = j['endDate'] as String? ?? j['endDateIso'] as String?;
      final deadline = endRaw != null
          ? DateTime.tryParse(endRaw) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30));

      return Market(
        id: j['id']?.toString() ?? j['slug']?.toString() ?? '',
        question: j['question'] as String? ?? '',
        category: category,
        context: j['description'] as String? ?? '',
        yesPrice: prices[0].clamp(0.01, 0.99),
        noPrice: prices[1].clamp(0.01, 0.99),
        volume: _fmt(volNum),
        liquidity: _fmt(liqNum),
        deadline: deadline,
        trend: trend,
        isFeatured: j['featured'] == true || j['new'] == true,
        tags: [category],
        history: const [],
        comments: const [],
        news: const [],
        imageUrl: j['image'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  String _fmt(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}
