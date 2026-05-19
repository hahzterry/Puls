import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_util.dart';
import '../../data/models/market.dart';
import '../../data/polymarket/price_history_service.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import '../shell/web_layout.dart';
import 'prediction_feed_card.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isMobileWeb = kIsWeb && MediaQuery.sizeOf(context).width < 600;

    if (kIsWeb && !isMobileWeb) {
      return Scaffold(
        backgroundColor: t.bg,
        body: WebLayout(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _FeedHeader(t: t)),
              _WebFeedBody(appState: appState, t: t),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _FeedHeader(t: t),
            Expanded(child: _FeedBody(appState: appState, t: t)),
          ],
        ),
      ),
    );
  }
}

class _FeedBody extends StatefulWidget {
  const _FeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  @override
  State<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends State<_FeedBody> {
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final t = widget.t;
    switch (appState.feedStatus) {
      case FeedStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                    color: t.brand, strokeWidth: 2.5),
              ),
              const SizedBox(height: 16),
              Text('Loading live markets…',
                  style: TextStyle(color: t.textMuted, fontSize: 14)),
              const SizedBox(height: 6),
              Text('Fetching from Polymarket',
                  style: TextStyle(color: t.textSubtle, fontSize: 12)),
            ],
          ),
        );

      case FeedStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, color: t.textSubtle, size: 40),
                const SizedBox(height: 16),
                Text('Could not load markets',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: appState.refresh,
                  style: FilledButton.styleFrom(
                    backgroundColor: t.brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );

      case FeedStatus.loaded:
        final markets = appState.feedMarkets;
        if (markets.isEmpty) {
          return Center(
            child: Text('No markets available.',
                style: TextStyle(color: t.textMuted)),
          );
        }
        return RefreshIndicator(
          color: t.brand,
          onRefresh: appState.refresh,
          child: PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: markets.length,
            itemBuilder: (context, index) {
              final market = markets[index];
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top - 140,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                      child: PredictionFeedCard(
                        market: market,
                        isWatchlisted: appState.isWatchlisted(market.id),
                        onWatchlist: () => appState.toggleWatchlist(market.id),
                        onDetails: () => _openDetails(context, market),
                        onChoose: (side) {
                          if (appState.fastBuyEnabled) {
                            _fastBuy(context, appState, market, side,
                                onDone: _nextPage);
                          } else {
                            showTradePreviewSheet(
                              context: context,
                              market: market,
                              side: side,
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
    }
  }

  void _openDetails(BuildContext context, Market market) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MarketDetailScreen(marketId: market.id)),
    );
  }

  Future<void> _fastBuy(
    BuildContext context,
    PulsAppState appState,
    Market market,
    MarketSide side, {
    VoidCallback? onDone,
  }) async {
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;

    if (ws.userId == null || !ws.hasWallet) {
      _showToast(context, '⚡ Connect wallet first', isError: true);
      return;
    }

    final isYes = side == MarketSide.yes;
    final amount = appState.fastBuyAmount;
    final label = isYes ? 'YES' : 'NO';

    // Advance to next card immediately — don't wait for trade
    onDone?.call();
    _showToast(context, '⚡ Buying $label \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)}…');

    try {
      await walletService.buyPosition(
        isYes: isYes,
        usdcAmount: amount,
        question: market.question,
        entryPrice: isYes ? market.yesPrice : market.noPrice,
      );
      if (context.mounted) {
        _showToast(
          context,
          '✅ $label bought · \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} USDC',
          isSuccess: true,
        );
        walletService.refreshBalance();
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().contains('Insufficient')
            ? '❌ Insufficient USDC'
            : '❌ Trade failed';
        _showToast(context, msg, isError: true);
      }
    }
  }

  void _showToast(BuildContext context, String message,
      {bool isSuccess = false, bool isError = false}) {
    final t = context.puls;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _TopToast(
          message: message, isSuccess: isSuccess, isError: isError, t: t),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2500), entry.remove);
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puls Feed',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Swipe to choose your side',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                      )),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: PulsColors.amberLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'DEMO',
              style: TextStyle(
                color: PulsColors.amber,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.t,
    this.isSuccess = false,
    this.isError = false,
  });
  final String message;
  final PulsThemeColors t;
  final bool isSuccess;
  final bool isError;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isSuccess
        ? PulsColors.green
        : widget.isError
            ? PulsColors.red
            : widget.t.brand;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(_anim),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Web grid feed ─────────────────────────────────────────────────────────────
class _WebFeedBody extends StatelessWidget {
  const _WebFeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    switch (appState.feedStatus) {
      case FeedStatus.loading:
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(color: t.brand, strokeWidth: 2.5),
            ),
          ),
        );
      case FeedStatus.error:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, color: t.textSubtle, size: 40),
                  const SizedBox(height: 16),
                  Text('Could not load markets',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: appState.refresh,
                    style: FilledButton.styleFrom(backgroundColor: t.brand),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      case FeedStatus.loaded:
        final markets = appState.feedMarkets;
        if (markets.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text('No markets available.',
                  style: TextStyle(color: t.textMuted)),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemCount: markets.length,
            itemBuilder: (context, i) {
              final market = markets[i];
              return _WebMarketCard(
                market: market,
                t: t,
                isWatchlisted: appState.isWatchlisted(market.id),
                onWatchlist: () => appState.toggleWatchlist(market.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MarketDetailScreen(marketId: market.id),
                  ),
                ),
                onBuy: (side) => showTradePreviewSheet(
                  context: context,
                  market: market,
                  side: side,
                ),
              );
            },
          ),
        );
    }
  }
}

