import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/theme/app_theme.dart';
import '../../core/motion.dart';

/// 1. Live Crypto Ticker (Binance Websocket)
class CryptoTickerStrip extends StatefulWidget {
  const CryptoTickerStrip({super.key});

  @override
  State<CryptoTickerStrip> createState() => _CryptoTickerStripState();
}

class _CryptoTickerStripState extends State<CryptoTickerStrip>
    with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  final Map<String, double> _prices = {};
  final Map<String, double> _oldPrices = {};
  // Binance @trade streams can fire many times per second; buffer the latest
  // price per symbol and flush to the UI once per second instead of a setState
  // per trade.
  final Map<String, double> _pending = {};
  Timer? _flushTimer;
  static const _flushEvery = Duration(seconds: 1);

  late final AnimationController _scrollController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 100000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor reduce-motion: hold the strip still (static first row).
    if (context.reduceMotion) {
      _scrollController
        ..stop()
        ..value = 0.0;
    } else if (!_scrollController.isAnimating) {
      _scrollController.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialPrices();
    _connectWebSocket();
  }

  /// Seeds the strip with real spot prices so it never flashes stale
  /// placeholders before the first websocket tick.
  Future<void> _fetchInitialPrices() async {
    try {
      final res = await http.get(Uri.parse(
          'https://api.binance.com/api/v3/ticker/price?symbols=["BTCUSDT","ETHUSDT","SOLUSDT"]'));
      if (res.statusCode != 200 || !mounted) return;
      final list = jsonDecode(res.body) as List<dynamic>;
      final next = <String, double>{};
      for (final e in list) {
        final symbol = e['symbol'] as String?;
        final price = double.tryParse(e['price'] as String? ?? '');
        if (symbol != null && price != null) next[symbol] = price;
      }
      if (next.isEmpty) return;
      setState(() {
        _prices
          ..clear()
          ..addAll(next);
        _oldPrices
          ..clear()
          ..addAll(next);
      });
    } catch (_) {}
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
            'wss://stream.binance.com:9443/ws/btcusdt@trade/ethusdt@trade/solusdt@trade'),
      );
      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        final symbol = data['s'] as String?;
        final priceStr = data['p'] as String?;
        if (symbol != null && priceStr != null) {
          final price = double.tryParse(priceStr);
          if (price != null) {
            _pending[symbol] = price;
            _flushTimer ??= Timer(_flushEvery, _flushPrices);
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _flushPrices() {
    _flushTimer = null;
    if (!mounted || _pending.isEmpty) return;
    setState(() {
      _pending.forEach((symbol, price) {
        _oldPrices[symbol] = _prices[symbol] ?? price;
        _prices[symbol] = price;
      });
      _pending.clear();
    });
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _channel?.sink.close();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildPair(String label, String symbol, PulsThemeColors t) {
    final price = _prices[symbol];
    final oldPrice = _oldPrices[symbol] ?? price ?? 0.0;
    final up = price != null && price >= oldPrice;
    final color = up ? t.yes : t.no;
    final icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      width: 120,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
                color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            price == null
                ? '—'
                : '\$${price.toStringAsFixed(price > 1000 ? 0 : 2)}',
            style: TextStyle(
                color: t.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: PulsColors.tabularFigures),
          ),
          const SizedBox(width: 4),
          if (price != null) Icon(icon, color: color, size: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // The ticker strip is rebuilt only when prices/theme change; the scroll
    // controller drives just the translate offset, so the static pair row is
    // built once as AnimatedBuilder's child instead of on every scroll tick.
    final pairs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPair('BTC', 'BTCUSDT', t),
        Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: t.border, shape: BoxShape.circle)),
        _buildPair('ETH', 'ETHUSDT', t),
        Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: t.border, shape: BoxShape.circle)),
        _buildPair('SOL', 'SOLUSDT', t),
        Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: t.border, shape: BoxShape.circle)),
      ],
    );
    final tape = Row(
      mainAxisSize: MainAxisSize.min,
      children: [pairs, pairs, pairs, pairs, pairs, pairs],
    );
    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _scrollController,
          child: tape,
          builder: (context, child) {
            final elapsed = _scrollController.value * 100000;
            final dx = -((elapsed * 42) % 372);

            return OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 2. Fear & Greed Index
class FearAndGreedWidget extends StatefulWidget {
  const FearAndGreedWidget({super.key});

  @override
  State<FearAndGreedWidget> createState() => _FearAndGreedWidgetState();
}

class _FearAndGreedWidgetState extends State<FearAndGreedWidget> {
  int? _value;
  String? _classification;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final res = await http.get(Uri.parse('https://api.alternative.me/fng/'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          if (mounted) {
            setState(() {
              _value = int.parse(data['data'][0]['value']);
              _classification = data['data'][0]['value_classification'];
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final value = _value;
    final color = value == null
        ? t.textSubtle
        : (value < 40 ? t.no : (value > 60 ? t.yes : Colors.orange));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: t.brand, size: 20),
              const SizedBox(width: 8),
              Text('Market Sentiment',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                value?.toString() ?? '—',
                style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFeatures: PulsColors.tabularFigures,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _classification ?? 'Loading…',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Fear & Greed Index',
                      style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
