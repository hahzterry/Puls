import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Cross-market arbitrage scanner вЂ” looks for price discrepancies
/// between markets on the same topic (e.g., "Will X win?" at different
/// price levels on different markets, or complementary YES/NO prices).
class ArbitrageScanner extends StatefulWidget {
  const ArbitrageScanner({super.key});

  @override
  State<ArbitrageScanner> createState() => _ArbitrageScannerState();
}

class _ArbitrageScannerState extends State<ArbitrageScanner> {
  List<Map<String, dynamic>> _markets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/markets?limit=200'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final markets = (data is List ? data : (data['markets'] as List? ?? []))
            .cast<Map<String, dynamic>>();
        if (mounted)
          setState(() {
            _markets = markets;
            _loading = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ArbOpportunity> _findArbitrage() {
    // Find markets where YES + NO prices don't sum to ~100%
    // (i.e., YES price + NO price < 0.95 в†’ buy both for guaranteed profit)
    final opps = <_ArbOpportunity>[];
    for (final m in _markets) {
      final yes = (m['yesPrice'] as num?)?.toDouble() ?? 0;
      final no = 1.0 - yes;
      final sum = yes + no;
      final spread = 1.0 - sum; // positive = profitable
      if (spread > 0.02 && yes > 0.05 && yes < 0.95) {
        final slug = (m['slug'] as String?) ?? 'unknown';
        final vol = (m['volumeNum'] as num?)?.toDouble() ??
            (m['volume24hr'] as num?)?.toDouble() ??
            0;
        final profit =
            spread * (vol > 0 ? vol * 0.01 : 100); // estimated profit per $100
        opps.add(_ArbOpportunity(slug, yes, no, spread, profit));
      }
    }
    opps.sort((a, b) => b.spread.compareTo(a.spread));
    return opps.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final opps = _loading ? [] : _findArbitrage();

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
                Text('ARBITRAGE SCANNER',
                    style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: PulsColors.fontMono,
                        letterSpacing: 1.5)),
                const Spacer(),
                Text('${opps.length} OPPS',
                    style: const TextStyle(
                        color: PulsColors.brandMint,
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
                        strokeWidth: 1.5, color: PulsColors.brandMint))
                : opps.isEmpty
                    ? Center(
                        child: Text('No arbitrage opportunities',
                            style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 12,
                                fontFamily: PulsColors.fontMono)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: opps.length,
                        itemBuilder: (context, i) => _ArbRow(opp: opps[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ArbOpportunity {
  final String slug;
  final double yesPrice;
  final double noPrice;
  final double spread;
  final double estProfit;
  _ArbOpportunity(
      this.slug, this.yesPrice, this.noPrice, this.spread, this.estProfit);
}

class _ArbRow extends StatelessWidget {
  const _ArbRow({required this.opp});
  final _ArbOpportunity opp;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final q = opp.slug.replaceAll('-', ' ');
    final qShort = q.length > 35 ? '${q.substring(0, 34)}…' : q;
    final spreadPct = (opp.spread * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: t.border, width: 0.5))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
                color: PulsColors.brandMint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3)),
            child: Text('+$spreadPct%',
                style: const TextStyle(
                    color: PulsColors.brandMint,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: PulsColors.fontMono)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(qShort,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 11,
                      fontFamily: PulsColors.fontMono))),
          const SizedBox(width: 6),
          Text('${(opp.yesPrice * 100).round()}¢',
              style: const TextStyle(
                  color: PulsColors.brandMint,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: PulsColors.fontMono)),
          Text('/',
              style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 11,
                  fontFamily: PulsColors.fontMono)),
          Text('${(opp.noPrice * 100).round()}¢',
              style: const TextStyle(
                  color: Color(0xFFEC4899),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: PulsColors.fontMono)),
        ],
      ),
    );
  }
}
