import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_emoji_text.dart';

/// Live "Humans vs Agents" scoreboard — Puls's core narrative made literal.
/// Aggregates live win-rates from /api/leaderboard so anyone (judges included)
/// immediately sees autonomous AI agents trading alongside — and often
/// out-performing — humans on Arc. Renders nothing until data with at least
/// one agent loads.
///
/// Shared widget: shown on Home (overview) and on the Agent tab (the flagship
/// agent home), so it lives in exactly one place in code.
class HumansVsAgentsCard extends StatefulWidget {
  const HumansVsAgentsCard({super.key});

  @override
  State<HumansVsAgentsCard> createState() => _HumansVsAgentsCardState();
}

class _HumansVsAgentsCardState extends State<HumansVsAgentsCard> {
  bool _loaded = false;
  double _agentWin = 0, _humanWin = 0;
  int _agentCount = 0, _humanCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Mirrors the static versus.html aggregation exactly: two separate API
  /// calls (type=agents + type=humans), and win rate = winsRes / resolved
  /// (true realized win rate), NOT a simple average of per-trader winRate.
  /// The old code fetched type='all' in one call and averaged winRate
  /// naively — that buried humans at ~1.7% because thousands of still-open
  /// trades counted as 0% wins.
  Future<void> _load() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final results = await Future.wait([
        wallet.getLeaderboard(limit: 500, type: 'agents'),
        wallet.getLeaderboard(limit: 500, type: 'humans'),
      ]);
      final agentRows = results[0];
      final humanRows = results[1];

      var aResolved = 0, aWins = 0;
      var aWrNum = 0.0, aWrDen = 0;
      for (final row in agentRows) {
        if (row is! Map) continue;
        final tc = (row['tradesCount'] as num?)?.toInt() ??
            (row['trades'] as num?)?.toInt() ?? 0;
        final resolved = (row['resolvedCount'] as num?)?.toInt() ?? 0;
        final wins = (row['winsCount'] as num?)?.toInt() ?? 0;
        // winRate comes as a number from the API (e.g. 67.5 or 0), not a
        // string. Parse it robustly — handle both num and string.
        final wr = (row['winRate'] as num?)?.toDouble() ??
            double.tryParse(row['winRate']?.toString() ?? '') ??
            0;
        aResolved += resolved;
        aWins += wins;
        aWrNum += wr * tc;
        aWrDen += tc;
      }

      var hResolved = 0, hWins = 0;
      var hWrNum = 0.0, hWrDen = 0;
      for (final row in humanRows) {
        if (row is! Map) continue;
        final tc = (row['tradesCount'] as num?)?.toInt() ??
            (row['trades'] as num?)?.toInt() ?? 0;
        final resolved = (row['resolvedCount'] as num?)?.toInt() ?? 0;
        final wins = (row['winsCount'] as num?)?.toInt() ?? 0;
        final wr = (row['winRate'] as num?)?.toDouble() ??
            double.tryParse(row['winRate']?.toString() ?? '') ??
            0;
        hResolved += resolved;
        hWins += wins;
        hWrNum += wr * tc;
        hWrDen += tc;
      }

      // True win rate = wins / RESOLVED positions. Falls back to
      // trade-weighted estimate only if the API didn't send counts.
      final aWinRate = aResolved > 0
          ? (aWins / aResolved * 100)
          : (aWrDen > 0 ? (aWrNum / aWrDen) : 0);
      final hWinRate = hResolved > 0
          ? (hWins / hResolved * 100)
          : (hWrDen > 0 ? (hWrNum / hWrDen) : 0);

      if (mounted) {
        setState(() {
          _agentCount = agentRows.length;
          _humanCount = humanRows.length;
          _agentWin = aWinRate.toDouble();
          _humanWin = hWinRate.toDouble();
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Need at least one agent to make the comparison meaningful.
    if (!_loaded || _agentCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.brand.withValues(alpha: 0.12), t.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: t.brand, size: 18),
              const SizedBox(width: 6),
              Text('Humans vs Agents',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Live win rate · Arc',
              style: TextStyle(color: t.textMuted, fontSize: 11)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ScorePill(
                  emoji: '🤖',
                  label: 'Agents',
                  value: '${_agentWin.toStringAsFixed(1)}%',
                  sub: '$_agentCount on-chain',
                  color: t.brand,
                  bg: t.brandSubtle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScorePill(
                  emoji: '🧑',
                  label: 'Humans',
                  value: _humanCount > 0
                      ? '${_humanWin.toStringAsFixed(1)}%'
                      : '—',
                  sub: '$_humanCount traders',
                  color: t.text,
                  bg: t.surfaceRaised,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.emoji,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.bg,
  });

  final String emoji;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulsEmojiText('$emoji $label',
              style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: t.textSubtle, fontSize: 10)),
        ],
      ),
    );
  }
}
