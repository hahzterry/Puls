import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/puls_snack.dart';

class GatewayDepositModal extends StatefulWidget {
  const GatewayDepositModal({
    super.key,
    required this.userAddress,
  });

  final String userAddress;

  static Future<void> show(BuildContext context, {required String userAddress}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GatewayDepositModal(userAddress: userAddress),
    );
  }

  @override
  State<GatewayDepositModal> createState() => _GatewayDepositModalState();
}

class _GatewayDepositModalState extends State<GatewayDepositModal> {
  String _selectedChain = 'base';
  double _amount = 10.0;
  bool _loading = false;
  Map<String, dynamic>? _quote;

  final List<Map<String, String>> _chains = const [
    {'id': 'base', 'name': 'Base', 'icon': '🔵', 'speed': '<2 sec'},
    {'id': 'arbitrum', 'name': 'Arbitrum', 'icon': '🔷', 'speed': '<2 sec'},
    {'id': 'solana', 'name': 'Solana', 'icon': '🟣', 'speed': '<1 sec'},
    {'id': 'ethereum', 'name': 'Ethereum', 'icon': '⟠', 'speed': '~15 min'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/gateway/quote'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fromChainId': _selectedChain,
          'amountUsdc': _amount,
          'destinationAddress': widget.userAddress,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _quote = data['quote'] as Map<String, dynamic>?;
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: t.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: t.brand, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Instant Circle Gateway Bridge',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deposit USDC to Arc Network with sub-second finality',
                style: TextStyle(color: t.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(
                'Source Blockchain',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _chains.map((chain) {
                  final sel = _selectedChain == chain['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedChain = chain['id']!);
                        _fetchQuote();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? t.brand.withOpacity(0.15) : t.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? t.brand : t.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(chain['icon']!, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(
                              chain['name']!,
                              style: TextStyle(
                                color: sel ? t.brand : t.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Amount to Bridge (USDC)',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [5.0, 10.0, 25.0, 50.0, 100.0].map((val) {
                  final sel = _amount == val;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _amount = val);
                        _fetchQuote();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? t.brand : t.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? t.brand : t.border),
                        ),
                        child: Center(
                          child: Text(
                            '\$${val.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: sel ? Colors.white : t.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_quote != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Estimated Speed', style: TextStyle(color: t.textMuted, fontSize: 12)),
                      Text(
                        _quote!['speed'] ?? 'Sub-second',
                        style: TextStyle(color: t.yes, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bridge Fee', style: TextStyle(color: t.textMuted, fontSize: 12)),
                      Text('0.00 USDC (Subsidized)', style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recipient (Your Arc Wallet)', style: TextStyle(color: t.textMuted, fontSize: 12)),
                      Text(
                        widget.userAddress.length > 10
                            ? '${widget.userAddress.substring(0, 6)}...${widget.userAddress.substring(widget.userAddress.length - 4)}'
                            : widget.userAddress,
                        style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                PulsSnack.of(context).show('Circle Gateway deposit intent initiated! ⚡');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Execute Gateway Deposit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
