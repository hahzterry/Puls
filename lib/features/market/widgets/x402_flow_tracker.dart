import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// x402 nanopayment flow tracker — shows recent nanopayments between agents.
/// Fetches from /api/x402/payments and displays who paid whom, for what, how much.
class X40FlowTracker extends StatefulWidget {
  const X40FlowTracker({super.key});

  @override
  State<X40FlowTracker> createState() => _X40FlowTrackerState();
}

class _X40FlowTrackerState extends State<X40FlowTracker> {
  List<Map<String, dynamic>> _payments = [];
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
      final res = await http.get(Uri.parse('$backendUrl/api/x402/payments?limit=100')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List rawList;
        if (data is List) {
          rawList = data;
        } else {
          rawList = (data['payments'] as List? ?? []);
        }
        final list = rawList.cast<Map<String, dynamic>>();
        if (mounted) setState(() { _payments = list.take(40).toList(); _loading = false; });
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
    final totalVol = _payments.fold<double>(0, (s, p) => s + ((p['amount_usdc'] as num?)?.toDouble() ?? 0));

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
                Text('x402 NANOPAYMENT FLOW',
                    style: TextStyle(color: t.textSubtle, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1.5)),
                const Spacer(),
                Text('\$${totalVol.toStringAsFixed(2)} VOL',
                    style: const TextStyle(color: Color(0xFFA855F7), fontSize: 11, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFA855F7)))
                : _payments.isEmpty
                    ? Center(child: Text('No nanopayments yet', style: TextStyle(color: t.textSubtle, fontSize: 12, fontFamily: PulsColors.fontMono)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _payments.length,
                        itemBuilder: (context, i) => _PaymentRow(payment: _payments[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final endpoint = (payment['endpoint'] as String? ?? 'unknown').toUpperCase();
    final amount = (payment['amountUsdc'] as num?)?.toDouble() ?? (payment['amount_usdc'] as num?)?.toDouble() ?? (payment['amount'] as num?)?.toDouble() ?? 0;
    final payerStr = payment['from'] as String? ?? payment['fromLabel'] as String? ?? payment['payerShort'] as String? ?? payment['payer'] as String? ?? 'HUMAN';
    final payeeStr = payment['to'] as String? ?? payment['toLabel'] as String? ?? payment['payeeShort'] as String? ?? payment['pay_to'] as String? ?? 'TREASURY';
    final ts = (payment['created_at'] as String? ?? payment['createdAt'] as String? ?? '');
    final time = ts.length >= 19 ? ts.substring(11, 19) : (ts.length >= 8 ? ts.substring(11) : '--:--:--');

    final payerShort = payerStr.length > 12 ? '${payerStr.substring(0, 5)}…' : payerStr;
    final payeeShort = payeeStr.length > 12 ? '${payeeStr.substring(0, 5)}…' : payeeStr;

    // Color by endpoint
    Color color;
    switch (endpoint) {
      case 'TIP': case 'BLOG_TIP': color = const Color(0xFFEC4899); break;
      case 'SIGNAL_UNLOCK': case 'ALPHA_UNLOCK': color = PulsColors.brandMint; break;
      case 'AGENT_TO_AGENT': color = const Color(0xFFA855F7); break;
      case 'COPY_FEE': color = PulsColors.brandMint; break;
      case 'STREAM_SETTLE': color = const Color(0xFFEAB308); break;
      case 'DIRECTOR': color = const Color(0xFF3B82F6); break;
      default: color = t.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: 0.5))),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(time, style: TextStyle(color: t.textSubtle, fontSize: 11, fontFamily: PulsColors.fontMono))),
          SizedBox(width: 60, child: Text(payerShort, style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono))),
          Icon(Icons.arrow_forward_rounded, size: 10, color: t.textSubtle),
          const SizedBox(width: 2),
          SizedBox(width: 60, child: Text(payeeShort, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(endpoint, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono, letterSpacing: 0.3)),
          ),
          const Spacer(),
          Text('\$${amount.toStringAsFixed(4)}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
        ],
      ),
    );
  }
}
