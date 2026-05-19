import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock/mock_videos.dart';
import '../../data/models/market.dart';
import '../../core/utils/trade_math.dart';
import '../home/web_video_player.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import 'prediction_feed_card.dart';
import 'ticker_strip.dart';

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
        body: Column(
          children: [
            _FeedHeader(t: t),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: WebTickerStrip(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _WebFeedBody(appState: appState, t: t),
            ),
          ],
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
class _WebFeedBody extends StatefulWidget {
  const _WebFeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  @override
  State<_WebFeedBody> createState() => _WebFeedBodyState();
}

class _WebFeedBodyState extends State<_WebFeedBody> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final appState = widget.appState;
    if (mockVideos.isEmpty) {
      return Center(
        child: Text('No videos available',
            style: TextStyle(color: t.textMuted, fontSize: 14)),
      );
    }

    final video = mockVideos[_currentIndex];

    // Find linked market
    final market = appState.markets.firstWhere(
      (m) => m.id == video.linkedMarketId,
      orElse: () => Market(
        id: video.linkedMarketId,
        question: video.linkedMarketQuestion,
        category: 'Sports',
        context: video.caption,
        yesPrice: video.linkedMarketYesPrice,
        noPrice: (1.0 - video.linkedMarketYesPrice).clamp(0.01, 0.99),
        volume: '\$24.5K',
        liquidity: '\$1.8K',
        deadline: DateTime.now().add(const Duration(days: 30)),
        imageUrl: '',
        clobTokenId: '',
        volume24hr: 1200,
        spread: 0.02,
        bestBid: video.linkedMarketYesPrice - 0.01,
        bestAsk: video.linkedMarketYesPrice,
        isFeatured: false,
        tags: const [],
        history: const [],
        comments: const [],
        news: const [],
        trend: 0.0,
      ),
    );

    final yesPct = (market.yesPrice * 100).round();
    final noPct = 100 - yesPct;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Left Pane: Video Player (TikTok-style)
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: buildWebVideoPlayer(video.videoUrl) ?? const SizedBox(),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          stops: const [0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Video Details Overlay
                  Positioned(
                    left: 20,
                    bottom: 20,
                    right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: t.brandSubtle,
                              child: Text(
                                video.username.isNotEmpty ? video.username.substring(1, 3).toUpperCase() : 'PL',
                                style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              video.username,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          video.caption,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Sidebar controls (Likes, Views, Next/Prev)
                  Positioned(
                    right: 16,
                    bottom: 30,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SidebarActionBtn(
                          icon: Icons.keyboard_arrow_up_rounded,
                          label: 'Prev',
                          onTap: _currentIndex > 0
                              ? () => setState(() => _currentIndex--)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _SidebarActionBtn(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: 'Next',
                          onTap: _currentIndex < mockVideos.length - 1
                              ? () => setState(() => _currentIndex++)
                              : null,
                        ),
                        const SizedBox(height: 24),
                        _SidebarActionBtn(
                          icon: Icons.favorite_rounded,
                          label: _fmt(video.likes),
                          color: PulsColors.red,
                        ),
                        const SizedBox(height: 16),
                        _SidebarActionBtn(
                          icon: Icons.visibility_rounded,
                          label: _fmt(video.views),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1.5, color: t.border),
          // Right Pane: Trading console & Social Comments
          Expanded(
            flex: 6,
            child: Container(
              color: t.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: t.brandSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                market.category.toUpperCase(),
                                style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.bookmark_rounded,
                                color: appState.isWatchlisted(market.id) ? PulsColors.amber : t.textSubtle,
                              ),
                              onPressed: () => appState.toggleWatchlist(market.id),
                            ),
                            IconButton(
                              icon: Icon(Icons.open_in_new_rounded, color: t.textSubtle, size: 20),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MarketDetailScreen(marketId: market.id),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          market.question,
                          style: TextStyle(color: t.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: t.surfaceRaised,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: t.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('YES PROBABILITY', style: TextStyle(color: PulsColors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('$yesPct%', style: const TextStyle(color: PulsColors.green, fontSize: 32, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('NO PROBABILITY', style: TextStyle(color: PulsColors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('$noPct%', style: const TextStyle(color: PulsColors.red, fontSize: 32, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: [
                                  Expanded(flex: yesPct, child: const ColoredBox(color: PulsColors.green)),
                                  Expanded(flex: noPct, child: const ColoredBox(color: PulsColors.red)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => showTradePreviewSheet(context: context, market: market, side: MarketSide.yes),
                                  style: TextButton.styleFrom(
                                    backgroundColor: PulsColors.greenLight,
                                    foregroundColor: PulsColors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text('Buy YES ${TradeMath.formatPrice(market.yesPrice)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextButton(
                                  onPressed: () => showTradePreviewSheet(context: context, market: market, side: MarketSide.no),
                                  style: TextButton.styleFrom(
                                    backgroundColor: PulsColors.redLight,
                                    foregroundColor: PulsColors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text('Buy NO ${TradeMath.formatPrice(market.noPrice)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                          child: Text(
                            'Comments (${video.comments.length})',
                            style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            itemCount: video.comments.length,
                            separatorBuilder: (_, __) => Divider(color: t.border, height: 20),
                            itemBuilder: (context, i) {
                              final comment = video.comments[i];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: t.brandSubtle,
                                        child: Text(
                                          comment.avatar,
                                          style: TextStyle(color: t.brand, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        comment.username,
                                        style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.favorite_outline_rounded, size: 12, color: t.textSubtle),
                                      const SizedBox(width: 3),
                                      Text(_fmt(comment.likes), style: TextStyle(color: t.textSubtle, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 32),
                                    child: Text(
                                      comment.text,
                                      style: TextStyle(color: t.text, fontSize: 13, height: 1.4),
                                    ),
                                  ),
                                  if (comment.reply != null) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundColor: PulsColors.greenLight,
                                            child: Text(
                                              comment.reply!.avatar,
                                              style: const TextStyle(color: PulsColors.green, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment.reply!.username,
                                            style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 64),
                                      child: Text(
                                        comment.reply!.text,
                                        style: TextStyle(color: t.text, fontSize: 12, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarActionBtn extends StatelessWidget {
  const _SidebarActionBtn({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && (label == 'Prev' || label == 'Next');
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, color: color ?? Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}
