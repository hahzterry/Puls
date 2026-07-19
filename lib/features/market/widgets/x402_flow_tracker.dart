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
        final list = (data['payments'] as List? ?? []).cast<Map<String, dynamic>>();
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
    final totalVol = _payments.fold<double>(0, (s, p) => s + ((p['amount_usdc'] as num?)?.toDouble() ?? 0));

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
                const Text('x402 NANOPAYMENT FLOW',
                    style: TextStyle(color: Color(0xFF5E6A85), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1.5)),
                const Spacer(),
                Text('\$${totalVol.toStringAsFixed(2)} VOL',
                    style: const TextStyle(color: Color(0xFFA855F7), fontSize: 10, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFA855F7)))
                : _payments.isEmpty
                    ? Center(child: Text('No nanopayments yet', style: TextStyle(color: const Color(0xFF5E6A85), fontSize: 12, fontFamily: PulsColors.fontMono)))
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
    final endpoint = (payment['endpoint'] as String? ?? 'unknown').toUpperCase();
    final amount = (payment['amount_usdc'] as num?)?.toDouble() ?? 0;
    final payer = (payment['payer'] as String? ?? '???');
    final payee = (payment['pay_to'] as String? ?? '???');
    final ts = (payment['created_at'] as String? ?? '');
    final time = ts.length >= 8 ? ts.substring(11, 19) : '--:--:--';

    final isAgent = payer.startsWith('agent_');
    final payerShort = isAgent ? payer.split('_').last.toUpperCase() : 'HUMAN';
    final payeeShort = payee.startsWith('agent_') ? payee.split('_').last.toUpperCase() : 'TREASURY';

    // Color by endpoint
    Color color;
    switch (endpoint) {
      case 'TIP': case 'BLOG_TIP': color = const Color(0xFFEC4899); break;
      case 'SIGNAL_UNLOCK': case 'ALPHA_UNLOCK': color = const Color(0xFF2DD4BF); break;
      case 'AGENT_TO_AGENT': color = const Color(0xFFA855F7); break;
      case 'COPY_FEE': color = const Color(0xFF06B6D4); break;
      case 'STREAM_SETTLE': color = const Color(0xFFEAB308); break;
      case 'DIRECTOR': color = const Color(0xFF3B82F6); break;
      default: color = const Color(0xFF9AA6C0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF0A0E1A), width: 0.5))),
      child: Row(
        children: [
          SizedBox(width: 50, child: Text(time, style: const TextStyle(color: Color(0xFF5E6A85), fontSize: 9, fontFamily: PulsColors.fontMono))),
          SizedBox(width: 60, child: Text(payerShort, style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono))),
          const Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF5E6A85)),
          const SizedBox(width: 2),
          SizedBox(width: 60, child: Text(payeeShort, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono))),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(endpoint, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono, letterSpacing: 0.3)),
          ),
          const Spacer(),
          Text('\$${amount.toStringAsFixed(4)}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
        ],
      ),
    );
  }
}
