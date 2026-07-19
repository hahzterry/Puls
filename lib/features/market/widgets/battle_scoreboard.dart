import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// AI vs Humans battle scoreboard — real numbers from /api/stats.
/// Shows trade count, volume, and win rate for agents vs humans.
class BattleScoreboard extends StatefulWidget {
  const BattleScoreboard({super.key});

  @override
  State<BattleScoreboard> createState() => _BattleScoreboardState();
}

class _BattleScoreboardState extends State<BattleScoreboard> {
  Map<String, dynamic>? _stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  void _fetch() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/stats')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 && mounted) {
        setState(() => _stats = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentTrades = (_stats?['agentTrades'] as num?)?.toInt() ?? 0;
    final humanTrades = (_stats?['humanTrades'] as num?)?.toInt() ?? 0;
    final agentVol = (_stats?['agentVolumeUsdc'] as num?)?.toDouble() ?? 0;
    final humanVol = (_stats?['humanVolumeUsdc'] as num?)?.toDouble() ?? 0;
    final agentCount = (_stats?['agents'] as num?)?.toInt() ?? 0;
    final totalTrades = agentTrades + humanTrades;
    final totalVol = agentVol + humanVol;

    final agentTradePct = totalTrades > 0 ? agentTrades / totalTrades : 0.0;
    final agentVolPct = totalVol > 0 ? agentVol / totalVol : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F19),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AI vs HUMANS',
                  style: TextStyle(
                      color: Color(0xFF5E6A85),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono,
                      letterSpacing: 1.5)),
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: Color(0xFF2DD4BF), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF2DD4BF), blurRadius: 4)]),
              ),
              const SizedBox(width: 6),
              const Text('LIVE',
                  style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
            ],
          ),
          const SizedBox(height: 14),
          _battleBar('TRADES', agentTrades, humanTrades, agentTradePct),
          const SizedBox(height: 10),
          _battleBar('VOLUME USDC', agentVol, humanVol, agentVolPct, isMoney: true),
          const SizedBox(height: 14),
          Row(
            children: [
              _scoreCard('AI AGENTS', '$agentCount', const Color(0xFF2DD4BF)),
              const SizedBox(width: 10),
              _scoreCard('AI TRADES', '$agentTrades', const Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              _scoreCard('HUMAN TRADES', '$humanTrades', const Color(0xFFEC4899)),
              const SizedBox(width: 10),
              _scoreCard('PROTOCOL REV', '\$${(_stats?['protocolRevenueUsdc'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}', const Color(0xFFA855F7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _battleBar(String label, int aiVal, int humanVal, double aiPct, {bool isMoney = false}) {
    final fmt = (v) => isMoney ? '\$${v.toStringAsFixed(0)}' : '$v';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${fmt(aiVal)} AI', style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono)),
            Text(label, style: const TextStyle(color: Color(0xFF5E6A85), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1)),
            Text('${fmt(humanVal)} HUMAN', style: const TextStyle(color: Color(0xFFEC4899), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(flex: (aiPct * 1000).round().clamp(1, 999), child: Container(color: const Color(0xFF2DD4BF))),
                Expanded(flex: ((1 - aiPct) * 1000).round().clamp(1, 999), child: Container(color: const Color(0xFFEC4899))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 7.5, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: PulsColors.fontMono)),
          ],
        ),
      ),
    );
  }
}
