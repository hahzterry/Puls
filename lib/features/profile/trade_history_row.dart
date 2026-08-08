import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// One row in a trade history list (own profile + trader profiles).
///
/// Shows the question, action (Bought/Sold/Claimed), amount and a link to the
/// transaction on Arcscan. Kept self-contained so both profile screens render
/// identical rows.
class TradeHistoryRow extends StatelessWidget {
  const TradeHistoryRow({super.key, required this.trade, required this.t});

  final dynamic trade;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final side = trade['side'] as String? ?? 'YES';
    final amt = _parseFloat(trade['usdc_amount']);
    final isBuy = amt > 0;
    final isClaim = side == 'CLAIM';

    Color amountColor = t.text;
    String actionLabel = '';

    if (isClaim) {
      amountColor = t.yes;
      actionLabel = 'Claimed Winnings';
    } else if (isBuy) {
      amountColor = t.no; // spending money
      actionLabel = 'Bought $side';
    } else {
      amountColor = t.yes; // earning money from sell
      actionLabel = 'Sold $side';
    }

    final displayAmt = isClaim
        ? '\$0.00'
        : '${isBuy ? '-' : '+'}\$${amt.abs().toStringAsFixed(2)}';

    final date = DateTime.tryParse(trade['created_at'] as String? ?? '') ??
        DateTime.now();
    final formattedDate =
        '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isClaim
                  ? t.yesBg
                  : isBuy
                      ? t.noBg
                      : t.yesBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isClaim
                  ? Icons.emoji_events_outlined
                  : isBuy
                      ? Icons.shopping_basket_outlined
                      : Icons.sell_outlined,
              color: isClaim
                  ? t.yes
                  : isBuy
                      ? t.no
                      : t.yes,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trade['question'] ?? 'Prediction Trade',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.text, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$actionLabel · $formattedDate',
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayAmt,
                style: TextStyle(
                    color: amountColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              if (trade['tx_hash'] != null &&
                  (trade['tx_hash'] as String).isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse(
                        'https://testnet.arcscan.app/tx/${trade['tx_hash']}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View Tx',
                        style: TextStyle(
                            color: t.brand,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.open_in_new_rounded, size: 8, color: t.brand),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

double _parseFloat(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
