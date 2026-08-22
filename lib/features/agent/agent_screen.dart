import 'dart:async';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/puls_sheet.dart';
import '../../core/widgets/tab_visibility.dart';
import '../../core/widgets/tactile.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth_headers.dart';
import '../../core/utils/haptics.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/motion.dart';
import '../../core/utils/puls_emoji.dart';
import '../../core/widgets/puls_emoji_text.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/config.dart' show backendUrl, appUrl;
import '../../core/widgets/shimmer_text.dart';
import '../../core/widgets/puls_page_route.dart';
import '../shell/web_layout.dart';
import '../shell/shell_nav.dart';
import '../onboarding/help_button.dart';
import 'agent_sponsorship_screen.dart';
import 'flash_arbitrage_screen.dart' deferred as flash_arb;
import 'gladiator_arena_screen.dart' deferred as gladiator;
import 'live_swarm_view.dart';
import 'proof_view.dart';
import '../market/signals_marketplace.dart';
import '../streams/streams_screen.dart';
import 'finance_director_card.dart';

class _Msg {
  _Msg(this.fromAgent, this.text,
      {this.txId,
      this.contract,
      this.sources = const [],
      this.trades = const [],
      this.signals = const []});
  final bool fromAgent;
  final String text;
  final String? txId;
  final String? contract;
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> trades;
  final List<Map<String, dynamic>> signals;
}

/// A live, auto-advancing pipeline of the steps the agent is taking right now
/// (research → buy alpha → reason → trade). The active node pulses and earlier
/// nodes check off as it advances — a transparent, on-brand "agent at work".
class _PipelineTracker extends StatefulWidget {
  const _PipelineTracker({required this.steps});
  final List<(IconData, String)> steps;
  @override
  State<_PipelineTracker> createState() => _PipelineTrackerState();
}

class _PipelineTrackerState extends State<_PipelineTracker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  int _active = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    TabVisibility.ensureListening();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || !TabVisibility.visible) return;
      if (_active < widget.steps.length - 1) setState(() => _active++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final reduce = context.reduceMotion;
    final steps = widget.steps;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                _node(t, steps[i].$1, i, reduce),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: i < _active ? t.brand : t.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              if (reduce)
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: t.brand))
              else
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.brand.withValues(alpha: 0.4 + 0.6 * _c.value),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text('${steps[_active].$2}…',
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _node(PulsThemeColors t, IconData icon, int i, bool reduce) {
    final done = i < _active;
    final active = i == _active;
    final node = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? t.brand
            : (active ? t.brand.withValues(alpha: 0.15) : t.surface),
        border: Border.all(
          color: (done || active) ? t.brand : t.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: 15,
        color: done ? Colors.white : (active ? t.brand : t.textSubtle),
      ),
    );
    if (active && !reduce) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1 + 0.07 * _c.value, child: child),
          child: node,
        ),
      );
    }
    return node;
  }
}

