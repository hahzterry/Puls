import 'package:puls/core/config.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/tactile.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/puls_app.dart';
import '../../core/motion.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../shell/web_layout.dart';
import '../../data/models/market.dart';
import '../market/trade_preview_sheet.dart';
import '../shell/shell_nav.dart';
import '../onboarding/help_button.dart';
import 'share_bet_card_dialog.dart';
import 'liquid_wealth_terrain.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/state_views.dart';
import '../../core/utils/formatters.dart';

import '../../core/config.dart' show backendUrl;

const _backendUrl = backendUrl;

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _limitOrders = [];
  bool _showOrdersTab = false;
  String _totalSpent = '0.00';
  bool _loading = true;
  String? _error;
  String? _lastUserId;
  bool _initialized = false;
  bool _newestFirst = true;
  bool _claimingAll = false;
  final http.Client _client = http.Client();

  /// Positions that are resolved, won, and not yet claimed.
  int get _claimableCount => _positions.where((p) {
        final resolved = p['resolved'] as bool? ?? false;
        final claimed = p['claimed'] as bool? ?? false;
        final outcome = p['outcome'] as bool? ?? false;
        final isYes = p['side'] == 'YES';
        return resolved && !claimed && (outcome == isYes);
      }).length;

  Future<void> _claimAll() async {
    if (_claimingAll) return;
    setState(() => _claimingAll = true);
    final wallet = WalletServiceScope.of(context);
    final snack = PulsSnack.of(context);
    try {
      final res = await wallet.claimAllWinnings();
      final n = (res['claimed'] as num?)?.toInt() ?? 0;
      snack.success(n > 0
          ? 'Claiming $n winning position${n == 1 ? '' : 's'} — balance updates shortly.'
          : 'No claimable winnings right now.');
      _load(silent: true);
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) _load(silent: true);
      });
    } catch (e) {
      snack.error(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _claimingAll = false);
    }
  }

  Widget _claimAllBar(PulsThemeColors t) {
    final n = _claimableCount;
    if (n < 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _claimingAll ? null : _claimAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: t.yesBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.yes.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(Icons.redeem_rounded, color: t.yes, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'You have $n winning position${n == 1 ? '' : 's'} to claim 🎉',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: t.yes, borderRadius: BorderRadius.circular(10)),
              child: _claimingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Claim all',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reactive: re-fires when wallet state changes. Only (re)subscribe + reload
    // when the signed-in user actually changes (e.g. sign-in after first build).
    final wallet = WalletServiceScope.of(context);
    final userId = wallet.state.userId;
    if (!_initialized || userId != _lastUserId) {
      _initialized = true;
      _lastUserId = userId;
      _load();
    }
    // Instant reload whenever any trade is placed (user or agent), no realtime lag.
    if (_signal != wallet.tradeSignal) {
      _signal?.removeListener(_onTradeSignal);
      _signal = wallet.tradeSignal;
      _signal!.addListener(_onTradeSignal);
    }
  }

  ValueNotifier<int>? _signal;
  void _onTradeSignal() {
    _pendingPollTries = 0; // fresh trade -> restart the pending poll budget
    _load(silent: true);
  }

  void _applySort() {
    _positions.sort((a, b) {
      final ta =
          DateTime.tryParse(a['timestamp'] as String? ?? '') ?? DateTime(1970);
      final tb =
          DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime(1970);
      return _newestFirst ? tb.compareTo(ta) : ta.compareTo(tb);
    });
  }

  Widget _sortToggle(PulsThemeColors t) {
    return Tactile(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _newestFirst = !_newestFirst;
        _applySort();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                _newestFirst
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 12,
                color: t.textMuted),
            const SizedBox(width: 4),
            Text(_newestFirst ? 'Newest' : 'Oldest',
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Timer? _pendingPoll;
  int _pendingPollTries = 0;
  static const _terminalStates = {'COMPLETE', 'FAILED', 'CANCELLED', 'DENIED'};

  /// While any position is still pending on-chain, silently re-fetch every few
  /// seconds so it flips to confirmed without the user reloading the page.
  void _schedulePendingPoll() {
    final hasPending = _positions.any((p) =>
        !_terminalStates.contains((p['state'] as String? ?? '').toUpperCase()));
    if (!hasPending || _pendingPollTries >= 20) {
      _pendingPoll?.cancel();
      _pendingPoll = null;
      _pendingPollTries = 0;
      return;
    }
    _pendingPoll?.cancel();
    _pendingPoll = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _pendingPollTries++;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pendingPoll?.cancel();
    _signal?.removeListener(_onTradeSignal);
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final wallet = WalletServiceScope.of(context);
    final ws = wallet.state;
    if (ws.userId == null) {
      setState(() {
        _positions = [];
        _limitOrders = [];
        _totalSpent = '0.00';
        _loading = false;
      });
      return;
    }
    // Silent reloads (trade just placed / realtime event / pending poll) keep the
    // current list on screen instead of flashing a spinner.
    if (!silent || _positions.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final headers = <String, String>{};
      final token = await wallet.freshAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      final res = await _client.get(
        Uri.parse('$_backendUrl/api/portfolio?userId=${ws.userId}'),
        headers: headers,
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw Exception(data['error']);
      final positions =
          (data['positions'] as List).cast<Map<String, dynamic>>();

      List<Map<String, dynamic>> limitOrders = [];
      try {
        final ordersData = await wallet.getLimitOrders();
        limitOrders = ordersData.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('Failed to load limit orders: $e');
      }

      if (!mounted) return;
      setState(() {
        _positions = positions;
        _limitOrders = limitOrders;
        _totalSpent = data['totalSpent'] as String? ?? '0.00';
        _loading = false;
      });
      _applySort();
      _schedulePendingPoll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cancelLimitOrder(String orderId) async {
    final wallet = WalletServiceScope.of(context);
    final snack = PulsSnack.of(context);
    setState(() {
      _loading = true;
    });
    try {
      await wallet.cancelLimitOrder(orderId);
      snack.success('Limit order cancelled successfully.');
      await _load();
    } catch (e) {
      snack.error(
          'Couldn\'t cancel order: ${e.toString().replaceAll('Exception: ', '')}');
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _tabToggle(PulsThemeColors t) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Positions (${_positions.length})',
              active: !_showOrdersTab,
              onTap: () => setState(() => _showOrdersTab = false),
              t: t,
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Limit Orders (${_limitOrders.length})',
              active: _showOrdersTab,
              onTap: () => setState(() => _showOrdersTab = true),
              t: t,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tradeMarketsBtn(PulsThemeColors t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Tactile(
        onTap: () => ShellNavScope.maybeOf(context)?.goToTab(PulsTab.feed),
        pressedScale: 0.98,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.brandSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.brand.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_rounded, color: t.brand, size: 18),
              const SizedBox(width: 8),
              Text('Trade Prediction Markets',
                  style: TextStyle(
                      color: t.brand,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  double? _calcPnl(
    Map<String, dynamic> position,
    Map<String, Market> marketsByQuestion,
  ) {
    final cost = (position['usdcAmount'] as num?)?.toDouble() ?? 0;
    final entryPrice = (position['entryPrice'] as num?)?.toDouble() ?? 0;
    final isYes = position['side'] == 'YES';
    final question = position['question'] as String? ?? '';

    final key = question.toLowerCase().split(' ').take(5).join(' ');
    final market = marketsByQuestion[key];
    final currentPrice = market == null
        ? null
        : isYes
            ? market.yesPrice
            : market.noPrice;

    if (currentPrice == null) return null;
    final shares = (position['shares'] as num?)?.toDouble() ??
        (entryPrice > 0 ? cost / entryPrice : 0);
    final currentValue = shares * currentPrice;
    return currentValue - cost;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final walletService = WalletServiceScope.of(context);
    final ws = walletService.state;
    final appState = PulsStateScope.of(context);
    final marketsByQuestion = <String, Market>{
      for (final market in appState.markets)
        market.question.toLowerCase().split(' ').take(5).join(' '): market,
    };

    double totalPnl = 0;
    double openValue = 0;
    int wins = 0, losses = 0;
    for (final p in _positions) {
      if (p['state'] != 'COMPLETE') continue;
      final pnl = _calcPnl(p, marketsByQuestion);
      if (pnl != null) {
        totalPnl += pnl;
        openValue += ((p['usdcAmount'] as num?)?.toDouble() ?? 0) + pnl;
        if (pnl >= 0) {
          wins++;
        } else {
          losses++;
        }
      }
    }

    final double invested = double.tryParse(_totalSpent) ?? 0.0;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = kIsWeb && width >= 900;

    Widget body;
    if (ws.userId == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: PulsEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Sign in to see your portfolio',
          message:
              'One tap — a Circle MPC wallet on Arc Network is created for you automatically.',
          actionLabel: 'Connect with Google',
          actionIcon: Icons.login_rounded,
          onAction: () => WalletServiceScope.of(context).signInWithGoogle(),
        ),
      );
    } else if (_loading) {
      body = const PortfolioSkeleton();
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: PulsErrorState(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load portfolio',
          message: _error!,
          retryLabel: 'Retry',
          onRetry: _load,
        ),
      );
    } else {
      // One scroll view for every breakpoint. The old desktop branch nested a
      // second SingleChildScrollView beside a CustomScrollView, which gave the
      // page two competing scrollbars and squeezed the hero into a 4/9 column.
      final pad = isDesktop ? 24.0 : 20.0;
      body = CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, isDesktop ? 12 : 18, pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PortfolioHero(
                      invested: invested,
                      openValue: openValue,
                      totalPnl: totalPnl,
                      winRate: (wins + losses) > 0
                          ? '${((wins / (wins + losses)) * 100).toStringAsFixed(0)}%'
                          : '—',
                      wins: wins,
                      losses: losses,
                      tradeCount: _positions.length,
                      openCount: _positions
                          .where((p) => !(p['resolved'] as bool? ?? false))
                          .length,
                      t: t,
                      walletAddress: ws.walletAddress,
                      usdcBalance: ws.usdcBalance,
                      desktop: isDesktop,
                    ),
                    const SizedBox(height: 20),
                    if (_positions.isNotEmpty || _limitOrders.isNotEmpty)
                      _tradeMarketsBtn(t),
                    Row(
                      children: [
                        Expanded(child: _tabToggle(t)),
                        if (!_showOrdersTab && _positions.length > 1) ...[
                          const SizedBox(width: 10),
                          _sortToggle(t),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!_showOrdersTab) _claimAllBar(t),
                  ],
                ),
              ),
            ),
            if (_showOrdersTab)
              if (_limitOrders.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    child: const PulsEmptyState(
                      icon: Icons.history_rounded,
                      title: 'No pending orders',
                      message:
                          'Place a limit order on any prediction to see it here.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
                  sliver: SliverList.builder(
                    itemCount: _limitOrders.length,
                    itemBuilder: (context, i) {
                      final item = Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LimitOrderCard(
                          order: _limitOrders[i],
                          t: t,
                          appState: appState,
                          onCancel: () => _cancelLimitOrder(
                            _limitOrders[i]['id'] as String,
                          ),
                        ),
                      );
                      if (context.reduceMotion) return item;
                      return item
                          .animate(delay: (i * 30).ms)
                          .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                          .slideY(
                              begin: 0.05,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic);
                    },
                  ),
                )
            else if (_positions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: PulsEmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: 'No positions yet — swipe on a market to start.',
                    message: 'Buy YES or NO on any prediction to get started.',
                    actionLabel: 'Browse markets',
                    actionIcon: Icons.explore_rounded,
                    onAction: () =>
                        ShellNavScope.maybeOf(context)?.goToTab(PulsTab.feed),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
                sliver: SliverList.builder(
                  itemCount: _positions.length,
                  itemBuilder: (context, i) {
                    final item = Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PositionCard(
                        position: _positions[i],
                        t: t,
                        appState: appState,
                        walletService: walletService,
                        onRefresh: _load,
                      ),
                    );
                    if (context.reduceMotion) return item;
                    return item
                        .animate(delay: (i * 30).ms)
                        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                        .slideY(
                            begin: 0.05,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic);
                  },
                ),
              ),
          ],
        );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const AnimatedGradientText('Portfolio',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: const [HelpAction(tab: PulsTab.portfolio)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: _load,
          child: isDesktop ? WebLayout(maxWidth: 1200, child: body) : body,
        ),
      ),
    );
  }
}

/// Portfolio hero — one card, brand colours only.
///
/// Left/top: the money (capital deployed, live P&L, wallet). Right/bottom: the
/// terrain visual. The old version nested the terrain and a metrics box inside
/// a pink gradient tray and pushed the three stat boxes outside the hero, so
/// the page read as four unrelated blocks. Now the numbers live in the hero
/// with the stats as its footer rail.
class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({
    required this.invested,
    required this.openValue,
    required this.totalPnl,
    required this.winRate,
    required this.wins,
    required this.losses,
    required this.tradeCount,
    required this.openCount,
    required this.t,
    required this.walletAddress,
    required this.usdcBalance,
    required this.desktop,
  });

  final double invested;
  final double openValue;
  final double totalPnl;
  final String winRate;
  final int wins;
  final int losses;
  final int tradeCount;
  final int openCount;
  final PulsThemeColors t;
  final String? walletAddress;
  final String usdcBalance;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final shortAddress = walletAddress != null && walletAddress!.length > 12
        ? '${walletAddress!.substring(0, 6)}…${walletAddress!.substring(walletAddress!.length - 4)}'
        : '—';
    final up = totalPnl >= 0;
    final pnlColor = up ? t.yes : t.no;

    final money = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('CAPITAL DEPLOYED',
            style: TextStyle(
                color: t.textSubtle,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4)),
        const SizedBox(height: 8),
        CountUpText(
          invested,
          duration: context.motionDuration(const Duration(milliseconds: 700)),
          builder: (context, value) => Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: t.text,
              fontSize: desktop ? 44 : 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.6,
              height: 1.0,
              fontFeatures: PulsColors.tabularFigures,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // P&L pill — the one number that should be readable from across the
        // room, in the semantic YES/NO colours (both drawn from the logo).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: up ? t.yesBg : t.noBg,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: pnlColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 14, color: pnlColor),
              const SizedBox(width: 6),
              Text(
                '${up ? '+' : '−'}\$${totalPnl.abs().toStringAsFixed(2)}',
                style: TextStyle(
                    color: pnlColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: PulsColors.tabularFigures),
              ),
              const SizedBox(width: 6),
              Text('P&L',
                  style: TextStyle(
                      color: pnlColor.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _HeroMetric(label: 'USDC BALANCE', value: '\$$usdcBalance', t: t),
        Divider(height: 17, color: t.border),
        _HeroMetric(label: 'OPEN VALUE', value: '\$${openValue.toStringAsFixed(2)}', t: t),
        const SizedBox(height: 16),
        Semantics(
          button: walletAddress != null,
          label: 'Copy wallet address',
          child: InkWell(
            onTap: walletAddress == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: walletAddress!));
                    PulsSnack.show(context, 'Address copied to clipboard',
                        duration: const Duration(seconds: 2));
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.brandSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.brand.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: t.brand, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(shortAddress,
                        style: TextStyle(
                            color: t.text,
                            fontFamily: PulsColors.fontMono,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.copy_rounded, color: t.brand, size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final terrain = LiquidWealthTerrain(
      pnlUsdc: totalPnl,
      pnlRange: invested > 0 ? invested : 100,
      height: desktop ? 300 : 240,
      title: 'PORTFOLIO TERRAIN · P&L',
      positiveColor: t.yes,
      negativeColor: t.no,
      borderRadius: 20,
    );

    // The third box used to repeat Invested, which is the headline number two
    // rows up — the same figure twice in one card. Average size is derived from
    // it and is the thing that number doesn't already say.
    final settled = wins + losses;
    final avg = tradeCount > 0 ? invested / tradeCount : 0.0;
    final stats = Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Win Rate',
            value: winRate,
            sub: settled > 0 ? '${wins}W · ${losses}L' : 'no settled trades',
            icon: Icons.emoji_events_rounded,
            accent: settled == 0
                ? null
                : wins >= losses
                    ? t.yes
                    : t.no,
            t: t,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'Positions',
            value: '$tradeCount',
            sub: openCount > 0 ? '$openCount open' : 'all settled',
            icon: Icons.layers_rounded,
            accent: t.brand,
            t: t,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'Avg Size',
            value: '\$${avg.toStringAsFixed(avg >= 100 ? 0 : 2)}',
            sub: 'per position',
            icon: Icons.straighten_rounded,
            accent: PulsColors.amber,
            t: t,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: pulsCardDecoration(
        t,
        radius: 24,
        isDark: context.isDark,
        raised: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: money),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: terrain),
                ],
              ),
            )
          else ...[
            money,
            const SizedBox(height: 16),
            terrain,
          ],
          const SizedBox(height: 18),
          stats,
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(
      {required this.label, required this.value, required this.t});
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: t.textSubtle,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFeatures: PulsColors.tabularFigures)),
        ),
      ],
    );
  }
}

