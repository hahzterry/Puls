import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches YES price history from Polymarket CLOB API.
/// Returns a list of prices (0.0–1.0) ordered oldest→newest.
class PriceHistoryService {
  static const _clob = 'https://clob.polymarket.com';

  // Simple in-memory cache: tokenId → prices
  static final _cache = <String, List<double>>{};

  static Future<List<double>> fetch(String clobTokenId) async {
    if (clobTokenId.isEmpty) return [];
    if (_cache.containsKey(clobTokenId)) return _cache[clobTokenId]!;

    try {
      final uri = Uri.parse(
        '$_clob/prices-history?market=$clobTokenId&interval=1d&fidelity=60',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final history = (data['history'] as List? ?? [])
          .map((e) => (e['p'] as num).toDouble())
          .toList();
      _cache[clobTokenId] = history;
      return history;
    } catch (_) {
      return [];
    }
  }
}
