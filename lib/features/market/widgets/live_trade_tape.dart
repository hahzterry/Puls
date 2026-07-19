import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Bloomberg-style live trade tape. Polls /api/trade/recent every 5s and
/// also listens to WebSocket TRADE_COMPLETE events for instant updates.
/// Each row: time | agent/human | market | YES/NO | amount | price.
class LiveTradeTape extends StatefulWidget {
  const LiveTradeTape({super.key, this.liveTrades = const []});
  final List<Map<String, dynamic>> liveTrades;

  @override
  State<LiveTradeTape> createState() => _LiveTradeTapeState();
}

class _LiveTradeTapeState extends State<LiveTradeTape> {
  List<Map<String, dynamic>> _trades = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchTrades();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchTrades());
  }

  @override
  void didUpdateWidget(LiveTradeTape old) {
    super.didUpdateWidget(old);
    if (widget.liveTrades.isNotEmpty && widget.liveTrades != old.liveTrades) {
      _trades = [...widget.liveTrades, ..._trades].take(100).toList();
    }
  }

  void _fetchTrades() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/trade/recent'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final list = (data['trades'] as List? ?? [])
          .map((t) => t as Map<String, dynamic>)
          .toList();
      if (mounted) setState(() => _trades = list.take(100).toList());
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _header(t),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _trades.length,
              itemBuilder: (context, i) => _TradeRow(trade: _trades[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(PulsThemeColors t) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF05080F),
      child: Row(
        children: [
          const _Hdr('TIME', 50),
          const _Hdr('TRADER', 70),
          const _Hdr('SIDE', 40),
          const _Hdr('AMOUNT', 60),
          const _Hdr('MARKET', 0, flex: true),
        ],
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.label, this.width, {this.flex = false});
  final String label;
  final double width;
  final bool flex;

  @override
  Widget build(BuildContext context) {
    if (flex) {
      return Expanded(
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF5E6A85),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                fontFamily: PulsColors.fontMono,
                letterSpacing: 1)),
      );
    }
    return SizedBox(
      width: width,
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF5E6A85),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontFamily: PulsColors.fontMono,
              letterSpacing: 1)),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade});
  final Map<String, dynamic> trade;

  @override
  Widget build(BuildContext context) {
    final side = (trade['side'] as String? ?? 'YES').toUpperCase();
    final isYes = side == 'YES';
    final sideColor = isYes ? const Color(0xFF2DD4BF) : const Color(0xFFEC4899);
    final userId = (trade['user_id'] as String? ?? 'unknown');
    final isAgent = userId.startsWith('agent_');
    final amount = (trade['usdc_amount'] as num?)?.toDouble() ?? 0;
    final question = (trade['question'] as String? ?? '').replaceAll('🤖 Agent:', '').trim();
    final q = question.length > 30 ? '${question.substring(0, 29)}…' : question;
    final ts = trade['created_at'] as String? ?? '';
    final time = ts.length >= 8 ? ts.substring(11, 19) : '--:--:--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF0A0E1A), width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(time,
                style: const TextStyle(
                    color: Color(0xFF5E6A85),
                    fontSize: 9.5,
                    fontFamily: PulsColors.fontMono)),
          ),
          SizedBox(
            width: 70,
            child: Text(isAgent ? 'AGENT' : 'HUMAN',
                style: TextStyle(
                    color: isAgent ? const Color(0xFFF59E0B) : const Color(0xFF9AA6C0),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: PulsColors.fontMono)),
          ),
          SizedBox(
            width: 40,
            child: Text(side,
                style: TextStyle(
                    color: sideColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: PulsColors.fontMono)),
          ),
          SizedBox(
            width: 60,
            child: Text('\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    color: sideColor.withValues(alpha: 0.8),
                    fontSize: 9.5,
                    fontFamily: PulsColors.fontMono)),
          ),
          Expanded(
            child: Text(q,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFEAF0FF),
                    fontSize: 9.5,
                    fontFamily: PulsColors.fontMono)),
          ),
        ],
      ),
    );
  }
}