/// Lets other tabs deep-link into one of the Agent screen's sub-tabs.
/// Index map: 0 Live Swarm · 1 My Agent · 2 Signals · 3 Proof.
/// Set the value, then switch to PulsTab.agent — the live AgentScreen picks it
/// up and animates to the requested sub-tab.
final ValueNotifier<int> agentSubTabRequest = ValueNotifier<int>(0);

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key, this.initialAgentId});

  /// Optional agent ID for deep-linking via `/agent/<id>`. When set, the
  /// screen can pre-select / focus that specific agent rather than the
  /// current user's own agent. Currently stored but not yet wired into the
  /// chat fetch flow (which uses the user's session); a dedicated per-agent
  /// decision-trace view can read this on mount.
  final String? initialAgentId;

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);
  final _client = http.Client();
  final _input = TextEditingController();
  final _budget = TextEditingController(text: '5');
  final _scroll = ScrollController();

  bool _started = false;
  bool _busy = false;
  String? _agentAddress;
  bool _registered = false;
  int _reputation = 0;
  String? _agentId;
  double _budgetVal = 0, _spent = 0;
  final List<_Msg> _msgs = [];
  String _strategy = 'NONE';
  bool _showTools = false; // strategy + Finance Director collapsed by default

  String? get _userId => WalletServiceScope.of(context).state.userId;

  /// Compact-density breakpoint: below 600px the My Agent tab switches to the
  /// mobile layout (single-row header, sheet-tucked tools & quick buys, slimmer
  /// composer, wider chat bubbles). Desktop keeps the roomy layout.
  bool get _isMobile => MediaQuery.sizeOf(context).width < 600;

  /// Max bubble/card width for chat content. Desktop keeps the fixed 340px
  /// column; mobile uses ~84% of the viewport so messages use the screen.
  double get _bubbleMax {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 340;
    final avail = w.clamp(0.0, 720.0) - 24; // WebLayout gutter + list padding
    return (avail * 0.84).clamp(220.0, 420.0);
  }

  @override
  void initState() {
    super.initState();
    // Honor a deep-link request that was set before this screen mounted.
    if (agentSubTabRequest.value > 0 && agentSubTabRequest.value < 4) {
      _tabController.index = agentSubTabRequest.value;
    }
    agentSubTabRequest.addListener(_onSubTabRequest);
    _tabController.addListener(_onTabChanged);
  }

  void _onSubTabRequest() {
    final i = agentSubTabRequest.value;
    if (mounted && i >= 0 && i < 4) _tabController.animateTo(i);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 1) {
      _resumeIfNeeded();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabController.index == 1) _resumeIfNeeded();
  }

  bool _resumed = false;

  void _resumeIfNeeded() {
    if (_resumed || _userId == null) return;
    _resumed = true;
    _resume();
  }

  // Restore an existing agent on page load so funds + agent aren't "lost" after a reload.
  Future<void> _resume() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final headers = await pulsAuthHeadersWithDirectAuth();
      final res = await _client
          .get(
            Uri.parse('$backendUrl/api/agent/status?userId=$uid'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      final r = jsonDecode(res.body) as Map<String, dynamic>;
      if (r['exists'] == true && mounted) {
        final bal = double.tryParse('${r['balance']}') ?? 0;
        String strategy = 'NONE';
        try {
          final stratRes = await _client
              .get(
                Uri.parse('$backendUrl/api/agent/strategy?userId=$uid'),
                headers: headers,
              )
              .timeout(const Duration(seconds: 5));
          if (stratRes.statusCode == 200) {
            final sr = jsonDecode(stratRes.body) as Map<String, dynamic>;
            strategy = sr['strategy'] as String? ?? 'NONE';
          }
        } catch (e) {
          debugPrint('[Puls] agent strategy fetch failed: $e');
        }
        setState(() {
          _started = true;
          _agentAddress = r['agentAddress'] as String?;
          _registered = r['registered'] == true;
          _reputation = (r['reputation'] as num?)?.toInt() ?? 0;
          _agentId = r['agentId'] as String?;
          _budgetVal = bal;
          _spent = 0;
          _strategy = strategy;
          _msgs.add(_Msg(true,
              'Welcome back. Your agent is live with \$${bal.toStringAsFixed(2)} USDC available. Ask me to trade, or withdraw the funds back to your wallet anytime.'));
        });
      }
    } catch (e) {
      debugPrint('[Puls] agent status load failed: $e');
    }
  }

  @override
  void dispose() {
    agentSubTabRequest.removeListener(_onSubTabRequest);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _client.close();
    _input.dispose();
    _budget.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final headers = await pulsAuthHeadersWithDirectAuth();
    headers['Content-Type'] = 'application/json';
    final res = await _client
        .post(
          Uri.parse('$backendUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 150));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<void> _start() async {
    final uid = _userId;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final r = await _post(
          '/api/agent/start', {'userId': uid, 'budget': _budget.text});
      setState(() {
        _started = true;
        _agentAddress = r['agentAddress'] as String?;
        _registered = r['registered'] == true;
        _reputation = (r['reputation'] as num?)?.toInt() ?? 0;
        _agentId = r['agentId'] as String?;
        _budgetVal = (r['budget'] as num?)?.toDouble() ?? 0;
        _spent = (r['spent'] as num?)?.toDouble() ?? 0;
        _msgs.add(_Msg(true,
            'Agent live on Arc. I have \$${(_budgetVal - _spent).toStringAsFixed(2)} USDC to trade. Tell me what to predict — e.g. "buy 2 USDC YES on the top market".'));
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final uid = _userId;
    final text = _input.text.trim();
    if (uid == null || text.isEmpty || _busy) return;
    setState(() {
      _msgs.add(_Msg(false, text));
      _input.clear();
      _busy = true;
    });
    _scrollDown();
    try {
      final r =
          await _post('/api/agent/chat', {'userId': uid, 'message': text});
      List<Map<String, dynamic>> asList(dynamic v) =>
          (v as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
      final trade = r['trade'] as Map<String, dynamic>?;
      final trades = asList(r['trades']);
      final signals = asList(r['signals']);
      setState(() {
        _msgs.add(_Msg(true, r['reply'] as String? ?? 'Done.',
            txId: trade?['txHash'] as String?,
            contract: trade?['contractAddress'] as String?,
            sources: asList(r['sources']),
            trades: trades,
            signals: signals));
        if (r['remaining'] != null) {
          _spent = _budgetVal - (r['remaining'] as num).toDouble();
        }
        if (r['reputation'] != null) {
          _reputation = (r['reputation'] as num).toInt();
        }
      });
      // Agent bought a signal or placed a trade → refresh balance + portfolio.
      if ((trade != null || trades.isNotEmpty || signals.isNotEmpty) &&
          mounted) {
        WalletServiceScope.of(context).notifyTrade();
      }
    } catch (e) {
      setState(() => _msgs
          .add(_Msg(true, '⚠️ ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  Future<void> _withdraw() async {
    final uid = _userId;
    if (uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await _post('/api/agent/withdraw', {'userId': uid});
      final w = (r['withdrawn'] as num?)?.toDouble() ?? 0;
      setState(() {
        _spent = _budgetVal; // remaining now 0
        _msgs.add(_Msg(
            true,
            w > 0
                ? 'Withdrew \$${w.toStringAsFixed(2)} USDC back to your wallet.'
                : 'Nothing to withdraw.'));
      });
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deposit() async {
    final uid = _userId;
    if (uid == null || _busy) return;
    final ctrl = TextEditingController(text: '5');
    final t = context.puls;
    final amount = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surfaceRaised,
        title: Text('Deposit to Agent',
            style: TextStyle(
                color: t.text, fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: t.text),
          decoration: InputDecoration(
              prefixText: '\$',
              prefixStyle: TextStyle(color: t.text),
              labelText: 'USDC amount',
              labelStyle: TextStyle(color: t.textMuted)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: t.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: Text('Deposit',
                  style:
                      TextStyle(color: t.brand, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (amount == null || amount.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final r =
          await _post('/api/agent/deposit', {'userId': uid, 'amount': amount});
      final d = (r['deposited'] as num?)?.toDouble() ?? 0;
      final bal = (r['balance'] as num?)?.toDouble() ?? _budgetVal;
      setState(() {
        _budgetVal = bal;
        _spent = 0;
        _msgs.add(_Msg(
            true,
            d > 0
                ? 'Deposited \$${d.toStringAsFixed(2)} USDC. I now have \$${bal.toStringAsFixed(2)} to trade.'
                : 'Deposit didn\'t go through. Check your wallet balance and try again.'));
      });
      if (mounted) WalletServiceScope.of(context).notifyTrade();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });

  void _toast(String m) =>
      PulsSnack.show(context, m.replaceAll('Exception: ', ''));

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: t.brand, size: 22),
            const SizedBox(width: 8),
            const AnimatedGradientText('AI Agent',
                style: TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Agent Sponsorship — stake USDC into an agent',
            icon: Icon(Icons.savings_rounded, color: t.brand),
            onPressed: () => Navigator.of(context).push(
              pulsRoute(context,
                  builder: (_) => const AgentSponsorshipScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Gladiator Arena — 24h AI trading tournament',
            icon: Icon(Icons.sports_mma_rounded, color: t.brand),
            onPressed: () async {
              await gladiator.loadLibrary();
              if (!context.mounted) return;
              Navigator.of(context).push(
                pulsRoute(context,
                    builder: (_) => gladiator.GladiatorArenaScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Flash Arbitrage — approve agent-found arbs',
            icon: Icon(Icons.radar_rounded, color: t.brand),
            onPressed: () async {
              await flash_arb.loadLibrary();
              if (!context.mounted) return;
              Navigator.of(context).push(
                pulsRoute(context,
                    builder: (_) => flash_arb.FlashArbitrageScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Puls Streams — pay-per-second',
            icon: Icon(Icons.bolt_rounded, color: t.brand),
            onPressed: () => Navigator.of(context).push(
              pulsRoute(context, builder: (_) => const StreamsScreen()),
            ),
          ),
          const HelpAction(tab: PulsTab.agent),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // One-line framing so anyone landing here — judges included —
            // instantly gets what this tab is: a live economy of real agents.
            // Tighter on mobile: every pixel of chat height matters there.
            Padding(
              padding:
                  EdgeInsets.fromLTRB(20, 0, 20, _isMobile ? 6 : 10),
              child: Text(
                'Autonomous AI agents with their own wallets — they trade, pay each other in USDC, and build on-chain reputation. Live on Arc.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: _isMobile ? 11 : 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelColor: t.brand,
              unselectedLabelColor: t.textMuted,
              indicatorColor: t.brand,
              labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: _isMobile ? 12.5 : 13.5),
              tabs: const [
                Tab(text: 'Live Swarm'),
                Tab(text: 'My Agent'),
                Tab(text: 'Signals'),
                Tab(text: 'Proof'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const WebLayout(maxWidth: 760, child: LiveSwarmView()),
                  WebLayout(
                      maxWidth: 720, child: _started ? _chat(t) : _setup(t)),
                  const WebLayout(maxWidth: 720, child: SignalsMarketplace()),
                  const WebLayout(maxWidth: 720, child: ProofView()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setup(PulsThemeColors t) {
    final signedIn = _userId != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZoomIn(
              duration: const Duration(milliseconds: 500),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.brand.withValues(alpha: 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                  border: Border.all(
                    color: t.brand.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: PulsEmoji.icon('🤖', size: 80),
              )
                  .animate(
                      onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(
                      duration: 2000.ms,
                      color: Colors.white.withValues(alpha: 0.4))
                  .scaleXY(
                      end: 1.05, duration: 2000.ms, curve: Curves.easeInOut),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: Text('Autonomous Trading Agent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(height: 8),
            FadeInUp(
              delay: const Duration(milliseconds: 160),
              child: Text(
                'Fund a budget-capped AI agent with its own Arc wallet and on-chain ERC-8004 identity. It trades predictions for you — autonomously.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: t.textMuted, fontSize: 14, height: 1.45),
              ),
            ),
            const SizedBox(height: 22),
            FadeInUp(
              delay: const Duration(milliseconds: 220),
              child: Column(
                children: [
                  _feature(t, Icons.account_balance_wallet_rounded,
                      'Its own Circle MPC wallet on Arc'),
                  _feature(t, Icons.verified_rounded,
                      'Verifiable ERC-8004 on-chain identity'),
                  _feature(t, Icons.shield_rounded,
                      "Spends only what you fund — can't exceed budget"),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FadeInUp(
              delay: const Duration(milliseconds: 280),
              child: TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.text),
                decoration: InputDecoration(
                  labelText: 'Budget (USDC)',
                  labelStyle: TextStyle(color: t.textMuted),
                  prefixText: '\$',
                  prefixStyle: TextStyle(color: t.text),
                  filled: true,
                  fillColor: t.surfaceRaised,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 320),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [5, 10, 25, 50].map((v) {
                  final sel = _budget.text == v.toString();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Tactile(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _budget.text = '$v'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? t.brand : t.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? t.brand : t.border),
                        ),
                        child: Text('\$$v',
                            style: TextStyle(
                                color: sel ? Colors.white : t.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 360),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (!signedIn || _busy) ? null : _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(signedIn ? 'Activate Agent' : 'Sign in first',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(PulsThemeColors t, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: t.brand),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: t.textMuted, fontSize: 13.5, height: 1.3))),
          ],
        ),
      );

  Future<void> _updateStrategy(String value) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      hapticLight();
      final r = await _post(
          '/api/agent/strategy', {'userId': uid, 'strategy': value});
      setState(() {
        _strategy = r['strategy'] as String? ?? 'NONE';
        final strategyName = _strategy == 'NONE' ? 'Manual Chat' : 'DCA';
        _msgs.add(_Msg(true,
            '⚙️ Presets changed: Autonomous strategy set to **$strategyName** mode.'));
      });
    } catch (e) {
      _toast(e.toString());
    }
  }

  Widget _strategySelector(PulsThemeColors t, {VoidCallback? onChanged}) {
    // [onChanged] fires after a strategy tap alongside the screen-level
    // setState — lets embedded hosts (e.g. the mobile ⋮ sheet) rebuild too.
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 16, color: t.brand),
              const SizedBox(width: 6),
              Text(
                'AGENT AUTONOMOUS STRATEGY',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _strategy == 'NONE' ? t.border : t.yesBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _strategy == 'NONE' ? 'Manual Chat' : 'DCA Active',
                  style: TextStyle(
                    color: _strategy == 'NONE' ? t.textMuted : t.yes,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _strategyOption(
                      t, 'NONE', 'Manual', Icons.chat_bubble_outline_rounded,
                      onChanged: onChanged)),
              const SizedBox(width: 8),
              Expanded(
                  child: _strategyOption(t, 'DCA', 'DCA', Icons.schedule_rounded,
                      onChanged: onChanged)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strategyOption(
      PulsThemeColors t, String value, String label, IconData icon,
      {VoidCallback? onChanged}) {
    final isSelected = _strategy == value;
    final isPremium = value == 'DCA';

    Widget content = Container(
      height: 42,
      decoration: BoxDecoration(
        color: isSelected
            ? (isPremium ? t.brand.withValues(alpha: 0.15) : t.brand)
            : t.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isSelected ? t.brand : t.border,
            width: isSelected && isPremium ? 1.5 : 1.0),
        boxShadow: isSelected && isPremium
            ? [
                BoxShadow(
                    color: t.brand.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1)
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 14,
              color: isSelected
                  ? (isPremium ? t.brand : Colors.white)
                  : t.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? (isPremium ? t.brand : Colors.white) : t.text,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (isPremium && isSelected) {
      content = content
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(
              duration: 2000.ms, color: Colors.white.withValues(alpha: 0.3))
          .elevation(end: 4, color: t.brand);
    }

    return Tactile(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _updateStrategy(value);
        onChanged?.call();
      },
      child: content,
    );
  }

  Widget _chat(PulsThemeColors t) {
    final mobile = _isMobile;
    return Column(
      children: [
        _header(t),
        // Tools stay inline on desktop; on mobile they live in the ⋮ sheet.
        if (!mobile && _showTools) _toolsPanel(t),
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding:
                    EdgeInsets.fromLTRB(mobile ? 12 : 16, 8, mobile ? 12 : 16, 16),
                sliver: SliverList.builder(
                  itemCount: _msgs.length,
                  itemBuilder: (_, mi) => RepaintBoundary(
                    key: ValueKey(mi),
                    child: _bubble(_msgs[mi], t),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_busy) _thinking(t),
        // Quick buys are tucked behind the composer's «+» on mobile — the
        // permanent bar cost ~100px of chat height for a rarely-used action.
        if (!mobile) _quickBuyBar(t),
        _composer(t, mobile: mobile),
      ],
    );
  }

  // Fast one-tap buys, routed through the agent (it picks + sizes + executes).
  void _quickBuy(String instruction) {
    if (_busy || _userId == null) return;
    hapticLight();
    _input.text = instruction;
    _send();
  }

  Widget _quickBuyBar(PulsThemeColors t) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Row(
              children: [
                Text('ONE-TAP BUYS',
                    style: TextStyle(
                        color: t.textSubtle,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3)),
                const Spacer(),
                Text('agent picks & executes',
                    style: TextStyle(color: t.textSubtle, fontSize: 9.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: _quickAction(
                    t,
                    Icons.trending_up_rounded,
                    'Top Market',
                    'hottest trending now',
                    accent: t.yes,
                    onTap: () => _quickBuy(
                        'Buy \$2 on the single hottest trending market right now — pick it yourself and execute immediately.'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickAction(
                    t,
                    Icons.bolt_rounded,
                    'Top Signal',
                    'top-rated creator alpha',
                    onTap: () => _quickBuy(
                        'Find the top-rated creator signal and buy \$2 into its market right now.'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _quickAction(
    PulsThemeColors t,
    IconData icon,
    String label,
    String sublabel, {
    Color? accent,
    double height = 50,
    required VoidCallback onTap,
  }) {
    final disabled = _busy;
    final gradient = accent == null;
    return Tactile(
      behavior: HitTestBehavior.opaque,
      hoverScale: 1.02,
      onTap: onTap, // _quickBuy guards _busy internally
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          gradient: gradient ? PulsColors.pulseGradient : null,
          color: gradient
              ? null
              : (disabled ? t.surface : accent.withValues(alpha: 0.10)),
          borderRadius: BorderRadius.circular(14),
          border: gradient
              ? null
              : Border.all(
                  color: disabled ? t.border : accent.withValues(alpha: 0.40)),
          boxShadow: gradient && !disabled
              ? PulsColors.neonGlow(color: PulsColors.brandPink)
              : null,
        ),
        alignment: Alignment.center,
        child: Opacity(
          opacity: disabled ? 0.45 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gradient
                      ? Colors.white.withValues(alpha: 0.22)
                      : accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 15, color: gradient ? Colors.white : accent),
              ),
              const SizedBox(width: 9),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: gradient ? Colors.white : t.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800)),
                  Text(sublabel,
                      style: TextStyle(
                          color: gradient
                              ? Colors.white.withValues(alpha: 0.75)
                              : t.textSubtle,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.flash_on_rounded,
                  size: 13,
                  color:
                      gradient ? Colors.white.withValues(alpha: 0.85) : accent),
            ],
          ),
        ),
      ),
    );
  }

  // Agent tools (autonomous strategy + Finance Director), tucked behind the
  // header's tune button so the conversation stays the focus. Collapsed default.
  Widget _toolsPanel(PulsThemeColors t) => Container(
        constraints: const BoxConstraints(maxHeight: 360),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _strategySelector(t),
              const FinanceDirectorCard(),
            ],
          ),
        ),
      );

  Widget _thinking(PulsThemeColors t) {
    // Build a live pipeline of the steps the agent will actually take, inferred
    // from what the user just asked. Pure questions (no signal/trade intent)
    // fall back to the default reasoning shimmer.
    final lastUser = _msgs
        .lastWhere((m) => !m.fromAgent, orElse: () => _Msg(false, ''))
        .text
        .toLowerCase();
    final wantsSignal = RegExp(r'signal|alpha|forecast').hasMatch(lastUser);
    final wantsTrade =
        RegExp(r'\b(buy|trade|bet|stake|long|short|sell)\b|\$\s*\d')
            .hasMatch(lastUser);
    if (!wantsSignal && !wantsTrade) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ShimmerText(
            highlightColor: t.brand,
            phrases: const [
              'Thinking…',
              'Reviewing your portfolio…',
              'Checking the latest odds…',
              'Reasoning through it…',
              'Putting it together…',
            ],
          ),
        ),
      );
    }
    final steps = <(IconData, String)>[
      (Icons.travel_explore_rounded, 'Researching the web'),
      if (wantsSignal) (Icons.workspace_premium_rounded, 'Buying alpha · x402'),
      (Icons.psychology_rounded, 'Reasoning'),
      if (wantsTrade) (Icons.bolt_rounded, 'Trading on Arc'),
    ];
    return _PipelineTracker(steps: steps);
  }

  Widget _header(PulsThemeColors t) {
    final addr = _agentAddress ?? '';
    final short = addr.length > 10
        ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}'
        : addr;
    final remaining =
        (_budgetVal - _spent).clamp(0, double.infinity).toDouble();
    // Mobile: one ~46px row instead of the ~100px desktop card. Deposit,
    // Withdraw, tools and reputation move into the ⋮ sheet — nothing is lost,
    // but the chat reclaims the vertical space.
    if (_isMobile) return _mobileHeader(t, short, remaining);
    return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.surfaceRaised.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: t.brandSubtle, shape: BoxShape.circle),
                      child: Icon(Icons.smart_toy_rounded,
                          color: t.brand, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: addr.isEmpty
                                    ? null
                                    : () => launchUrl(
                                        Uri.parse(
                                            'https://testnet.arcscan.app/address/$addr'),
                                        mode: LaunchMode.externalApplication),
                                child: Text(short,
                                    style: TextStyle(
                                        color: t.brand,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (_registered) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.verified_rounded,
                                    size: 13, color: t.yes),
                                Text(' ERC-8004',
                                    style: TextStyle(
                                        color: t.yes,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                              'Budget \$${remaining.toStringAsFixed(2)} / \$${_budgetVal.toStringAsFixed(2)} USDC',
                              style:
                                  TextStyle(color: t.textMuted, fontSize: 11)),
                          if (_registered) ...[
                            const SizedBox(height: 3),
                            GestureDetector(
                              onTap: addr.isEmpty
                                  ? null
                                  : () => launchUrl(
                                      Uri.parse(
                                          'https://testnet.arcscan.app/address/$addr'),
                                      mode: LaunchMode.externalApplication),
                              child: Row(
                                children: [
                                  const Icon(Icons.workspace_premium_rounded,
                                      size: 12, color: PulsColors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    _reputation > 0
                                        ? 'Reputation: $_reputation on-chain attestation${_reputation == 1 ? '' : 's'}'
                                        : 'Reputation: builds as it trades',
                                    style: TextStyle(
                                        color: t.textSubtle,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (_agentId != null) ...[
                                    const SizedBox(width: 5),
                                    Text('· Agent #$_agentId',
                                        style: TextStyle(
                                            color: t.textSubtle,
                                            fontSize: 10.5)),
                                  ],
                                  const SizedBox(width: 3),
                                  Icon(Icons.open_in_new_rounded,
                                      size: 10, color: t.textSubtle),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Agent tools — strategy & Finance Director',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 28),
                          icon: Icon(
                              _showTools
                                  ? Icons.close_rounded
                                  : Icons.tune_rounded,
                              size: 18,
                              color: _showTools ? t.brand : t.textMuted),
                          onPressed: () =>
                              setState(() => _showTools = !_showTools),
                        ),
                        const SizedBox(height: 2),
                        TextButton(
                          onPressed: _busy ? null : _deposit,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            backgroundColor: t.brand,
                            minimumSize: const Size(84, 28),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Deposit',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                        if (remaining > 0.01) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _busy ? null : _withdraw,
                            style: TextButton.styleFrom(
                              foregroundColor: t.brand,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              backgroundColor: t.brandSubtle,
                              minimumSize: const Size(84, 28),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Withdraw',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ))
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, duration: 400.ms, curve: Curves.easeOut);
  }

  // ── Mobile header — single 46px row ──────────────────────────────────────────
  Widget _mobileHeader(PulsThemeColors t, String short, double remaining) {
    final addr = _agentAddress ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
        decoration: BoxDecoration(
          color: t.surfaceRaised.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration:
                  BoxDecoration(color: t.brandSubtle, shape: BoxShape.circle),
              child: Icon(Icons.smart_toy_rounded, color: t.brand, size: 15),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: addr.isEmpty
                    ? null
                    : () => launchUrl(
                        Uri.parse('https://testnet.arcscan.app/address/$addr'),
                        mode: LaunchMode.externalApplication),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(short,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: t.brand,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (_registered) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, size: 12, color: t.yes),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border.withValues(alpha: 0.6)),
              ),
              child: Text('\$${remaining.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                tooltip: 'Agent controls',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz_rounded,
                    size: 19, color: t.textMuted),
                onPressed: _showAgentMenu,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.08, duration: 300.ms, curve: Curves.easeOut);
  }

  // ── Agent controls sheet (mobile ⋮) ──────────────────────────────────────────
  void _showAgentMenu() {
    final t = context.puls;
    final addr = _agentAddress ?? '';
    final remaining = (_budgetVal - _spent).clamp(0, double.infinity);
    var showTools = false; // lives across sheet rebuilds (outside the builder)
    PulsSheet.show(
      context,
      builder: (sheetCtx) => PulsSheetSurface(
        raised: true,
        scrollable: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: StatefulBuilder(builder: (sheetCtx, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy_rounded, color: t.brand, size: 18),
                  const SizedBox(width: 8),
                  Text('My agent',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  if (_registered) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.verified_rounded, size: 14, color: t.yes),
                    Text(' ERC-8004',
                        style: TextStyle(
                            color: t.yes,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _menuRow(t, Icons.account_balance_wallet_rounded, 'Deposit',
                  'add USDC to the agent budget',
                  iconColor: t.brand, onTap: () {
                Navigator.pop(sheetCtx);
                _deposit();
              }),
              if (remaining > 0.01)
                _menuRow(t, Icons.savings_rounded, 'Withdraw',
                    'return \$${remaining.toStringAsFixed(2)} to your wallet',
                    iconColor: PulsColors.amber, onTap: () {
                  Navigator.pop(sheetCtx);
                  _withdraw();
                }),
              _menuRow(t, Icons.tune_rounded, 'Agent tools',
                  'strategy & Finance Director', iconColor: t.brand,
                  onTap: () => setSheetState(() => showTools = !showTools)),
              if (showTools) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _strategySelector(t,
                      onChanged: () => setSheetState(() {})),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: FinanceDirectorCard(),
                ),
              ],
              _menuRow(t, Icons.workspace_premium_rounded,
                  _reputation > 0
                      ? 'Reputation: $_reputation attestation${_reputation == 1 ? '' : 's'}'
                      : 'Reputation: builds as it trades',
                  addr.isEmpty ? null : 'view on Arcscan',
                  iconColor: t.yes,
                  enabled: addr.isNotEmpty, onTap: () {
                Navigator.pop(sheetCtx);
                launchUrl(
                    Uri.parse('https://testnet.arcscan.app/address/$addr'),
                    mode: LaunchMode.externalApplication);
              }),
            ],
          );
        }),
      ),
    );
  }

  Widget _menuRow(PulsThemeColors t, IconData icon, String title,
      String? subtitle,
      {required Color iconColor, VoidCallback? onTap, bool enabled = true}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: enabled ? t.text : t.textSubtle,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: t.textSubtle),
        ],
      ),
    );
    if (!enabled || onTap == null) return row;
    return Tactile(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  // ── Quick buys sheet (mobile «+») ────────────────────────────────────────────
  void _showQuickBuysSheet() {
    final t = context.puls;
    PulsSheet.show(
      context,
      builder: (sheetCtx) => PulsSheetSurface(
        raised: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ONE-TAP BUYS',
                style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3)),
            const SizedBox(height: 2),
            Text('agent picks & executes',
                style: TextStyle(color: t.textSubtle, fontSize: 11)),
            const SizedBox(height: 12),
            _quickAction(
              t,
              Icons.trending_up_rounded,
              'Top Market',
              'hottest trending now',
              accent: t.yes,
              height: 54,
              onTap: () {
                Navigator.pop(sheetCtx);
                _quickBuy(
                    'Buy \$2 on the single hottest trending market right now — pick it yourself and execute immediately.');
              },
            ),
            const SizedBox(height: 8),
            _quickAction(
              t,
              Icons.bolt_rounded,
              'Top Signal',
              'top-rated creator alpha',
              height: 54,
              onTap: () {
                Navigator.pop(sheetCtx);
                _quickBuy(
                    'Find the top-rated creator signal and buy \$2 into its market right now.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Msg m, PulsThemeColors t) {
    final mobile = _isMobile;
    final align =
        m.fromAgent ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final bg = m.fromAgent ? t.surfaceRaised : t.brand;
    final fg = m.fromAgent ? t.text : Colors.white;
    return Padding(
      padding: EdgeInsets.only(bottom: mobile ? 10 : 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: _bubbleMax),
            padding: EdgeInsets.symmetric(
                horizontal: mobile ? 12 : 16, vertical: mobile ? 9 : 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(m.fromAgent ? 4 : 16),
                bottomRight: Radius.circular(m.fromAgent ? 16 : 4),
              ),
              boxShadow: m.fromAgent
                  ? [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : [
                      BoxShadow(
                          color: t.brand.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
              border: m.fromAgent
                  ? Border.all(color: t.border.withValues(alpha: 0.5))
                  : null,
            ),
            child: PulsEmojiText(m.text,
                style: TextStyle(
                    color: fg,
                    fontSize: mobile ? 13.5 : 14.5,
                    height: 1.38)),
          ),
          if (m.fromAgent && m.sources.isNotEmpty) ...[
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _bubbleMax),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.sources.map((s) {
                  final src = (s['source'] as String?) ?? 'source';
                  final url = s['url'] as String?;
                  return GestureDetector(
                    onTap: url == null
                        ? null
                        : () => launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore_rounded,
                              size: 10, color: t.brand),
                          const SizedBox(width: 4),
                          Text(src,
                              style: TextStyle(
                                  color: t.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          // Verifiable, on-chain action receipts — the agent's signal buys and
          // trades, each clickable through to the market + Arcscan.
          if (m.fromAgent) ...[
            for (final s in m.signals) _signalCard(s, t),
            for (final tr in m.trades) _tradeCard(tr, t),
          ],
          if (m.fromAgent && m.trades.isEmpty && m.txId != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => launchUrl(
                  Uri.parse('https://testnet.arcscan.app/tx/${m.txId}'),
                  mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 13, color: t.yes),
                  const SizedBox(width: 3),
                  Text('Trade executed · View on Arcscan',
                      style: TextStyle(
                          color: t.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 3),
                  Icon(Icons.open_in_new_rounded, size: 11, color: t.brand),
                ],
              ),
            ),
          ] else if (m.fromAgent && m.trades.isEmpty && m.contract != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: t.textSubtle)),
                const SizedBox(width: 6),
                Text('Trade submitted · confirming on-chain…',
                    style: TextStyle(color: t.textSubtle, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Verifiable action cards — the WOW: every agent action, clickable on-chain.
  Widget _signalCard(Map<String, dynamic> s, PulsThemeColors t) {
    final title = (s['title'] as String?) ?? 'Premium signal';
    final price = (s['price'] as num?)?.toDouble() ?? 0;
    final stance = (s['stance'] as String?)?.toUpperCase();
    final slug = s['marketSlug'] as String?;
    const accent = Color(0xFF8B5CF6);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: BoxConstraints(maxWidth: _bubbleMax),
      padding:
          EdgeInsets.all(_isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  size: 14, color: accent),
              const SizedBox(width: 6),
              const Text('ALPHA UNLOCKED',
                  style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0)),
              const Spacer(),
              Text('\$${price.toStringAsFixed(3)} · x402',
                  style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(title,
              style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25)),
          if (stance != null || slug != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (stance != null)
                  _pill(stance, stance == 'NO' ? t.no : t.yes),
                if (stance != null && slug != null) const SizedBox(width: 8),
                if (slug != null)
                  _linkChip(
                      'Market',
                      Icons.open_in_new_rounded,
                      accent,
                      () => launchUrl(Uri.parse('$appUrl/m/$slug'),
                          mode: LaunchMode.externalApplication)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tradeCard(Map<String, dynamic> tr, PulsThemeColors t) {
    final q = _prettyMarket(
        (tr['question'] as String?) ?? (tr['slug'] as String?) ?? 'Market');
    final side =
        ((tr['side'] as String?) ?? 'YES').toUpperCase() == 'NO' ? 'NO' : 'YES';
    final amt = (tr['usdcAmount'] as num?)?.toDouble() ?? 0;
    final slug = tr['slug'] as String?;
    final txHash = tr['txHash'] as String?;
    final accent = side == 'NO' ? t.no : t.yes;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: BoxConstraints(maxWidth: _bubbleMax),
      padding:
          EdgeInsets.all(_isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text('TRADE EXECUTED',
                  style: TextStyle(
                      color: accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0)),
              const Spacer(),
              _pill(
                  '$side · \$${amt.toStringAsFixed(amt >= 1 ? 0 : 2)}', accent),
            ],
          ),
          const SizedBox(height: 6),
          Text(q,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (slug != null)
                _linkChip(
                    'Open market',
                    Icons.open_in_new_rounded,
                    accent,
                    () => launchUrl(Uri.parse('$appUrl/m/$slug'),
                        mode: LaunchMode.externalApplication)),
              if (slug != null) const SizedBox(width: 8),
              if (txHash != null)
                _linkChip(
                    'Arcscan',
                    Icons.verified_rounded,
                    t.brand,
                    () => launchUrl(
                        Uri.parse('https://testnet.arcscan.app/tx/$txHash'),
                        mode: LaunchMode.externalApplication))
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: t.textSubtle)),
                    const SizedBox(width: 6),
                    Text('confirming…',
                        style: TextStyle(color: t.textSubtle, fontSize: 11)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style:
                TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  String _prettyMarket(String q) {
    if (q.contains(' ')) return q; // already a human-readable question
    final s = q.replaceAll(RegExp(r'-\d{6,}$'), '').replaceAll('-', ' ').trim();
    return s.isEmpty ? q : s[0].toUpperCase() + s.substring(1);
  }

  Widget _linkChip(String label, IconData icon, Color c, VoidCallback onTap) =>
      Tactile(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: c),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  Widget _composer(PulsThemeColors t, {bool mobile = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          mobile ? 10 : 16, mobile ? 8 : 12, mobile ? 10 : 16, mobile ? 10 : 24),
      decoration: BoxDecoration(
        color: t.bg,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(mobile ? 20 : 24),
          border: Border.all(color: t.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        padding:
            EdgeInsets.symmetric(horizontal: mobile ? 5 : 8, vertical: 5),
        child: Row(
          children: [
            // Mobile: quick buys live behind «+» instead of a permanent bar.
            if (mobile) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showQuickBuysSheet,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.surface,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: t.border.withValues(alpha: 0.7)),
                  ),
                  child: Icon(Icons.add_rounded,
                      size: 19, color: t.textMuted),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: TextField(
                controller: _input,
                style:
                    TextStyle(color: t.text, fontSize: mobile ? 14 : 15),
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask the agent to trade…',
                  hintStyle: TextStyle(color: t.textSubtle),
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: mobile ? 9 : 10),
                  border: InputBorder.none,
                ),
              ),
            ),
            SizedBox(width: mobile ? 4 : 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input,
              builder: (context, val, child) {
                final isEmpty = val.text.trim().isEmpty;
                final disabled = _busy || isEmpty;
                return GestureDetector(
                  onTap: disabled ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: mobile ? 36 : 44,
                    height: mobile ? 36 : 44,
                    decoration: BoxDecoration(
                        color: disabled ? t.surface : t.brand,
                        shape: BoxShape.circle,
                        boxShadow: disabled
                            ? []
                            : [
                                BoxShadow(
                                    color: t.brand.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1)
                              ]),
                    child: Icon(Icons.arrow_upward_rounded,
                        color: disabled ? t.textSubtle : Colors.white,
                        size: mobile ? 18 : 20),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
