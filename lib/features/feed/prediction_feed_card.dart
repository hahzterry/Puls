import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:picons/picons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/puls_emoji_text.dart';
import '../../core/motion.dart';
import '../../core/widgets/tactile.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/puls_sparkline.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/trade_math.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/market.dart';
import '../../data/polymarket/price_history_service.dart';
import 'package:puls/core/config.dart';

class PredictionFeedCard extends StatefulWidget {
  const PredictionFeedCard({
    required this.market,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onDetails,
    required this.onChoose,
    this.showSwipeHint = false,
    super.key,
  });

  final Market market;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onDetails;
  final ValueChanged<MarketSide> onChoose;

  /// When true (first card in the feed), plays a one-time "peek" animation
  /// nudging the card right then left so users discover swipe-to-trade.
  final bool showSwipeHint;

  @override
  State<PredictionFeedCard> createState() => _PredictionFeedCardState();
}

class _PredictionFeedCardState extends State<PredictionFeedCard>
    with TickerProviderStateMixin {
  // Once per app session — not on every rebuild of the first card.
  static bool _swipeHintPlayed = false;

  late final ValueNotifier<double> _dragX;
  List<double> _sparkline = [];
  bool _hasTriggeredHaptic = false;
  AnimationController? _hintCtrl;

  // Release animation: spring-return to centre, or fling the card off-screen.
  AnimationController? _releaseCtrl;
  bool _flinging = false; // true while the card is flying off after a commit

  @override
  void initState() {
    super.initState();
    _dragX = ValueNotifier<double>(0.0);
    PriceHistoryService.fetch(widget.market.clobTokenId).then((prices) {
      if (mounted) setState(() => _sparkline = prices);
    });
    if (widget.showSwipeHint && !_swipeHintPlayed) {
      _swipeHintPlayed = true;
      _scheduleSwipeHint();
    }
  }

  void _scheduleSwipeHint() {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _hintCtrl = ctrl;
    final anim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 68.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 26),
      TweenSequenceItem(
          tween: Tween(begin: 68.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -54.0)
              .chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 26),
      TweenSequenceItem(
          tween: Tween(begin: -54.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 26),
    ]).animate(ctrl);
    anim.addListener(() {
      if (_hintCtrl != null) _dragX.value = anim.value;
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || _hintCtrl != ctrl) return;
      // Reduce-motion: skip the auto swipe-hint nudge entirely.
      if (context.reduceMotion) {
        _cancelSwipeHint();
        return;
      }
      ctrl.forward();
    });
  }

  void _cancelSwipeHint() {
    final ctrl = _hintCtrl;
    if (ctrl == null) return;
    _hintCtrl = null;
    ctrl.stop();
    ctrl.dispose();
  }

  @override
  void dispose() {
    _cancelSwipeHint();
    _releaseCtrl?.dispose();
    _dragX.dispose();
    super.dispose();
  }

  // Animate _dragX from its current value to [target] with a custom curve.
  // onDone fires at the end (used to fire the trade after the card flies off).
  void _animateDragTo(double target,
      {required Duration duration,
      required Curve curve,
      VoidCallback? onDone}) {
    _releaseCtrl?.dispose();
    final ctrl = AnimationController(vsync: this, duration: duration);
    _releaseCtrl = ctrl;
    final from = _dragX.value;
    final anim = Tween<double>(begin: from, end: target)
        .chain(CurveTween(curve: curve))
        .animate(ctrl);
    anim.addListener(() => _dragX.value = anim.value);
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) onDone?.call();
    });
    ctrl.forward();
  }

  // Spring back to centre when the swipe didn't cross the threshold.
  void _springBack() {
    _hasTriggeredHaptic = false;
    _animateDragTo(0.0,
        duration: const Duration(milliseconds: 420), curve: Curves.elasticOut);
  }

  void _reset() {
    _releaseCtrl?.dispose();
    _releaseCtrl = null;
    _dragX.value = 0.0;
    _hasTriggeredHaptic = false;
    _flinging = false;
  }

  // Commit: heavy haptic, fling the card off-screen in the swipe direction with
  // inertia, THEN fire the trade callback — so the gesture feels physical.
  void _commit(MarketSide side) {
    if (_flinging) return;
    _flinging = true;
    hapticHeavy();
    final dir = side == MarketSide.yes ? 1.0 : -1.0;
    _animateDragTo(
      dir * 1000.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      onDone: () {
        widget.onChoose(side);
        // Parent advances the feed; reset so a reused card starts centred.
        _reset();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final market = widget.market;

    // Yes price formatted as cents (e.g. "62¢") for a concise screen-reader
    // summary — the same compact form sighted users get from the odds bar.
    final yesCents = (market.yesPrice * 100).round();
    final noCents = 100 - yesCents;
    final yesPct = '$yesCents%';
    final noPct = '$noCents%';

    return Semantics(
        // Container so screen readers announce the card as a single labelled
        // group, then the actionable children (YES/NO buttons, Details link,
        // bookmark) get their own labels. Without this, VoiceOver/TalkBack would
        // read every Text node in the card in sequence, with no context for
        // what the swipe gesture does.
        container: true,
        label: 'Prediction market: ${market.question}. '
            'Yes $yesPct, No $noPct. '
            'Swipe right to buy Yes, swipe left to buy No.',
        hint: 'Swipe right for Yes, swipe left for No. '
            'Double-tap Details for the full market.',
        // Exclude the drag gesture from semantics — the YES/NO buttons below
        // are the accessible fallback for screen-reader users (a swipe gesture
        // has no canonical screen-reader representation). The drag itself is
        // excluded so the reader doesn't announce a meaningless "custom" action.
        excludeSemantics: false,
        child: RepaintBoundary(
            child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _cancelSwipeHint();
            _releaseCtrl?.dispose();
            _releaseCtrl = null;
            _flinging = false;
            _dragX.value = 0.0;
          },
          onHorizontalDragUpdate: (d) {
            if (_flinging) return;
            _dragX.value = (_dragX.value + d.delta.dx).clamp(-180.0, 180.0);
            final absDrag = _dragX.value.abs();
            if (absDrag > 82) {
              if (!_hasTriggeredHaptic) {
                // Crossed the commit threshold — a firm "you're about to trade" cue.
                hapticMedium();
                _hasTriggeredHaptic = true;
              }
            } else {
              if (_hasTriggeredHaptic) {
                _hasTriggeredHaptic = false;
              }
            }
          },
          onHorizontalDragEnd: (d) {
            if (_flinging) return;
            final v = d.primaryVelocity ?? 0;
            final currentDrag = _dragX.value;
            if (currentDrag > 82 || v > 700) {
              _commit(MarketSide.yes);
            } else if (currentDrag < -82 || v < -700) {
              _commit(MarketSide.no);
            } else {
              _springBack();
            }
          },
          onHorizontalDragCancel: _springBack,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragX,
            builder: (context, dragX, child) {
              final progress = (dragX.abs() / 140).clamp(0.0, 1.0);
              final side = dragX >= 0 ? MarketSide.yes : MarketSide.no;
              final swipeColor = side == MarketSide.yes ? t.yes : t.no;

              return Transform.translate(
                offset: Offset(dragX, 0),
                child: Transform.rotate(
                  angle: (dragX / 180) * 0.18, // tilt up to ~10° at full drag
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: t.surfaceRaised,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: progress > 0.1
                            ? swipeColor.withValues(alpha: progress * 0.5)
                            : t.border,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: progress > 0.1
                              ? swipeColor.withValues(alpha: progress * 0.25)
                              : const Color(0xFFEC4899)
                                  .withValues(alpha: 0.045),
                          blurRadius: 18 + progress * 20,
                          offset: Offset(dragX * 0.05, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Swipe color wave — rises from the bottom as you drag.
                        if (progress > 0)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        swipeColor.withValues(
                                            alpha: 0.35 * progress),
                                        swipeColor.withValues(
                                            alpha: 0.08 * progress),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, progress * 0.6, progress],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Tinder-style angled YES/NO stamp — YES pins to the top-left
                        // and tilts left; NO pins to the top-right and tilts right.
                        if (progress > 0.05)
                          Positioned(
                            top: 22,
                            left: side == MarketSide.yes ? 20 : null,
                            right: side == MarketSide.no ? 20 : null,
                            child: Opacity(
                              opacity:
                                  ((progress - 0.05) / 0.45).clamp(0.0, 1.0),
                              child: Transform.rotate(
                                angle: side == MarketSide.yes ? -0.32 : 0.32,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: swipeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: swipeColor, width: 4),
                                  ),
                                  child: Text(
                                    side == MarketSide.yes ? 'YES' : 'NO',
                                    style: TextStyle(
                                      color: swipeColor,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Card content (Expensive static part) — wrapped in a
                        // RepaintBoundary so it doesn't repaint when _dragX changes.
                        // The drag animation (transform, shadow, gradient wave)
                        // happens in the outer ValueListenableBuilder; this child
                        // (image, sparkline, text, buttons) is static per market.
                        RepaintBoundary(child: child!),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: tags + swipe badge + bookmark
                  Row(
                    children: [
                      _Tag(label: market.category, t: t),
                      const SizedBox(width: 8),
                      _Tag(label: market.volume, t: t),
                      if (market.createdByAgent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const PulsEmojiText('🤖 Agent',
                              style: TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                      const Spacer(),
                      // A tiny live stamp during drag supplements
                      // the big Tinder stamp (kept) — removed the
                      // redundant mid-sized YES/NO pill to declutter
                      // the tag row.
                      Semantics(
                        button: true,
                        toggled: widget.isWatchlisted,
                        label: widget.isWatchlisted
                            ? 'Remove from watchlist'
                            : 'Add to watchlist',
                        hint: 'Saves this market to your watchlist '
                            'so you can find it later.',
                        excludeSemantics: true,
                        child: Tactile(
                          onTap: widget.onWatchlist,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.bookmark_rounded,
                              size: 20,
                              color: widget.isWatchlisted
                                  ? PulsColors.amber
                                  : t.textSubtle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Question
                  Text(
                    market.question,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Topic image — recessed into the card with a top scrim.
                  // NOTE: intentionally NOT a Hero. A Hero whose tag repeats
                  // across recycled list slots throws "multiple heroes share
                  // the same tag" and blanked the whole feed. The detail
                  // screen keeps its own hero image; the cross-fade flight
                  // is simply skipped from the feed side.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: t.border.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                          market.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: proxifyImageUrl(
                                      _proxied(market.imageUrl)),
                                  height: 130,
                                  width: double.infinity,
                                  memCacheHeight: 260,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const Skeleton(height: 130, radius: 0),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    height: 130,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                        gradient: PulsColors.pulseGradient),
                                  ),
                                )
                              : Container(
                                  height: 130,
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    gradient: PulsColors.pulseGradient,
                                  ),
                                ),
                          // Soft top scrim — visually recesses the image
                          // into the card instead of floating on it.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Theme.of(context)
                                          .scaffoldBackgroundColor
                                          .withValues(alpha: 0.16),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.32],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (market.context.isNotEmpty) ...[
                    Text(
                      market.context,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: t.textMuted,
                            height: 1.4,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Odds bar
                  _OddsBar(market: market),
                  const SizedBox(height: 12),
                  // Sparkline — always 48px, shows a quiet surface
                  // while loading. CustomPainter renders a smooth line,
                  // no per-rebuild animation cost in the scroll list.
                  PulsSparkline(
                    prices: _sparkline,
                    color: (_sparkline.length >= 2
                            ? _sparkline.last >= _sparkline.first
                            : market.trendIsPositive)
                        ? context.puls.yes
                        : context.puls.no,
                    height: 48,
                  ),
                  const SizedBox(height: 8),
                  // Stats + details
                  Row(
                    children: [
                      _Stat(
                        icon: Picons.trendUp,
                        label:
                            '${market.trendIsPositive ? '+' : ''}${TradeMath.formatPercent(market.trend)}',
                        color: market.trendIsPositive ? t.yes : t.no,
                      ),
                      const SizedBox(width: 8),
                      if (market.volume24hr > 0)
                        _Stat(
                          icon: Picons.chartBar,
                          label: compactUsd(market.volume24hr),
                          color: t.textMuted,
                        )
                      else
                        _Stat(
                          icon: Picons.drop,
                          label: market.liquidity,
                          color: t.textMuted,
                        ),
                      if (market.spread > 0) ...[
                        const SizedBox(width: 8),
                        _Stat(
                          icon: Picons.arrowsLeftRight,
                          label: 'Spread ${formatCents(market.spread)}',
                          color: t.textMuted,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'View details for ${market.question}',
                        hint: 'Opens the full market page with '
                            'charts, analysis and trade options.',
                        excludeSemantics: true,
                        child: Tactile(
                          onTap: widget.onDetails,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
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
                          price: TradeMath.formatPrice(market.yesPrice),
                          bg: t.yesBg,
                          fg: t.yes,
                          onPressed: () => widget.onChoose(MarketSide.yes),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SideBtn(
                          label: 'NO',
                          price: TradeMath.formatPrice(market.noPrice),
                          bg: t.noBg,
                          fg: t.no,
                          onPressed: () => widget.onChoose(MarketSide.no),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Single quiet micro-hint — the old duplicate arrow
                  // row fought the buttons above for attention.
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded,
                            size: 11, color: t.no.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text('swipe to pick a side',
                            style: TextStyle(
                                color: t.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 11, color: t.yes.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )));
  }
}

class _OddsBar extends StatelessWidget {
  const _OddsBar({required this.market});
  final Market market;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      children: [
        Row(
          children: [
            Text('Yes ${TradeMath.formatPrice(market.yesPrice)}',
                style: TextStyle(
                    color: t.yes,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontFeatures: PulsColors.tabularFigures)),
            const Spacer(),
            Text('No ${TradeMath.formatPrice(market.noPrice)}',
                style: TextStyle(
                    color: t.no,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    fontFeatures: PulsColors.tabularFigures)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                // Animate the split so price updates glide rather than snap.
                _OddsFlexSegment(
                  flex: (market.yesPrice * 1000).round().clamp(1, 1000),
                  color: t.yes,
                ),
                _OddsFlexSegment(
                  flex: (market.noPrice * 1000).round().clamp(1, 1000),
                  color: t.no,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One half of the odds split. [Expanded] `flex` isn't itself animatable
/// without a controller, and the card exists in a scrollable feed — extra
/// AnimationControllers per-segment are not worth it. Prices per market are
/// effectively static during a browsing session, so a simple split is correct.
class _OddsFlexSegment extends StatelessWidget {
  const _OddsFlexSegment({required this.flex, required this.color});
  final int flex;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: ColoredBox(color: color),
      );
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
    return Semantics(
      button: true,
      label: 'Bet $label at $price',
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        child: Tactile(
          onTap: onPressed,
          pressedScale: 0.97,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fg.withValues(alpha: 0.28)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.4,
                        color: fg)),
                const SizedBox(height: 1),
                Text(price,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: fg.withValues(alpha: 0.75),
                        fontFeatures: PulsColors.tabularFigures)),
              ],
            ),
          ),
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
  final PiconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Picon(icon, size: 14, color: color),
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

String _proxied(String url) {
  if (!kIsWeb || url.isEmpty) return url;
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&w=600&output=webp';
}
