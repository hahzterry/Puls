import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/models/market.dart';

class PredictionFeedCard extends StatefulWidget {
  const PredictionFeedCard({
    required this.market,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onDetails,
    required this.onChoose,
    super.key,
  });

  final Market market;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onDetails;
  final ValueChanged<MarketSide> onChoose;

  @override
  State<PredictionFeedCard> createState() => _PredictionFeedCardState();
}

class _PredictionFeedCardState extends State<PredictionFeedCard> {
  double _dragX = 0;

  void _reset() {
    if (mounted) setState(() => _dragX = 0);
  }

  void _commit(MarketSide side) {
    _reset();
    widget.onChoose(side);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final market = widget.market;
    final progress = (_dragX.abs() / 140).clamp(0.0, 1.0);
    final side = _dragX >= 0 ? MarketSide.yes : MarketSide.no;
    final swipeColor = side == MarketSide.yes ? PulsColors.green : PulsColors.red;
    final hasImage = market.imageUrl.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) =>
          setState(() => _dragX = (_dragX + d.delta.dx).clamp(-180.0, 180.0)),
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_dragX > 82 || v > 700) {
          _commit(MarketSide.yes);
        } else if (_dragX < -82 || v < -700) {
          _commit(MarketSide.no);
        } else {
          _reset();
        }
      },
      onHorizontalDragCancel: _reset,
      child: Transform.translate(
        offset: Offset(_dragX, 0),
        child: Transform.rotate(
          angle: _dragX / 2400,
          child: Container(
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: progress > 0.1
                    ? swipeColor.withValues(alpha: progress * 0.5)
                    : t.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Swipe tint overlay
                if (progress > 0)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: progress * 0.08,
                      duration: const Duration(milliseconds: 60),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: swipeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                // Card content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: tags + swipe badge + bookmark
                      Row(
                              children: [
                                _Tag(label: market.category, t: t),
                                const SizedBox(width: 8),
                                _Tag(label: market.volume, t: t),
                                const Spacer(),
                                if (progress > 0.2)
                                  AnimatedOpacity(
                                    opacity: ((progress - 0.2) / 0.8)
                                        .clamp(0, 1),
                                    duration:
                                        const Duration(milliseconds: 80),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: swipeColor,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        side == MarketSide.yes
                                            ? 'YES'
                                            : 'NO',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: widget.onWatchlist,
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    size: 20,
                                    color: widget.isWatchlisted
                                        ? PulsColors.amber
                                        : t.textSubtle,
                                  ),
                                ),
                              ],
                            ),
                      // Image inside card
                      if (hasImage) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            market.imageUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Question
                            Text(
                              market.question,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium,
                              maxLines: hasImage ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!hasImage && market.context.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                market.context,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(height: 1.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 14),
                            // Odds bar
                            _OddsBar(market: market),
                            const SizedBox(height: 14),
                            // Stats + details
                            Row(
                              children: [
                                _Stat(
                                  icon: Icons.trending_up_rounded,
                                  label:
                                      '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                                  color: market.trendIsPositive
                                      ? PulsColors.green
                                      : PulsColors.red,
                                ),
                                const SizedBox(width: 8),
                                _Stat(
                                  icon: Icons.water_drop_outlined,
                                  label: market.liquidity,
                                  color: t.textMuted,
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: widget.onDetails,
                                  child: Row(
                                    children: [
                                      Text('Details',
                                          style: TextStyle(
                                              color: t.brand,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 2),
                                      Icon(Icons.arrow_forward_rounded,
                                          size: 14, color: t.brand),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // YES / NO buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _SideBtn(
                                    label: 'YES',
                                    price: TradeMath.formatPrice(
                                        market.yesPrice),
                                    bg: PulsColors.greenLight,
                                    fg: PulsColors.green,
                                    onPressed: () =>
                                        widget.onChoose(MarketSide.yes),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SideBtn(
                                    label: 'NO',
                                    price: TradeMath.formatPrice(
                                        market.noPrice),
                                    bg: PulsColors.redLight,
                                    fg: PulsColors.red,
                                    onPressed: () =>
                                        widget.onChoose(MarketSide.no),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'Swipe right for Yes · left for No',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.04, duration: 200.ms, curve: Curves.easeOut);
  }
}

class _OddsBar extends StatelessWidget {
  const _OddsBar({required this.market});
  final Market market;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('Yes ${TradeMath.formatPrice(market.yesPrice)}',
                style: const TextStyle(
                    color: PulsColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const Spacer(),
            Text('No ${TradeMath.formatPrice(market.noPrice)}',
                style: const TextStyle(
                    color: PulsColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(
                  flex: (market.yesPrice * 100).round(),
                  child: const ColoredBox(color: PulsColors.green),
                ),
                Expanded(
                  flex: (market.noPrice * 100).round(),
                  child: const ColoredBox(color: PulsColors.red),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideBtn extends StatelessWidget {
  const _SideBtn({
    required this.label,
    required this.price,
    required this.bg,
    required this.fg,
    required this.onPressed,
  });
  final String label;
  final String price;
  final Color bg;
  final Color fg;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
            Text(price,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: fg.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.t});
  final String label;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(label,
          style: TextStyle(
              color: t.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
