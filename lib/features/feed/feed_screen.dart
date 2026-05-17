import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import 'prediction_feed_card.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;

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
