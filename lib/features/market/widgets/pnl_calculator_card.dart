import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Interactive P&L and Potential Return Calculator for Prediction Markets
class PnlCalculatorCard extends StatefulWidget {
  const PnlCalculatorCard({
    super.key,
    required this.marketQuestion,
    required this.yesProbability, // 0.0 to 1.0
  });

  final String marketQuestion;
  final double yesProbability;

  @override
  State<PnlCalculatorCard> createState() => _PnlCalculatorCardState();
}

class _PnlCalculatorCardState extends State<PnlCalculatorCard> {
  double _amount = 10.0;
  String _side = 'YES'; // 'YES' | 'NO'

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final prob = _side == 'YES'
        ? widget.yesProbability.clamp(0.01, 0.99)
        : (1.0 - widget.yesProbability).clamp(0.01, 0.99);

    final potentialPayout = _amount / prob;
    final netProfit = potentialPayout - _amount;
    final roiPct = (netProfit / _amount) * 100;
    final sideColor = _side == 'YES' ? t.yes : t.no;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: t.brand, size: 18),
              const SizedBox(width: 6),
              Text(
                'Interactive P&L Calculator',
                style: TextStyle(
                  color: t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sideColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(prob * 100).toStringAsFixed(0)}¢ Implied',
                  style: TextStyle(
                    color: sideColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _side = 'YES'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _side == 'YES' ? t.yes.withOpacity(0.15) : t.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _side == 'YES' ? t.yes : t.border,
                        width: _side == 'YES' ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Predict YES (${(widget.yesProbability * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: _side == 'YES' ? t.yes : t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _side = 'NO'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _side == 'NO' ? t.no.withOpacity(0.15) : t.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _side == 'NO' ? t.no : t.border,
                        width: _side == 'NO' ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Predict NO (${((1.0 - widget.yesProbability) * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: _side == 'NO' ? t.no : t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Investment Size',
                style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '\$${_amount.toStringAsFixed(0)} USDC',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: sideColor,
              inactiveTrackColor: t.border,
              thumbColor: sideColor,
              overlayColor: sideColor.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _amount,
              min: 1.0,
              max: 100.0,
              divisions: 99,
              onChanged: (val) => setState(() => _amount = val),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potential Payout',
                      style: TextStyle(color: t.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${potentialPayout.toStringAsFixed(2)} USDC',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Net Profit (ROI)',
                      style: TextStyle(color: t.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${roiPct.toStringAsFixed(1)}% (+\$${netProfit.toStringAsFixed(2)})',
                      style: TextStyle(
                        color: sideColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