class _WebMarketCard extends StatefulWidget {
  const _WebMarketCard({
    required this.market,
    required this.t,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onTap,
    required this.onBuy,
  });

  final Market market;
  final PulsThemeColors t;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onTap;
  final ValueChanged<MarketSide> onBuy;

  @override
  State<_WebMarketCard> createState() => _WebMarketCardState();
}

class _WebMarketCardState extends State<_WebMarketCard> {
  bool _hovered = false;
  List<double> _sparkline = [];
  bool _sparkLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSparkline();
  }

  Future<void> _loadSparkline() async {
    final prices = await PriceHistoryService.fetch(widget.market.clobTokenId);
    if (mounted) setState(() { _sparkline = prices; _sparkLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final market = widget.market;
    final t = widget.t;
    final isDark = context.isDark;
    final yesLabel = '${(market.yesPrice * 100).toStringAsFixed(0)}¢';
    final noLabel = '${(market.noPrice * 100).toStringAsFixed(0)}¢';

    // Sparkline trend color
    final sparkUp = _sparkline.length >= 2
        ? _sparkline.last >= _sparkline.first
        : market.trendIsPositive;
    final sparkColor = sparkUp ? PulsColors.green : PulsColors.red;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovered ? -4.0 : 0.0, 0),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? t.brand.withValues(alpha: 0.4) : t.border,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? t.brand.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                blurRadius: _hovered ? 24 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Full-bleed image ──────────────────────────────────────
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (market.imageUrl.isNotEmpty)
                      networkImage(market.imageUrl, fit: BoxFit.cover)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              t.brand.withValues(alpha: 0.7),
                              t.brand.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.show_chart_rounded,
                              color: Colors.white.withValues(alpha: 0.4), size: 36),
                        ),
                      ),
                    // Bottom gradient
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Category + bookmark
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              market.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w700, letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: widget.onWatchlist,
                            child: Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.bookmark_rounded, size: 14,
                                color: widget.isWatchlisted ? PulsColors.amber
                                    : Colors.white.withValues(alpha: 0.8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Last trade price bottom-left
                    if (market.lastTradePrice > 0)
                      Positioned(
                        bottom: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Last ${(market.lastTradePrice * 100).toStringAsFixed(0)}¢',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // 24h change bottom-right
                    Positioned(
                      bottom: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: market.trendIsPositive
                              ? PulsColors.green.withValues(alpha: 0.85)
                              : PulsColors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${market.trendIsPositive ? '+' : ''}${(market.trend * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Info panel ────────────────────────────────────────────
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question
                      Text(
                        market.question,
                        style: TextStyle(
                          color: t.text, fontSize: 12,
                          fontWeight: FontWeight.w600, height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // ── Sparkline ──────────────────────────────────────
                      SizedBox(
                        height: 44,
                        child: _sparkLoading
                            ? Center(
                                child: SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: t.textSubtle),
                                ),
                              )
                            : _sparkline.length >= 2
                                ? _Sparkline(prices: _sparkline, color: sparkColor)
                                : Center(
                                    child: Text('No chart data',
                                      style: TextStyle(color: t.textSubtle, fontSize: 10)),
                                  ),
                      ),
                      const SizedBox(height: 8),

                      // ── YES probability bar ────────────────────────────
                      _ProbabilityBar(yesPrice: market.yesPrice, t: t),
                      const SizedBox(height: 8),

                      // ── Stats row ──────────────────────────────────────
                      Row(
                        children: [
                          _Stat(label: '24h Vol', value: _fmtVol(market.volume24hr), t: t),
                          _StatDivider(t: t),
                          _Stat(label: 'Liq', value: market.liquidity, t: t),
                          if (market.spread > 0) ...[
                            _StatDivider(t: t),
                            _Stat(
                              label: 'Spread',
                              value: '${(market.spread * 100).toStringAsFixed(0)}¢',
                              t: t,
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),

                      // ── YES / NO buttons ───────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _BuyButton(
                              label: 'YES', price: yesLabel,
                              color: PulsColors.green, bg: PulsColors.greenLight,
                              onTap: () => widget.onBuy(MarketSide.yes),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BuyButton(
                              label: 'NO', price: noLabel,
                              color: PulsColors.red, bg: PulsColors.redLight,
                              onTap: () => widget.onBuy(MarketSide.no),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtVol(double v) {
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

// ── Sparkline using fl_chart ──────────────────────────────────────────────────
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.prices, required this.color});
  final List<double> prices;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = prices.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) < 0.01 ? 0.05 : (maxY - minY) * 0.2;

    return LineChart(
      LineChartData(
        minY: (minY - padding).clamp(0, 1),
        maxY: (maxY + padding).clamp(0, 1),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── YES probability split bar ─────────────────────────────────────────────────
class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({required this.yesPrice, required this.t});
  final double yesPrice;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('YES ${(yesPrice * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: PulsColors.green, fontSize: 10, fontWeight: FontWeight.w700)),
            Text('NO ${((1 - yesPrice) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: PulsColors.red, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: (yesPrice * 100).round(),
                  child: const ColoredBox(color: PulsColors.green),
                ),
                Expanded(
                  flex: ((1 - yesPrice) * 100).round(),
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

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.t});
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.textSubtle, fontSize: 9, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: t.text, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: t.border,
    );
  }
}

class _BuyButton extends StatefulWidget {
  const _BuyButton({
    required this.label,
    required this.price,
    required this.color,
    required this.bg,
    required this.onTap,
  });
  final String label;
  final String price;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  State<_BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<_BuyButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? widget.color : widget.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? Colors.white : widget.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.price,
                style: TextStyle(
                  color: (_hovered ? Colors.white : widget.color)
                      .withValues(alpha: 0.75),
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
