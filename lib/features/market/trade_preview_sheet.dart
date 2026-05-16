import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';

Future<void> showTradePreviewSheet({
  required BuildContext context,
  required Market market,
  required MarketSide side,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TradePreviewSheet(market: market, side: side),
  );
}

class TradePreviewSheet extends StatefulWidget {
  const TradePreviewSheet({
    required this.market,
    required this.side,
    super.key,
  });

  final Market market;
  final MarketSide side;

  @override
  State<TradePreviewSheet> createState() => _TradePreviewSheetState();
}

class _TradePreviewSheetState extends State<TradePreviewSheet> {
  late final TextEditingController _controller;
  double _amount = 50;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final sideColor =
        widget.side == MarketSide.yes ? PulsColors.green : PulsColors.coral;
    final sideLabel = widget.side == MarketSide.yes ? 'Yes' : 'No';
    final price = widget.side == MarketSide.yes
        ? widget.market.yesPrice
        : widget.market.noPrice;
    final payout = TradeMath.estimatedPayout(amount: _amount, price: price);
    final profit = TradeMath.estimatedProfit(amount: _amount, price: price);
    final canSubmit = _amount > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PulsColors.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PulsColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PulsColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sideColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      sideLabel.toUpperCase(),
                      style: TextStyle(
                        color: sideColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Demo trade preview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(widget.market.question, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mock amount',
                  prefixText: '\$',
                ),
                onChanged: (value) {
                  setState(() => _amount = double.tryParse(value) ?? 0);
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [25, 50, 100, 250].map((amount) {
                  return ChoiceChip(
                    label: Text('\$$amount'),
                    selected: _amount == amount,
                    onSelected: (_) {
                      setState(() {
                        _amount = amount.toDouble();
                        _controller.text = amount.toString();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _PreviewRow(label: 'Price', value: TradeMath.formatPrice(price)),
              _PreviewRow(label: 'Estimated shares', value: payout.toStringAsFixed(2)),
              _PreviewRow(label: 'Max payout if correct', value: '\$${payout.toStringAsFixed(2)}'),
              _PreviewRow(label: 'Estimated profit', value: '\$${profit.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PulsColors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PulsColors.amber.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'Demo only. This prototype does not place real trades or move money.',
                  style: TextStyle(color: PulsColors.amber, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: canSubmit
                      ? () {
                          appState.addDemoPosition(
                            market: widget.market,
                            side: widget.side,
                            amount: _amount,
                          );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added demo $sideLabel position to portfolio.',
                              ),
                            ),
                          );
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: PulsColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Confirm demo trade'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: PulsColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
