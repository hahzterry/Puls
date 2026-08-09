import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart' show WalletServiceScope;
import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/motion.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/puls_snack.dart';
import '../../core/widgets/tactile.dart';
import '../wallet/wallet_service.dart';
import '../wallet/web3_wallet_bridge.dart';

/// ── Puls Invest: sponsor an AI agent with USDC ─────────────────────────────
///
/// Live protocol dashboard: every agent on Arc with its capital pool, PnL and
/// APY. Stake USDC with your Puls wallet (the gasless Circle SCA wallet that
/// comes with Google sign-in — no MetaMask needed) or, as a fallback, from a
/// browser wallet via Circle Gateway + x402 signature. Withdraw your pro-rata
/// claim anytime — treasury pays out on-chain.
///
/// Endpoints (https://api.pulsmarket.tech):
///   GET  /api/invest/agents          → all agents + live stats
///   GET  /api/invest/me?address=…    → my positions
///   POST /api/invest/:agentId        → SCA invest (Google wallet, gasless)
///   GET  /api/invest/:agentId?amountUsdc=…  → x402 paywall → settle (web3)
///   POST /api/invest/withdraw        → { agentId, address, signature? }
class AgentSponsorshipScreen extends StatefulWidget {
  const AgentSponsorshipScreen({super.key});

  @override
  State<AgentSponsorshipScreen> createState() => _AgentSponsorshipScreenState();
}

class _Agent {
  const _Agent({
    required this.id,
    required this.key,
    required this.name,
    required this.glyph,
    required this.role,
    required this.strategy,
    this.address,
    this.balance = 0,
    this.invested = 0,
    this.pool = 0,
    this.tvl = 0,
    this.realizedPnlUsdc = 0,
    this.roi30dPct = 0,
    this.winRatePct = 0,
    this.netUsdc = 0,
    this.apyEstimatePct = 0,
    this.isProfitable = false,
  });

  final String id;
  final String key;
  final String name;
  final String glyph;
  final String role;
  final String strategy;
  final String? address;
  final double balance;
  final double invested;
  final double pool;
  final double tvl;
  final double realizedPnlUsdc;
  final double roi30dPct;
  final double winRatePct;
  final double netUsdc;
  final double apyEstimatePct;
  final bool isProfitable;

  factory _Agent.fromJson(Map<String, dynamic> j) => _Agent(
        id: j['id'] as String? ?? '',
        key: j['key'] as String? ?? '',
        name: j['name'] as String? ?? 'Agent',
        glyph: j['glyph'] as String? ?? '🤖',
        role: j['role'] as String? ?? 'trader',
        strategy: j['strategy'] as String? ?? '',
        address: j['address'] as String?,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        invested: (j['invested'] as num?)?.toDouble() ?? 0,
        pool: (j['pool'] as num?)?.toDouble() ?? 0,
        tvl: (j['tvlUsdc'] as num?)?.toDouble() ?? (j['pool'] as num?)?.toDouble() ?? 0,
        realizedPnlUsdc: (j['realizedPnlUsdc'] as num?)?.toDouble() ?? (j['netUsdc'] as num?)?.toDouble() ?? 0,
        roi30dPct: (j['roi30dPct'] as num?)?.toDouble() ?? 0,
        winRatePct: (j['winRatePct'] as num?)?.toDouble() ?? 0,
        netUsdc: (j['netUsdc'] as num?)?.toDouble() ?? 0,
        apyEstimatePct: (j['apyEstimatePct'] as num?)?.toDouble() ?? 0,
        isProfitable: j['isProfitable'] as bool? ?? false,
      );
}

class _Position {
  const _Position({
    required this.agentId,
    required this.agentName,
    required this.glyph,
    required this.role,
    required this.invested,
    required this.pool,
    required this.claimable,
  });

  final String agentId;
  final String agentName;
  final String glyph;
  final String role;
  final double invested;
  final double pool;
  final double claimable;

  factory _Position.fromJson(Map<String, dynamic> j) => _Position(
        agentId: j['agentId'] as String? ?? '',
        agentName: j['agentName'] as String? ?? 'Agent',
        glyph: j['glyph'] as String? ?? '🤖',
        role: j['role'] as String? ?? 'trader',
        invested: (j['invested'] as num?)?.toDouble() ?? 0,
        pool: (j['pool'] as num?)?.toDouble() ?? 0,
        claimable: (j['claimable'] as num?)?.toDouble() ?? 0,
      );
}

