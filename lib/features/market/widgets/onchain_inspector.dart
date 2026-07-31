import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// On-chain transaction inspector вЂ” shows recent trades with tx hashes,
/// gas, contract addresses, and Arcscan links.
class OnchainInspector extends StatefulWidget {
  const OnchainInspector({super.key});

  @override
  State<OnchainInspector> createState() => _OnchainInspectorState();
}

class _OnchainInspectorState extends State<OnchainInspector> {
  List<Map<String, dynamic>> _trades = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  void _fetch() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/trade/recent'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // API returns a bare array, not { trades: [...] }
        final list = (data is List ? data : (data['trades'] as List? ?? []))
            .cast<Map<String, dynamic>>();
        if (mounted)
          setState(() {
            _trades = list.take(30).toList();
            _loading = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border.all(color: const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF05080F),
            child: Row(
              children: [
                const Text('ON-CHAIN INSPECTOR',
                    style: TextStyle(
                        color: Color(0xFF5E6A85),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        fontFamily: PulsColors.fontMono,
                        letterSpacing: 1.5)),
                const Spacer(),
                Text('${_trades.length} TXS',
                    style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: PulsColors.fontMono)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Color(0xFF06B6D4)))
                : _trades.isEmpty
                    ? Center(
                        child: Text('No on-chain transactions',
                            style: TextStyle(
                                color: const Color(0xFF5E6A85),
                                fontSize: 12,
                                fontFamily: PulsColors.fontMono)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _trades.length,
                        itemBuilder: (context, i) => _TxRow(trade: _trades[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.trade});
  final Map<String, dynamic> trade;

  @override
  Widget build(BuildContext context) {
    final side = (trade['side'] as String? ?? 'YES').toUpperCase();
    final isYes = side == 'YES';
    final sideColor = isYes ? PulsColors.brandMint : PulsColors.brandPink;
    final amount = (trade['usdc_amount'] as num?)?.toDouble() ?? 0;
    final txHash = (trade['tx_hash'] as String? ?? '');
    final shortHash =
        '${txHash.substring(0, 6)}вЂ¦${txHash.substring(txHash.length - 4)}';
    final marketId = (trade['market_id'] as String? ?? '');
    final shortMarket = marketId.length > 10
        ? '${marketId.substring(0, 6)}вЂ¦${marketId.substring(marketId.length - 4)}'
        : marketId;
    final userId = (trade['user_id'] as String? ?? 'unknown');
    final isAgent = userId.startsWith('agent_');
    final state = (trade['state'] as String? ?? 'COMPLETE').toUpperCase();
    final stateColor = state == 'COMPLETE'
        ? PulsColors.brandMint
        : state == 'FAILED'
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final ts = (trade['created_at'] as String? ?? '');
    final time = ts.length >= 8 ? ts.substring(11, 19) : '--:--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFF0A0E1A), width: 0.5))),
      child: Row(
        children: [
          SizedBox(
              width: 50,
              child: Text(time,
                  style: const TextStyle(
                      color: Color(0xFF5E6A85),
                      fontSize: 9,
                      fontFamily: PulsColors.fontMono))),
          SizedBox(
            width: 35,
            child: Text(isAgent ? 'AGT' : 'HUM',
                style: TextStyle(
                    color: isAgent
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF9AA6C0),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: PulsColors.fontMono)),
          ),
          SizedBox(
              width: 35,
              child: Text(side,
                  style: TextStyle(
                      color: sideColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono))),
          SizedBox(
              width: 55,
              child: Text('\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: sideColor.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontFamily: PulsColors.fontMono))),
          SizedBox(
              width: 50,
              child: Text(shortHash,
                  style: const TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 8.5,
                      fontFamily: PulsColors.fontMono))),
          Expanded(
              child: Text(shortMarket,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF5E6A85),
                      fontSize: 8.5,
                      fontFamily: PulsColors.fontMono))),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2)),
            child: Text(state.substring(0, 4),
                style: TextStyle(
                    color: stateColor,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: PulsColors.fontMono)),
          ),
        ],
      ),
    );
  }
}
