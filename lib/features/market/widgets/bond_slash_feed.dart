import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Bond/Slash live feed вЂ” shows AgentBond events from /api/agents/bonds.
/// Displays: BOND POSTED, BOND RETURNED (green), BOND SLASHED (red).
class BondSlashFeed extends StatefulWidget {
  const BondSlashFeed({super.key});

  @override
  State<BondSlashFeed> createState() => _BondSlashFeedState();
}

class _BondSlashFeedState extends State<BondSlashFeed> {
  Map<String, dynamic>? _bondData;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  void _fetch() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/agents/bonds/report'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _bondData = jsonDecode(res.body);
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
    final t = context.puls;
    final agents =
        (_bondData?['agents'] as List? ?? []).cast<Map<String, dynamic>>();
    final totalBonds = (_bondData?['totalBonds'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: t.surfaceRaised,
            child: Row(
              children: [
                Text('AGENTBOND FEED',
                    style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: PulsColors.fontMono,
                        letterSpacing: 1.5)),
                const Spacer(),
                Text('$totalBonds BONDS',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: PulsColors.fontMono)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Color(0xFFF59E0B)))
                : agents.isEmpty
                    ? Center(
                        child: Text('No bonds posted',
                            style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 12,
                                fontFamily: PulsColors.fontMono)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: agents.length,
                        itemBuilder: (context, i) => _BondRow(agent: agents[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _BondRow extends StatelessWidget {
  const _BondRow({required this.agent});
  final Map<String, dynamic> agent;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final agentName =
        (agent['agent'] as String? ?? 'agent').split('_').last.toUpperCase();
    final bonds = agent['bonds'] as Map<String, dynamic>? ?? {};
    final usdc = agent['usdc'] as Map<String, dynamic>? ?? {};
    final accuracy = agent['accuracy'] as num?;

    final active = (bonds['active'] as num?)?.toInt() ?? 0;
    final slashed = (bonds['slashed'] as num?)?.toInt() ?? 0;
    final returned = (bonds['returned'] as num?)?.toInt() ?? 0;
    final usdcActive = (usdc['active'] as num?)?.toDouble() ?? 0;
    final usdcSlashed = (usdc['slashed'] as num?)?.toDouble() ?? 0;
    final usdcReturned = (usdc['returned'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: t.border, width: 0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(agentName,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono)),
              const Spacer(),
              if (accuracy != null)
                Text('${accuracy.toStringAsFixed(0)}% ACC',
                    style: TextStyle(
                        color: accuracy >= 70
                            ? PulsColors.brandMint
                            : PulsColors.brandPink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: PulsColors.fontMono)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _bondTag('ACTIVE', active, '\$${usdcActive.toStringAsFixed(2)}',
                  PulsColors.brandMint),
              const SizedBox(width: 6),
              _bondTag(
                  'RETURNED',
                  returned,
                  '\$${usdcReturned.toStringAsFixed(2)}',
                  PulsColors.brandMint),
              const SizedBox(width: 6),
              _bondTag(
                  'SLASHED',
                  slashed,
                  '\$${usdcSlashed.toStringAsFixed(2)}',
                  const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bondTag(String label, int count, String usdc, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: color.withValues(alpha: 0.2), width: 0.5)),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: PulsColors.fontMono,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: PulsColors.fontMono)),
            Text(usdc,
                style: TextStyle(
                    color: color.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontFamily: PulsColors.fontMono)),
          ],
        ),
      ),
    );
  }
}
