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

  void _resetDrag() {
    if (!mounted) {
      return;
    }
    setState(() => _dragX = 0);
  }

  void _commitSwipe(MarketSide side) {
    _resetDrag();
    widget.onChoose(side);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    final market = widget.market;
    final trendColor =
        market.trendIsPositive ? PulsColors.green : PulsColors.coral;
    final swipeProgress = (_dragX.abs() / 140).clamp(0.0, 1.0);
    final swipeSide = _dragX >= 0 ? MarketSide.yes : MarketSide.no;

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() => _dragX = (_dragX + details.delta.dx).clamp(-180, 180));
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_dragX > 82 || velocity > 700) {
          _commitSwipe(MarketSide.yes);
        } else if (_dragX < -82 || velocity < -700) {
          _commitSwipe(MarketSide.no);
        } else {
          _resetDrag();
        }
      },
      onHorizontalDragCancel: _resetDrag,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: Transform.translate(
          offset: Offset(_dragX, 0),
          child: Transform.rotate(
            angle: _dragX / 1800,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.panel,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.border),
                boxShadow: [
                  BoxShadow(
                    color: (_dragX == 0
                            ? PulsColors.blue
                            : swipeSide == MarketSide.yes
                                ? PulsColors.green
                                : PulsColors.coral)
                        .withValues(alpha: 0.10 + swipeProgress * 0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tokens.panelElevated,
                              tokens.panel,
                              tokens.ink.withValues(alpha: 0.96),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _SwipeCue(
                          progress: swipeProgress,
                          side: swipeSide,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Tag(label: market.category),
                              const SizedBox(width: 8),
                              _Tag(label: market.volume),
                              const Spacer(),
                              IconButton(
                                onPressed: widget.onWatchlist,
                                tooltip: widget.isWatchlisted
                                    ? 'Remove watch'
                                    : 'Add watch',
                                icon: Icon(
                                  widget.isWatchlisted
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  color: widget.isWatchlisted
                                      ? PulsColors.amber
                                      : tokens.muted,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            market.question,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            market.context,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: tokens.muted,
                                    ),
                          ),
                          const SizedBox(height: 18),
                          _OddsBar(market: market),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _Signal(
                                icon: Icons.trending_up_rounded,
                                label:
                                    '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                                color: trendColor,
                              ),
                              const SizedBox(width: 10),
                              _Signal(
                                icon: Icons.water_drop_outlined,
                                label: 'Liq ${market.liquidity}',
                                color: PulsColors.cyan,
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: widget.onDetails,
                                icon: const Icon(Icons.open_in_new_rounded,
                                    size: 18),
                                label: const Text('Details'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _SideButton(
                                  label: 'YES',
                                  price: TradeMath.formatPrice(market.yesPrice),
                                  color: PulsColors.green,
                                  onPressed: () =>
                                      widget.onChoose(MarketSide.yes),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SideButton(
                                  label: 'NO',
                                  price: TradeMath.formatPrice(market.noPrice),
                                  color: PulsColors.coral,
                                  onPressed: () =>
                                      widget.onChoose(MarketSide.no),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Swipe right for Yes, left for No',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 12),
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
        ),
      ),
    );

    return card.animate().fadeIn(duration: 220.ms, curve: Curves.easeOut).scale(
          begin: const Offset(0.98, 0.98),
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _SwipeCue extends StatelessWidget {
  const _SwipeCue({required this.progress, required this.side});

  final double progress;
  final MarketSide side;

  @override
  Widget build(BuildContext context) {
    if (progress == 0) {
      return const SizedBox.shrink();
    }

    final isYes = side == MarketSide.yes;
    final color = isYes ? PulsColors.green : PulsColors.coral;
    final alignment = isYes ? Alignment.centerLeft : Alignment.centerRight;
    final label = isYes ? 'YES' : 'NO';

    return AnimatedOpacity(
      opacity: progress,
      duration: const Duration(milliseconds: 80),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08 * progress),
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Transform.rotate(
              angle: isYes ? -0.16 : 0.16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
            Text(
              'Yes ${TradeMath.formatPrice(market.yesPrice)}',
              style: const TextStyle(
                color: PulsColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              'No ${TradeMath.formatPrice(market.noPrice)}',
              style: const TextStyle(
                color: PulsColors.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (market.yesPrice * 100).round(),
                  child: Container(color: PulsColors.green),
                ),
                Expanded(
                  flex: (market.noPrice * 100).round(),
                  child: Container(color: PulsColors.coral),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.price,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String price;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.66)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
            Text(price, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.panelSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
