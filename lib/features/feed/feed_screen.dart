import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/market.dart';
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

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

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
    MarketSide side,
  ) async {
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;

    if (ws.userId == null || !ws.hasWallet) {
      _showToast(context, '⚡ Connect wallet first', isError: true);
      return;
    }

    final isYes = side == MarketSide.yes;
    final amount = appState.fastBuyAmount;
    final label = isYes ? 'YES' : 'NO';

    _showToast(context, '⚡ Buying $label \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)}…');

    try {
      await walletService.buyPosition(
        isYes: isYes,
        usdcAmount: amount,
        question: market.question,
        entryPrice: isYes ? market.yesPrice : market.noPrice,
        contractAddress: market.id,
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

  @override
  Widget build(BuildContext context) {
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
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemBuilder: (context, index) {
              final market = markets[index % markets.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PredictionFeedCard(
                  market: market,
                  isWatchlisted: appState.isWatchlisted(market.id),
                  onWatchlist: () => appState.toggleWatchlist(market.id),
                  onDetails: () => _openDetails(context, market),
                  onChoose: (side) {
                    if (appState.fastBuyEnabled) {
                      _fastBuy(context, appState, market, side);
                    } else {
                      showTradePreviewSheet(
                        context: context,
                        market: market,
                        side: side,
                      );
                    }
                  },
                ),
              );
            },
          ),
        );
    }
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

// ── Web Grid Feed ─────────────────────────────────────────────────────────────
class _WebFeedBody extends StatefulWidget {
  const _WebFeedBody({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  @override
  State<_WebFeedBody> createState() => _WebFeedBodyState();
}

class _WebFeedBodyState extends State<_WebFeedBody> {
  String? _selectedCategory;
  late final Timer _activityTimer;
  final List<_BetActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    // Populate initial activities
    _activities.addAll([
      _BetActivity(username: '0x8f2d…e11a', action: 'bought', question: 'Will Donald Trump launch a new token in 2026?', amount: 520, time: 'Just now', isYes: true),
      _BetActivity(username: 'arbitrum_whale', action: 'bought', question: 'Will BTC exceed \$100k in 2026?', amount: 2500, time: '1m ago', isYes: true),
      _BetActivity(username: '0x4c99…88b2', action: 'bought', question: 'Will the Fed cut interest rates in June?', amount: 150, time: '3m ago', isYes: false),
      _BetActivity(username: 'puls_trader_9', action: 'bought', question: 'Will OpenAI announce GPT-5 before July?', amount: 800, time: '5m ago', isYes: true),
      _BetActivity(username: 'degen_king', action: 'bought', question: 'Will Champions League final go to penalties?', amount: 4300, time: '8m ago', isYes: false),
    ]);

    // Timer to add new bet activities
    _activityTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      final markets = widget.appState.feedMarkets;
      if (markets.isEmpty) return;

      final random = Random();
      final market = markets[random.nextInt(markets.length)];
      final usernames = ['solana_maxi', '0x12a9…cd45', 'crypto_ninja', 'betting_dave', 'pulse_master', '0x7e51…33b9', 'whale_watcher', 'trade_lord'];
      final user = usernames[random.nextInt(usernames.length)];
      final isYes = random.nextBool();
      final amount = (random.nextInt(90) + 10) * 50.0; // multiples of 50 between 500 and 5000

      setState(() {
        _activities.insert(0, _BetActivity(
          username: user,
          action: 'bought',
          question: market.question,
          amount: amount,
          time: 'Just now',
          isYes: isYes,
        ));
        if (_activities.length > 20) {
          _activities.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _activityTimer.cancel();
    super.dispose();
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
    MarketSide side,
  ) async {
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;

    if (ws.userId == null || !ws.hasWallet) {
      _showToast(context, '⚡ Connect wallet first', isError: true);
      return;
    }

    final isYes = side == MarketSide.yes;
    final amount = appState.fastBuyAmount;
    final label = isYes ? 'YES' : 'NO';

    _showToast(context, '⚡ Buying $label \$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)}…');

    try {
      await walletService.buyPosition(
        isYes: isYes,
        usdcAmount: amount,
        question: market.question,
        entryPrice: isYes ? market.yesPrice : market.noPrice,
        contractAddress: market.id,
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

  Widget _buildCategoryRow(String label, String? category, int count) {
    final t = widget.t;
    final selected = _selectedCategory == category;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? t.brandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? t.brand : t.text,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? t.brand.withValues(alpha: 0.2) : t.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected ? t.brand : t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final appState = widget.appState;
    final allMarkets = appState.feedMarkets;

    // Filter markets by category
    final filteredMarkets = _selectedCategory == null
        ? allMarkets
        : allMarkets.where((m) => m.category == _selectedCategory).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Category Panel
        SizedBox(
          width: 250,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Card(
              color: t.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CATEGORIES',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          _buildCategoryRow('All Markets', null, allMarkets.length),
                          const Divider(height: 16),
                          ...appState.categories.map((cat) {
                            final count = allMarkets.where((m) => m.category == cat).length;
                            return _buildCategoryRow(cat, cat, count);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Center Column: Endless scroll feed
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: filteredMarkets.isEmpty
                ? Center(
                    child: Text(
                      'No predictions in this category.',
                      style: TextStyle(color: t.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: 1000, // Large number to act as infinite
                    itemBuilder: (context, index) {
                      final market = filteredMarkets[index % filteredMarkets.length];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: PredictionFeedCard(
                              market: market,
                              isWatchlisted: appState.isWatchlisted(market.id),
                              onWatchlist: () => appState.toggleWatchlist(market.id),
                              onDetails: () => _openDetails(context, market),
                              onChoose: (side) {
                                if (appState.fastBuyEnabled) {
                                  _fastBuy(context, appState, market, side);
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
                      );
                    },
                  ),
          ),
        ),

        // Right Column: Recent Betting Activity
        SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 20),
            child: Card(
              color: t.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: PulsColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE BETTING FEED',
                          style: TextStyle(
                            color: t.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _activities.length,
                        separatorBuilder: (_, __) => Divider(color: t.border, height: 16),
                        itemBuilder: (context, i) {
                          final act = _activities[i];
                          final sideColor = act.isYes ? PulsColors.green : PulsColors.red;
                          final sideText = act.isYes ? 'YES' : 'NO';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    act.username,
                                    style: TextStyle(
                                      color: t.brand,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    act.action,
                                    style: TextStyle(
                                      color: t.textSubtle,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    act.time,
                                    style: TextStyle(
                                      color: t.textSubtle,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                act.question,
                                style: TextStyle(
                                  color: t.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sideColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sideText,
                                      style: TextStyle(
                                        color: sideColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '\$${act.amount.toStringAsFixed(0)} USDC',
                                    style: TextStyle(
                                      color: t.text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BetActivity {
  _BetActivity({
    required this.username,
    required this.action,
    required this.question,
    required this.amount,
    required this.time,
    required this.isYes,
  });
  final String username;
  final String action;
  final String question;
  final double amount;
  final String time;
  final bool isYes;
}
