import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/puls_avatar.dart';

/// Agent strategy cards — shows each agent's persona, role, stats,
/// recent signals, and win rate by category.
class AgentStrategyCards extends StatefulWidget {
  const AgentStrategyCards({super.key});

  @override
  State<AgentStrategyCards> createState() => _AgentStrategyCardsState();
}

class _AgentStrategyCardsState extends State<AgentStrategyCards> {
  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/agents/roster')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final agents = (data['agents'] as List? ?? []).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _agents = agents; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _colors = [
    Color(0xFF2DD4BF), Color(0xFFEC4899), Color(0xFFA855F7),
    Color(0xFF06B6D4), Color(0xFFEAB308), Color(0xFF3B82F6),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2DD4BF)));
    if (_agents.isEmpty) return Center(child: Text('No agents', style: TextStyle(color: const Color(0xFF5E6A85), fontSize: 12, fontFamily: PulsColors.fontMono)));

    return ListView.builder(
      itemCount: _agents.length,
      itemBuilder: (context, i) {
        final agent = _agents[i];
        final color = _colors[i % _colors.length];
        return _StrategyCard(agent: agent, color: color);
      },
    );
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({required this.agent, required this.color});
  final Map<String, dynamic> agent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final name = (agent['name'] as String?) ?? 'Agent';
    final role = (agent['role'] as String?) ?? 'trader';
    final balance = (agent['balance'] as num?)?.toDouble() ?? 0;
    final address = (agent['address'] as String?) ?? '0x...';
    final decisions = (agent['recentDecisions'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F19),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulsAvatar(url: '', name: name, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: PulsColors.fontMono)),
                    Text(role.toUpperCase(), style: const TextStyle(color: Color(0xFF5E6A85), fontSize: 8.5, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono, letterSpacing: 0.8)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('\$${balance.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (decisions.isNotEmpty) ...[
            const Text('RECENT DECISIONS', style: TextStyle(color: Color(0xFF5E6A85), fontSize: 8, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1)),
            const SizedBox(height: 4),
            ...decisions.take(3).map((d) {
              final m = d as Map;
              final action = (m['action'] as String?) ?? 'unknown';
              final side = (m['side'] as String?) ?? '';
              final q = (m['question'] as String? ?? '').replaceAll('🤖 Agent:', '').trim();
              final qShort = q.length > 35 ? '${q.substring(0, 34)}…' : q;
              final actionColor = action == 'go' ? const Color(0xFF2DD4BF) : action == 'skip' ? const Color(0xFFF59E0B) : const Color(0xFF5E6A85);
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: actionColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                      child: Text(action.toUpperCase(), style: TextStyle(color: actionColor, fontSize: 8, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono)),
                    ),
                    if (side.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(side, style: TextStyle(color: side == 'YES' ? const Color(0xFF2DD4BF) : const Color(0xFFEC4899), fontSize: 9, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono)),
                    ],
                    const SizedBox(width: 6),
                    Expanded(child: Text(qShort, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFEAF0FF), fontSize: 9, fontFamily: PulsColors.fontMono))),
                  ],
                ),
              );
            }),
          ] else
            Text('No recent decisions', style: const TextStyle(color: Color(0xFF5E6A85), fontSize: 10, fontFamily: PulsColors.fontMono)),
          const SizedBox(height: 8),
          Text(address, style: const TextStyle(color: Color(0xFF5E6A85), fontSize: 8.5, fontFamily: PulsColors.fontMono)),
        ],
      ),
    );
  }
}