class _AgentSponsorshipScreenState extends State<AgentSponsorshipScreen> {
  List<_Agent> _agents = const [];
  List<_Position> _positions = const [];
  bool _loading = true;
  String? _walletAddress;
  bool _scaWallet = false;
  bool _busy = false;
  WalletService? _walletService;

  @override
  void initState() {
    super.initState();
    _walletService = WalletServiceScope.of(context);
    _walletService!.addListener(_onWalletChanged);
    _load();
    final sca = _walletService!.state.walletAddress;
    if (sca != null && sca.isNotEmpty) {
      _walletAddress = sca;
      _scaWallet = true;
    } else {
      _walletAddress = getBrowserWalletAddress();
    }
    if (_walletAddress != null) _loadPositions(_walletAddress!);
  }

  @override
  void dispose() {
    _walletService?.removeListener(_onWalletChanged);
    super.dispose();
  }

  void _onWalletChanged() {
    final sca = _walletService!.state.walletAddress;
    if (sca != null && sca.isNotEmpty && _walletAddress != sca) {
      setState(() {
        _walletAddress = sca;
        _scaWallet = true;
      });
      _loadPositions(sca);
    }
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/invest/agents'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('bad status ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = <_Agent>[];
      for (final raw in (body['agents'] as List? ?? const [])) {
        list.add(_Agent.fromJson(raw as Map<String, dynamic>));
      }
      if (!mounted) return;
      setState(() {
        _agents = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPositions(String address) async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/invest/me?address=$address'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = <_Position>[];
      for (final raw in (body['positions'] as List? ?? const [])) {
        list.add(_Position.fromJson(raw as Map<String, dynamic>));
      }
      if (!mounted) return;
      setState(() => _positions = list);
    } catch (_) {}
  }

  Future<String?> _connect() async {
    if (_walletAddress != null) return _walletAddress;
    // Prefer the Puls SCA wallet (Google sign-in) — no MetaMask required.
    final sca = _walletService?.state.walletAddress;
    if (sca != null && sca.isNotEmpty) {
      setState(() {
        _walletAddress = sca;
        _scaWallet = true;
      });
      await _loadPositions(sca);
      return sca;
    }
    if (!hasBrowserWallet()) {
      PulsSnack.show(context,
          'No wallet found — sign in with Google in the Wallet tab to get your Puls wallet, or install MetaMask.',
          duration: const Duration(seconds: 5));
      return null;
    }
    final result = await connectBrowserWallet();
    if (!mounted) return null;
    if (result.error != null) {
      PulsSnack.error(context, result.error!);
      return null;
    }
    setState(() {
      _walletAddress = result.address;
      _scaWallet = false;
    });
    if (result.address != null) await _loadPositions(result.address!);
    return result.address;
  }

  // ── Invest (Replenish) ────────────────────────────────────────────────────
  Future<void> _invest(_Agent agent, double amount) async {
    final addr = await _connect();
    if (addr == null || !mounted) return;
    setState(() => _busy = true);

    final stage = ValueNotifier<String>('Connecting wallet…');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BusyDialog(title: 'Replenishing ${agent.name}', stage: stage),
    );

    try {
      Map<String, dynamic>? settled;
      String? depositTx;
      bool alreadySettled = false;
      if (_scaWallet) {
        stage.value = 'Paying from your Puls wallet…';
        final res = await _walletService!.investInAgent(agent.id, amount);
        settled = res;
      } else {
        stage.value = 'Funding Gateway wallet…';
        final result = await investToAgent(agent.id, amount.toStringAsFixed(2));
        if (result.error != null) throw StateError(result.error!);
        settled = result.data;
        depositTx = result.depositTx;
        alreadySettled = result.alreadySettled;
      }
      if (!mounted) return;
      final investedNow = (settled?['invested'] as num?)?.toDouble();
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _busy = false);
      }
      PulsSnack.show(
        context,
        alreadySettled
            ? 'Already active — position refreshed'
            : '${agent.glyph} ${agent.name}: ${investedNow?.toStringAsFixed(2) ?? amount.toStringAsFixed(2)} USDC invested',
        duration: const Duration(seconds: 4),
      );
      _refresh();
      if (depositTx != null && mounted) {
        await _txActions(depositTx);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        PulsSnack.error(context, e.toString().replaceFirst('StateError: ', ''));
      }
      setState(() => _busy = false);
    } finally {
      stage.dispose();
    }
  }

  // ── Withdraw ──────────────────────────────────────────────────────────────
  Future<void> _withdraw(_Agent agent) async {
    final addr = await _connect();
    if (addr == null || !mounted) return;
    final position =
        _positions.where((p) => p.agentId == agent.id).toList().isEmpty
            ? null
            : _positions.firstWhere((p) => p.agentId == agent.id);
    if (position == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.puls.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Withdraw from ${agent.name}?',
            style: TextStyle(color: ctx.puls.text, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          'You claim \$${position.claimable.toStringAsFixed(4)} USDC '
          '(pro-rata share of the pool). Your position closes.',
          style: TextStyle(color: ctx.puls.textMuted, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.puls.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Withdraw', style: TextStyle(color: ctx.puls.brand, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final stage = ValueNotifier<String>('Signing with your wallet…');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BusyDialog(title: 'Withdrawing', stage: stage),
    );

    try {
      String? txHash;
      double? amountUsdc;
      if (_scaWallet) {
        stage.value = 'Processing payout…';
        final res = await _walletService!.withdrawFromAgent(agent.id);
        txHash = res['txHash'] as String?;
        amountUsdc = (res['amountUsdc'] as num?)?.toDouble();
      } else {
        stage.value = 'Awaiting signature…';
        final signed = await signWithdrawMessage(agent.id);
        if (signed.error != null) throw StateError(signed.error!);
        if (signed.address == null || signed.signature == null) {
          throw StateError('Withdraw signing failed');
        }
        stage.value = 'Processing payout…';
        final res = await http
            .post(
              Uri.parse('$backendUrl/api/invest/withdraw'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'agentId': agent.id,
                'address': signed.address,
                'signature': signed.signature,
              }),
            )
            .timeout(const Duration(seconds: 45));
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode != 200) {
          throw StateError((body['error'] as String?) ?? 'Withdraw failed');
        }
        txHash = body['txHash'] as String?;
        amountUsdc = (body['amountUsdc'] as num?)?.toDouble();
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() => _busy = false);
      PulsSnack.show(
        context,
        'Withdrawn ${amountUsdc?.toStringAsFixed(4) ?? ''} USDC — transaction ${shortHash(txHash)}',
        duration: const Duration(seconds: 5),
      );
      _refresh();
      if (txHash != null && mounted) await _txActions(txHash);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        PulsSnack.error(context, e.toString().replaceFirst('StateError: ', ''));
      }
      setState(() => _busy = false);
    } finally {
      stage.dispose();
    }
  }

  Future<void> _refresh() async {
    await _load();
    final addr = _walletAddress;
    if (addr != null) await _loadPositions(addr);
  }

  Future<void> _txActions(String txHash) async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.puls.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Transaction sent',
            style: TextStyle(color: ctx.puls.text, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text('${shortHash(txHash)}\nView on Arcscan?',
            style: TextStyle(color: ctx.puls.textMuted, fontSize: 13.5, fontFamily: 'monospace')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'close'),
            child: Text('Close', style: TextStyle(color: ctx.puls.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'open'),
            child: Text('Open Arcscan', style: TextStyle(color: ctx.puls.brand, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (action == 'open') {
      launchUrl(Uri.parse('https://testnet.arcscan.app/tx/$txHash'),
          mode: LaunchMode.externalApplication);
    }
  }

  static String shortHash(String? hash) {
    if (hash == null || hash.length <= 14) return hash ?? '';
    return '${hash.substring(0, 6)}…${hash.substring(hash.length - 4)}';
  }

  String _usd(double v, {int decimals = 2}) {
    final s = v < 1 && v > 0 ? v.toStringAsFixed(4) : v.toStringAsFixed(decimals);
    return '\$$s';
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tactile(
            onTap: () => Navigator.of(context).maybePop(),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border),
                ),
                child: Icon(Icons.arrow_back_rounded, color: t.text, size: 18),
              ),
            ),
          ),
        ),
        title: const AnimatedGradientText('Puls Invest',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _WalletPill(
              t: t,
              address: _walletAddress,
              sca: _scaWallet,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const _SkeletonList()
            : _agents.isEmpty
                ? _EmptyState(onRetry: _load)
                : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: RefreshIndicator(
                    color: t.brand,
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        _summaryCard(t),
                        const SizedBox(height: 14),
                        _sectionLabel(t, 'CAPITAL POOL'),
                        const SizedBox(height: 8),
                        ..._agents.asMap().entries.map((e) => _agentCard(t, e.value, e.key)),
                        if (_positions.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _sectionLabel(t, 'MY INVESTMENTS'),
                          const SizedBox(height: 8),
                          ..._positions.map((p) => _positionCard(t, p)),
                        ],
                        const SizedBox(height: 20),
                        _footer(t),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _summaryCard(PulsThemeColors t) {
    final totalPool =
        _agents.fold<double>(0, (s, a) => s + a.pool);
    final profitable = _agents.where((a) => a.isProfitable).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.brand.withValues(alpha: 0.14), t.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: PulsColors.pulseGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.savings_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sponsor an AI agent',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      'Pro-rata share of the capital pool · 80/20 split',
                      style:
                          TextStyle(color: t.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(t, _usd(totalPool), 'pool'),
              _divider(t),
              _stat(t, '$profitable/${_agents.length}', 'agents green'),
              _divider(t),
              _stat(t, '${_agents.length}', 'active agents'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(PulsThemeColors t, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  fontFeatures: PulsColors.tabularFigures)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: t.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider(PulsThemeColors t) =>
      Container(width: 1, height: 32, color: t.border);

  Widget _sectionLabel(PulsThemeColors t, String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            gradient: PulsColors.pulseGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: t.textSubtle,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4)),
      ],
    );
  }

  Widget _agentCard(PulsThemeColors t, _Agent a, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: index < 3
              ? t.brand.withValues(alpha: 0.35)
              : t.border,
        ),
      ),
      child: Tactile(
        hoverScale: 1.01,
        onTap: () => _investSheet(a),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(a.glyph,
                        style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: index < 3
                                    ? PulsColors.pulseGradient
                                    : null,
                                color: index < 3 ? null : t.surfaceRaised,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: index < 3
                                      ? Colors.transparent
                                      : t.border,
                                ),
                              ),
                              child: Text('${index + 1}',
                                  style: TextStyle(
                                    color: index < 3
                                        ? Colors.white
                                        : t.textSubtle,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures:
                                        PulsColors.tabularFigures,
                                  )),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: t.text,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: a.isProfitable
                                    ? t.yesBg
                                    : t.surfaceRaised,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                a.isProfitable ? '▲ profitable' : 'flat',
                                style: TextStyle(
                                  color: a.isProfitable ? t.yes : t.textSubtle,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(a.role.toUpperCase(),
                            style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _apyLabel(a),
                        style: TextStyle(
                          color: _apyColor(t, a),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          fontFeatures: PulsColors.tabularFigures,
                        ),
                      ),
                      Text('EST. APY (30D)',
                          style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStat(t, 'REALIZED PNL',
                      _signedUsd(a.realizedPnlUsdc),
                      valueColor: a.realizedPnlUsdc >= 0 ? t.yes : t.no),
                  const SizedBox(width: 12),
                  _miniStat(t, 'WIN RATE',
                      '${a.winRatePct.toStringAsFixed(1)}%'),
                  const SizedBox(width: 12),
                  _miniStat(t, '30D ROI', _signedPct(a.roi30dPct),
                      valueColor: a.roi30dPct >= 0 ? t.yes : t.no),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: t.textSubtle),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStat(t, 'POOL', _usd(a.pool)),
                  const SizedBox(width: 12),
                  _miniStat(t, 'YOURS', _usd(a.invested)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _apyLabel(_Agent a) {
    if (a.apyEstimatePct == 0) return 'n/a';
    return '${a.apyEstimatePct.toStringAsFixed(1)}%';
  }

  static Color _apyColor(PulsThemeColors t, _Agent a) {
    if (a.apyEstimatePct > 0) return t.yes;
    if (a.apyEstimatePct < 0) return t.no;
    return t.textSubtle;
  }

  String _signedUsd(double v) =>
      v >= 0 ? '+${_usd(v)}' : '−${_usd(v.abs())}';

  String _signedPct(double v) =>
      v > 0 ? '+${v.toStringAsFixed(1)}%' : '${v.toStringAsFixed(1)}%';

  Widget _miniStat(PulsThemeColors t, String label, String value,
      {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor ?? t.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFeatures: PulsColors.tabularFigures)),
        Text(label,
            style: TextStyle(color: t.textSubtle, fontSize: 9, letterSpacing: 0.6, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Invest / withdraw bottom sheet ────────────────────────────────────────
  void _investSheet(_Agent a) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InvestSheet(
        agent: a,
        busy: _busy,
        position: _positions.where((p) => p.agentId == a.id).firstOrNull,
        onInvest: (amount) {
          Navigator.of(context).pop();
          _invest(a, amount);
        },
        onWithdraw: () {
          Navigator.of(context).pop();
          _withdraw(a);
        },
      ),
    );
  }

  Widget _positionCard(PulsThemeColors t, _Position p) {
    final share = p.pool > 0 ? p.invested / p.pool : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.brand.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.glyph, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(p.agentName,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _usd(p.claimable, decimals: 4),
                  style: TextStyle(
                      color: t.brand,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFeatures: PulsColors.tabularFigures),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniStat(t, 'INVESTED', _usd(p.invested)),
              const SizedBox(width: 14),
              _miniStat(t, 'CLAIMABLE', _usd(p.claimable, decimals: 4)),
              const SizedBox(width: 14),
              _miniStat(t, 'SHARE',
                  '${(share * 100).clamp(0, 100).toStringAsFixed(2)}%'),
            ],
          ),
          const SizedBox(height: 12),
          Tactile(
            hoverScale: 1.02,
            onTap: _busy ? null : () => _withdrawPosition(p),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: Text(
                'Withdraw ${_usd(p.claimable, decimals: 4)} USDC',
                style: TextStyle(
                    color: t.brand,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawPosition(_Position p) async {
    final agent =
        _agents.where((a) => a.id == p.agentId).firstOrNull;
    if (agent != null) await _withdraw(agent);
  }

  Widget _footer(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: t.textMuted),
              const SizedBox(width: 6),
              Text('How it works',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You pay USDC from your wallet via Circle Gateway (x402 signature — no custody, no backend key). '
            'Your share of the agent pool earns pro-rata from its PnL (80/20 split). '
            'Withdraw any time with a wallet signature; the treasury pays out on-chain.',
            style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ── Wallet pill ─────────────────────────────────────────────────────────────
class _WalletPill extends StatelessWidget {
  const _WalletPill({required this.t, required this.address, required this.sca});
  final PulsThemeColors t;
  final String? address;
  final bool sca;

  @override
  Widget build(BuildContext context) {
    final connected = address != null && address!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: connected ? t.yesBg : t.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: connected ? t.yes.withValues(alpha: 0.3) : t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 7,
            width: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? t.yes : t.textSubtle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected
                ? sca
                    ? 'Puls wallet ${address!.substring(0, 5)}…${address!.substring(address!.length - 4)}'
                    : '${address!.substring(0, 5)}…${address!.substring(address!.length - 4)}'
                : 'No wallet',
            style: TextStyle(
              color: connected ? t.yes : t.textSubtle,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading state ───────────────────────────────────────────────────
/// Skeleton matching the real layout (summary card + agent cards) so the
/// first paint feels deliberate instead of a blank spinner.
class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _fade = _pulse.drive(
    Tween(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = context.reduceMotion;
    if (_reduce) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _bar(PulsThemeColors t, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: t.textSubtle.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(5),
        ),
      );

  Widget _block(PulsThemeColors t, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: FadeTransition(
          opacity: _reduce ? const AlwaysStoppedAnimation(1.0) : _fade,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _block(
                t,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: t.textSubtle.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bar(t, 150, 15),
                            const SizedBox(height: 8),
                            _bar(t, 110, 10),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _bar(t, 62, 16)),
                        const SizedBox(width: 12),
                        Expanded(child: _bar(t, 62, 16)),
                        const SizedBox(width: 12),
                        Expanded(child: _bar(t, 62, 16)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _bar(t, 120, 12),
              const SizedBox(height: 10),
              for (var i = 0; i < 3; i++)
                _block(
                  t,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: t.textSubtle.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _bar(t, 110, 14),
                              const SizedBox(height: 7),
                              _bar(t, 70, 10),
                            ],
                          ),
                          const Spacer(),
                          _bar(t, 58, 18),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _bar(t, 60, 12),
                          const SizedBox(width: 14),
                          _bar(t, 60, 12),
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / error state ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: PulsColors.pulseGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sensors_off_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Agents unavailable',
                style: TextStyle(
                    color: t.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'The live pool could not be reached. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            Tactile(
              behavior: HitTestBehavior.opaque,
              hoverScale: 1.02,
              onTap: onRetry,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: PulsColors.pulseGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: PulsColors.neonGlow(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Try again',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Busy dialog ─────────────────────────────────────────────────────────────
class _BusyDialog extends StatelessWidget {
  const _BusyDialog({required this.title, required this.stage});
  final String title;
  final ValueNotifier<String> stage;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                gradient: PulsColors.pulseGradient,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: t.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ValueListenableBuilder<String>(
              valueListenable: stage,
              builder: (_, s, __) => Text(s,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: t.textMuted, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invest sheet ────────────────────────────────────────────────────────────
class _InvestSheet extends StatefulWidget {
  const _InvestSheet({
    required this.agent,
    required this.busy,
    required this.position,
    required this.onInvest,
    required this.onWithdraw,
  });

  final _Agent agent;
  final bool busy;
  final _Position? position;
  final ValueChanged<double> onInvest;
  final VoidCallback onWithdraw;

  @override
  State<_InvestSheet> createState() => _InvestSheetState();
}

class _InvestSheetState extends State<_InvestSheet> {
  static const _quickAmounts = [10.0, 50.0, 100.0];
  double _amount = 10;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final pos = widget.position;
    final apy = widget.agent.apyEstimatePct;
    final hasProfit = apy > 0;
    final projected = _amount * apy / 100;
    final fee = hasProfit ? projected * 0.20 : 0;
    final share = hasProfit ? projected - fee : 0;
    final apyLabel = apy == 0 ? 'n/a' : '${apy.toStringAsFixed(1)}%';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(widget.agent.glyph, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.agent.name,
                          style: TextStyle(
                              color: t.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4)),
                      Text('Pool ${_fmt(widget.agent.pool)} USDC · '
                          '$apyLabel APY',
                          style: TextStyle(
                              color: t.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _amount),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => CachedGradientMask(
                    gradient: PulsColors.pulseGradient,
                    child: Text(
                      '\$${v.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('USDC',
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 7,
                activeTrackColor: PulsColors.brandMint,
                inactiveTrackColor: t.surfaceRaised,
                thumbColor: Colors.white,
                overlayColor: PulsColors.brandPink.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                value: _amount.clamp(1, 1000),
                min: 1,
                max: 1000,
                onChanged: widget.busy
                    ? null
                    : (v) => setState(() => _amount = v.roundToDouble()),
              ),
            ),
            Row(
              children: [
                for (final q in _quickAmounts)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tactile(
                      onTap: widget.busy
                          ? null
                          : () => setState(() => _amount = q),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: (_amount - q).abs() < 0.5
                              ? t.brandSubtle
                              : t.surfaceRaised,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_amount - q).abs() < 0.5
                                ? t.brand
                                : t.border,
                          ),
                        ),
                        child: Text(
                          '\$${q.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: (_amount - q).abs() < 0.5
                                ? t.brand
                                : t.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  _row(t, 'Est. annual yield ($apyLabel est. APY)',
                      hasProfit
                          ? '\$${projected.toStringAsFixed(2)}'
                          : apy < 0
                              ? '−\$${projected.abs().toStringAsFixed(2)}'
                              : '\$0.00'),
                  _row(t, 'Agent performance fee (20%)',
                      '−\$${fee.toStringAsFixed(2)}'),
                  _row(t, 'Your share',
                      hasProfit ? '\$${share.toStringAsFixed(2)}' : '\$0.00',
                      strong: true),
                  if (!hasProfit)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          apy < 0
                              ? 'Agent is currently net-negative — no fee is charged, losses reduce principal.'
                              : 'No profit yet — the projection appears once the agent is net positive.',
                          style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 10.5,
                              height: 1.35),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Tactile(
              onTap: widget.busy ? null : () => widget.onInvest(_amount),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: PulsColors.pulseGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: PulsColors.brandPink.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Replenish ${widget.agent.name} with '
                      '${_fmt(_amount)} USDC',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pos != null) ...[
              const SizedBox(height: 10),
              Tactile(
                onTap: widget.busy ? null : widget.onWithdraw,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                  ),
                  child: Text(
                    'Withdraw claim \$${pos.claimable.toStringAsFixed(4)} USDC',
                    style: TextStyle(
                        color: t.brand,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v < 1 && v > 0 ? v.toStringAsFixed(4) : v.toStringAsFixed(2);

  Widget _row(PulsThemeColors t, String label, String value,
      {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Text(value,
              style: TextStyle(
                  color: strong ? t.brand : t.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: PulsColors.tabularFigures)),
        ],
      ),
    );
  }
}
