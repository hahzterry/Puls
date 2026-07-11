import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/theme/app_theme.dart';

/// 1. Live Crypto Ticker (Binance Websocket)
class CryptoTickerStrip extends StatefulWidget {
  const CryptoTickerStrip({super.key});

  @override
  State<CryptoTickerStrip> createState() => _CryptoTickerStripState();
}

class _CryptoTickerStripState extends State<CryptoTickerStrip> with SingleTickerProviderStateMixin {
  WebSocketChannel? _channel;
  final Map<String, double> _prices = {'BTCUSDT': 64000, 'ETHUSDT': 3450, 'SOLUSDT': 145};
  final Map<String, double> _oldPrices = {'BTCUSDT': 64000, 'ETHUSDT': 3450, 'SOLUSDT': 145};
  
  late final AnimationController _scrollController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 100000),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://stream.binance.com:9443/ws/btcusdt@trade/ethusdt@trade/solusdt@trade'),
      );
      _channel!.stream.listen((message) {
        final data = jsonDecode(message);
        final symbol = data['s'] as String?;
        final priceStr = data['p'] as String?;
        if (symbol != null && priceStr != null) {
          final price = double.tryParse(priceStr);
          if (price != null && mounted) {
            setState(() {
              _oldPrices[symbol] = _prices[symbol] ?? price;
              _prices[symbol] = price;
            });
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildPair(String label, String symbol, PulsThemeColors t) {
    final price = _prices[symbol] ?? 0.0;
    final oldPrice = _oldPrices[symbol] ?? price;
    final up = price >= oldPrice;
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
            style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            '\$${price.toStringAsFixed(price > 1000 ? 0 : 2)}',
            style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.w800, fontFeatures: PulsColors.tabularFigures),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: color, size: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      height: 32,
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final pairs = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPair('BTC', 'BTCUSDT', t),
              Container(width: 4, height: 4, decoration: BoxDecoration(color: t.border, shape: BoxShape.circle)),
              _buildPair('ETH', 'ETHUSDT', t),
              Container(width: 4, height: 4, decoration: BoxDecoration(color: t.border, shape: BoxShape.circle)),
              _buildPair('SOL', 'SOLUSDT', t),
              Container(width: 4, height: 4, decoration: BoxDecoration(color: t.border, shape: BoxShape.circle)),
            ],
          );

          final elapsed = _scrollController.value * 100000;
          final dx = -((elapsed * 42) % 372);

          return OverflowBox(
            minWidth: 0,
            maxWidth: double.infinity,
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [pairs, pairs, pairs, pairs, pairs, pairs]),
            ),
          );
        },
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
  int _value = 74;
  String _classification = 'Greed';

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
    final color = _value < 40 ? t.no : (_value > 60 ? t.yes : Colors.orange);
    
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
                '$_value',
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
                      _classification,
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