class _PositionCard extends StatefulWidget {
  const _PositionCard({
    required this.position,
    required this.t,
    required this.appState,
    required this.walletService,
    this.onRefresh,
  });
  final Map<String, dynamic> position;
  final PulsThemeColors t;
  final dynamic appState;
  final dynamic walletService;
  final VoidCallback? onRefresh;

  @override
  State<_PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends State<_PositionCard> {
  bool _claiming = false;

  Future<void> _claim() async {
    final snack = PulsSnack.of(context);
    setState(() => _claiming = true);
    final slug = widget.position['slug'] as String? ?? '';
    final String? contractAddress =
        (widget.position['contractAddress'] as String?) ??
            (widget.position['marketId'] as String?);

    try {
      if (contractAddress == null || contractAddress.isEmpty) {
        throw Exception('Market contract address not available');
      }
      await widget.walletService
          .claimWinnings(contractAddress: contractAddress, slug: slug);
      if (mounted) {
        snack.success('Claim submitted! Check balance in a few seconds.');
        widget.onRefresh?.call();
        // Delay to allow transaction to mine on-chain before refreshing again
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) widget.onRefresh?.call();
        });
      }
    } catch (e) {
      if (mounted) {
        snack.error(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final t = widget.t;
    final isYes = position['side'] == 'YES';
    final sideBg = isYes ? t.yesBg : t.noBg;
    final sideFg = isYes ? t.yes : t.no;
    final state = position['state'] as String? ?? 'UNKNOWN';
    final amount = (position['usdcAmount'] as num?)?.toDouble() ?? 0.0;
    final entryPrice = (position['entryPrice'] as num?)?.toDouble() ?? 0.0;
    final question = position['question'] as String? ?? 'Prediction';
    final txHash = position['txHash'] as String?;
    final timestamp = position['timestamp'] as String?;

    final resolved = position['resolved'] as bool? ?? false;
    final outcome = position['outcome'] as bool? ?? false;
    final claimed = position['claimed'] as bool? ?? false;
    final userWon = resolved && (outcome == isYes);

    double? pnl;
    double? currentPrice;
    final hasRealEntryPrice = entryPrice > 0 && entryPrice != 0.5;
    Market? matchedMarket;

    if (state == 'COMPLETE') {
      try {
        matchedMarket = (widget.appState.markets as List).firstWhere(
          (m) => (m.question as String).toLowerCase().contains(
                question.toLowerCase().split(' ').take(5).join(' '),
              ),
        ) as Market;
        currentPrice = isYes ? matchedMarket.yesPrice : matchedMarket.noPrice;
        final shares = (position['shares'] as num?)?.toDouble() ??
            (amount > 0
                ? (amount / (hasRealEntryPrice ? entryPrice : 0.5))
                : 0.0);
        pnl = (shares * currentPrice) - amount;
      } catch (_) {}
    }

    matchedMarket ??= Market(
      id: (position['marketId'] as String? ??
              position['contractAddress'] as String?) ??
          '',
      slug: position['slug'] as String? ?? 'default-slug',
      contractAddress: position['contractAddress'] as String? ??
          position['marketId'] as String?,
      question: question,
      category: 'Crypto',
      context: '',
      yesPrice: 0.5,
      noPrice: 0.5,
      volume: '\$20',
      liquidity: '\$20',
      deadline: DateTime.now().add(const Duration(days: 30)),
      trend: 0.0,
      isFeatured: false,
      tags: const [],
      history: const [],
      comments: const [],
      news: const [],
    );

    final positionContract = (position['contractAddress'] as String?) ??
        (position['marketId'] as String?);
    final hasValidContract = positionContract != null &&
        positionContract.startsWith('0x') &&
        positionContract.length == 42;

    Color stateColor;
    String stateLabel;
    switch (state) {
      case 'COMPLETE':
        stateColor = t.yes;
        stateLabel = 'Confirmed';
        break;
      case 'FAILED':
      case 'DENIED':
        stateColor = t.no;
        stateLabel = 'Failed';
        break;
      default:
        stateColor = PulsColors.amber;
        stateLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: pulsCardDecoration(
        t,
        radius: 18,
        isDark: context.isDark,
        // A won-but-unclaimed position is the only card that earns an accent.
        accent: userWon && !claimed ? t.yes : null,
        raised: userWon && !claimed,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: sideBg, borderRadius: BorderRadius.circular(6)),
                child: Text(isYes ? 'YES' : 'NO',
                    style: TextStyle(
                        color: sideFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(stateLabel,
                    style: TextStyle(
                        color: stateColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
              ),
              if (resolved) ...[
                const SizedBox(width: 8),
                if (claimed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: t.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('Claimed',
                        style: TextStyle(
                            color: t.brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  )
                else if (userWon)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: t.yes.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('Won',
                        style: TextStyle(
                            color: t.yes,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: t.no.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('Lost',
                        style: TextStyle(
                            color: t.no,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                  ),
              ],
              const Spacer(),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('\$${amount.toStringAsFixed(2)} USDC',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: t.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                fontFeatures: PulsColors.tabularFigures)),
                        if (state == 'COMPLETE') ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                ShareBetCardDialog.show(context, position, pnl),
                            child: Icon(Icons.share_rounded,
                                size: 14, color: t.brand),
                          ),
                        ],
                      ],
                    ),
                    if (pnl != null && pnl.abs() >= 0.01)
                      Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: pnl >= 0 ? t.yes : t.no,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              fontFeatures: PulsColors.tabularFigures)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(question,
              style: TextStyle(
                  color: t.text, fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (entryPrice > 0 && entryPrice != 0.5) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Entry ${formatCents(entryPrice)}',
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
                if (currentPrice != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      size: 10, color: t.textSubtle),
                  const SizedBox(width: 6),
                  Text('Now ${formatCents(currentPrice)}',
                      style: TextStyle(
                        color: (currentPrice - entryPrice).abs() < 0.01
                            ? t.textSubtle
                            : currentPrice >= entryPrice
                                ? t.yes
                                : t.no,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ],
            ),
          ],
          if (txHash != null || timestamp != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (timestamp != null)
                  Text(formatShortDateTime(timestamp),
                      style: TextStyle(color: t.textSubtle, fontSize: 11)),
                const Spacer(),
                if (txHash != null)
                  GestureDetector(
                    onTap: () => launchUrl(
                        Uri.parse('https://testnet.arcscan.app/tx/$txHash'),
                        mode: LaunchMode.externalApplication),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            '${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}',
                            style: TextStyle(
                                color: t.brand,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 3),
                        Icon(Icons.open_in_new_rounded,
                            size: 11, color: t.brand),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (state == 'COMPLETE') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: hasValidContract && !resolved
                          ? () {
                              showTradePreviewSheet(
                                context: context,
                                market: matchedMarket!.copyWith(
                                  contractAddress: positionContract,
                                  slug: position['slug'] as String?,
                                ),
                                side: isYes ? MarketSide.yes : MarketSide.no,
                                initialIsBuy: false,
                                owner: (position['owner'] as String?) ?? 'user',
                                maxShares:
                                    (position['shares'] as num?)?.toDouble() ??
                                        (amount > 0
                                            ? (amount /
                                                (hasRealEntryPrice
                                                    ? entryPrice
                                                    : 0.5))
                                            : 0.0),
                              ).then((_) => widget.onRefresh?.call());
                            }
                          : null,
                      icon: const Icon(Icons.sell_rounded, size: 14),
                      label: Text(
                          resolved ? 'Market Resolved' : 'Sell Position',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.brand,
                        side: BorderSide(
                            color: (hasValidContract && !resolved)
                                ? t.brand
                                : t.border,
                            width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: _claiming
                        ? const Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                        : OutlinedButton.icon(
                            onPressed: (hasValidContract &&
                                    resolved &&
                                    userWon &&
                                    !claimed)
                                ? _claim
                                : null,
                            icon: const Icon(Icons.redeem_rounded, size: 14),
                            label: Text(
                              !resolved
                                  ? 'Market Active'
                                  : claimed
                                      ? 'Winnings Claimed'
                                      : userWon
                                          ? 'Claim Winnings'
                                          : 'Position Lost',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: t.yes,
                              side: BorderSide(
                                  color: (hasValidContract &&
                                          resolved &&
                                          userWon &&
                                          !claimed)
                                      ? t.yes
                                      : t.border,
                                  width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One stat in the hero footer rail.
///
/// Each box carries its own [accent] — an icon chip and a hairline down the
/// leading edge — so the three read as distinct meters instead of three
/// identical grey tiles. [accent] null means "nothing to colour yet" (no
/// settled trades), which stays neutral rather than guessing a good/bad hue.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.t,
    this.sub,
    this.icon,
    this.accent,
  });
  final String label;
  final String value;
  final PulsThemeColors t;
  final String? sub;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final a = accent;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: a == null ? t.border : a.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colour rail: enough to tell the boxes apart at a glance, not
          // enough to compete with the numbers they sit beside.
          Container(width: 3, color: a ?? t.border),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 11, color: a ?? t.textSubtle),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.textSubtle,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        color: t.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.0,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.t,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Tactile(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.motionDuration(const Duration(milliseconds: 200)),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? t.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: t.brand.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : t.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LimitOrderCard extends StatelessWidget {
  const _LimitOrderCard({
    required this.order,
    required this.t,
    required this.appState,
    required this.onCancel,
  });
  final Map<String, dynamic> order;
  final PulsThemeColors t;
  final dynamic appState;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final side = order['side'] as String? ?? 'YES';
    final type = order['type'] as String? ?? 'BUY';
    final isYes = side == 'YES';
    final isBuy = type == 'BUY';

    final sideBg = isYes ? t.yesBg : t.noBg;
    final sideFg = isYes ? t.yes : t.no;

    final status = order['status'] as String? ?? 'PENDING';
    final targetPrice =
        double.tryParse(order['target_price']?.toString() ?? '0') ?? 0.0;
    final usdcAmount =
        double.tryParse(order['usdc_amount']?.toString() ?? '0') ?? 0.0;
    final shares = double.tryParse(order['shares']?.toString() ?? '0') ?? 0.0;
    final txHash = order['tx_hash'] as String?;
    final createdAt = order['created_at'] as String?;

    // Match market to get question
    Market? market;
    try {
      market = (appState.markets as List).firstWhere((m) =>
          m.slug == order['slug'] ||
          m.id == order['marketId'] ||
          m.contractAddress == order['marketId']) as Market;
    } catch (_) {}

    final question = market?.question ?? order['slug'] ?? 'Prediction Market';

    Color statusColor;
    switch (status) {
      case 'PENDING':
        statusColor = PulsColors.amber;
        break;
      case 'EXECUTED':
        statusColor = t.yes;
        break;
      case 'CANCELLED':
        statusColor = t.textSubtle;
        break;
      default:
        statusColor = t.no;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: pulsCardDecoration(
        t,
        radius: 18,
        isDark: context.isDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: sideBg, borderRadius: BorderRadius.circular(6)),
                child: Text('$type $side',
                    style: TextStyle(
                        color: sideFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isBuy)
                    Text('\$${usdcAmount.toStringAsFixed(2)} USDC',
                        style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14))
                  else
                    Text('${shares.toStringAsFixed(0)} shares',
                        style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  Text('Limit: ${formatCents(targetPrice)}',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(question,
              style: TextStyle(
                  color: t.text, fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              if (createdAt != null)
                Text(formatShortDateTime(createdAt),
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
              const Spacer(),
              if (status == 'PENDING')
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: Icon(Icons.cancel_outlined, size: 12, color: t.no),
                    label: Text('Cancel',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: t.no)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                )
              else if (txHash != null)
                GestureDetector(
                  onTap: () => launchUrl(
                      Uri.parse('https://testnet.arcscan.app/tx/$txHash'),
                      mode: LaunchMode.externalApplication),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}',
                          style: TextStyle(
                              color: t.brand,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 3),
                      Icon(Icons.open_in_new_rounded, size: 11, color: t.brand),
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
