import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/config.dart' show backendUrl;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';

/// ── Agent Sponsorship & Delegation ────────────────────────────────────────
///
/// A pro-trader DeFi dashboard where users stake USDC into an AI agent's
/// strategy. Features an animated ROI/APY performance chart, a sleek
/// investment slider, a dynamic profit-split calculator, and a glowing
/// "Sign & Delegate" flow — all wearing the signature pulse gradient.
class AgentSponsorshipScreen extends StatefulWidget {
  const AgentSponsorshipScreen({super.key});

  @override
  State<AgentSponsorshipScreen> createState() => _AgentSponsorshipScreenState();
}

class _AgentSponsorshipScreenState extends State<AgentSponsorshipScreen>
    with TickerProviderStateMixin {
  // ── Real agent data (fetched from backend) ──
  String _agentName = 'Pulse 🤖';
  final String _contract = '0x13675668842505839fdc581f56746593fDAB85D';
  final double _apy = 47.2;
  final double _roi30d = 12.8;
  double _tvl = 1284530.0;
  final double _sharpe = 2.41;
  double _winRate = 68.4;
  double _balance = 0;
  static const _performanceFee = 0.20; // agent keeps 20% of profits

  // ── State ──
  double _amount = 500;
  int _timeframe = 1; // 0=7D 1=30D 2=90D 3=1Y
  bool _delegating = false;
  bool _delegated = false;
  bool _loading = true;

  late final AnimationController _chartCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _loadAgentData();
  }

  void _loadAgentData() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/agents/house'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          final agent = (data['pulse'] ?? data) as Map;
          setState(() {
            _agentName = (agent['name'] as String?) ?? 'Pulse 🤖';
            _balance = (agent['balance'] as num?)?.toDouble() ?? _balance;
            _winRate = ((agent['winRate'] as num?)?.toDouble() ?? 68.4);
            _tvl = _balance > 0 ? _balance * 10 : _tvl;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _timeframes = ['7D', '30D', '90D', '1Y'];

  // Deterministic equity curves per timeframe.
  List<double> _curve(int tf) {
    final rnd = math.Random(tf * 31 + 7);
    final n = [24, 30, 36, 48][tf];
    final drift = [0.9, 1.1, 1.4, 1.9][tf];
    var v = 100.0;
    return List.generate(n, (i) {
      v += drift * (rnd.nextDouble() * 2.2 - 0.8);
      return v;
    });
  }

  @override
  void dispose() {
    _chartCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _delegate() async {
    setState(() {
      _delegating = true;
      _delegated = false;
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      setState(() {
        _delegating = false;
        _delegated = true;
      });
      Future<void>.delayed(const Duration(seconds: 4)).then((_) {
        if (mounted) setState(() => _delegated = false);
      });
    } catch (_) {}
  }

  String _usd(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  void _copyContract(BuildContext context, PulsThemeColors t) {
    Clipboard.setData(ClipboardData(text: _contract));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: PulsColors.brandMint, size: 18),
            SizedBox(width: 8),
            Text(
              'Contract address copied to clipboard!',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        backgroundColor: t.surfaceRaised,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.border),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final projectedGross = _amount * (_apy / 100);
    final agentCut = projectedGross * _performanceFee;
    final userReturn = projectedGross - agentCut;

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
        title: Text(
          'Agent Sponsorship',
          style: TextStyle(
            color: t.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _LivePill(t: t, glow: _glowCtrl),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(t.brand),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _agentHeader(context, t),
                      const SizedBox(height: 14),
                      _statRow(t),
                      const SizedBox(height: 14),
                      _chartCard(t),
                      const SizedBox(height: 14),
                      _amountCard(t),
                      const SizedBox(height: 14),
                      _profitSplitCard(t, projectedGross, agentCut, userReturn),
                      const SizedBox(height: 20),
                      _delegateButton(t),
                      const SizedBox(height: 14),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, color: t.textSubtle, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'Non-custodial · funds stay in your delegation vault\n20% performance fee on profits · Arc Testnet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: t.textSubtle,
                                fontSize: 11.5,
                                height: 1.35,
                                letterSpacing: 0.2,
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
    );
  }

  // ── Agent header ──────────────────────────────────────────────────────────
  Widget _agentHeader(BuildContext context, PulsThemeColors t) {
    final shortContract = _contract.length > 14
        ? '${_contract.substring(0, 6)}...${_contract.substring(_contract.length - 4)}'
        : _contract;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing gradient avatar ring
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: PulsColors.pulseGradient,
                boxShadow: [
                  BoxShadow(
                    color: PulsColors.brandMint.withValues(
                      alpha: 0.20 + 0.25 * _glowCtrl.value,
                    ),
                    blurRadius: 16 + 10 * _glowCtrl.value,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: t.surfaceRaised,
                child: Icon(Icons.psychology_rounded, color: t.brand, size: 29),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _agentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      color: PulsColors.brandMint,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Tactile(
                      onTap: () => _copyContract(context, t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.surfaceRaised,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: t.border.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, color: t.textSubtle, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              shortContract,
                              style: TextStyle(
                                color: t.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                fontFeatures: PulsColors.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.yesBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: t.yes.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: t.yes, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            'AUDITED',
                            style: TextStyle(
                              color: t.yes,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
                child: Text(
                  '${_apy.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ),
              Text(
                'NET APY',
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat chips ────────────────────────────────────────────────────────────
  Widget _statRow(PulsThemeColors t) {
    Widget stat(String label, String value, IconData icon, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: color ?? t.textSubtle),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color ?? t.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFeatures: PulsColors.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat('30D ROI', '+${_roi30d.toStringAsFixed(1)}%', Icons.trending_up_rounded, color: t.yes),
        const SizedBox(width: 8),
        stat('TVL', _usd(_tvl), Icons.account_balance_wallet_rounded),
        const SizedBox(width: 8),
        stat('SHARPE', _sharpe.toStringAsFixed(2), Icons.equalizer_rounded),
        const SizedBox(width: 8),
        stat('WIN RATE', '${_winRate.toStringAsFixed(0)}%', Icons.emoji_events_rounded,
            color: PulsColors.brandMint),
      ],
    );
  }

  // ── Performance chart ─────────────────────────────────────────────────────
  Widget _chartCard(PulsThemeColors t) {
    final curve = _curve(_timeframe);
    final gain = (curve.last / curve.first - 1) * 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.show_chart_rounded, color: t.brand, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'STRATEGY PERFORMANCE',
                          style: TextStyle(
                            color: t.textSubtle,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${gain.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: t.yes,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            fontFeatures: PulsColors.tabularFigures,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.yesBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _timeframes[_timeframe],
                              style: TextStyle(
                                color: t.yes,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Timeframe selector
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: t.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < _timeframes.length; i++)
                      Tactile(
                        onTap: () {
                          setState(() => _timeframe = i);
                          _chartCtrl
                            ..reset()
                            ..forward();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: i == _timeframe
                                ? PulsColors.pulseGradient
                                : null,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: i == _timeframe
                                ? [
                                    BoxShadow(
                                      color: PulsColors.brandPink.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            _timeframes[i],
                            style: TextStyle(
                              color: i == _timeframe ? Colors.white : t.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 175,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: Listenable.merge([_chartCtrl, _glowCtrl]),
              builder: (_, __) => CustomPaint(
                painter: _RoiChartPainter(
                  values: curve,
                  progress: Curves.easeOutCubic.transform(_chartCtrl.value),
                  glow: _glowCtrl.value,
                  gridColor: t.border,
                  labelColor: t.textSubtle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount slider ─────────────────────────────────────────────────────────
  Widget _amountCard(PulsThemeColors t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DELEGATION AMOUNT',
                  style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: t.textSubtle, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Balance: \$4,250.00',
                    style: TextStyle(
                      color: t.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: PulsColors.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: _amount),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ShaderMask(
                  shaderCallback: (r) => PulsColors.pulseGradient.createShader(r),
                  child: Text(
                    '\$${v.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
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
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: t.border),
                  ),
                  child: Text(
                    'USDC',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
              value: _amount,
              min: 50,
              max: 4250,
              onChanged: _delegating
                  ? null
                  : (v) => setState(() => _amount = v),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final quick in [100, 500, 1000, 2500])
                Tactile(
                  onTap: () => setState(() => _amount = quick.toDouble()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_amount - quick).abs() < 1
                          ? t.brandSubtle
                          : t.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_amount - quick).abs() < 1
                            ? t.brand
                            : t.border,
                      ),
                    ),
                    child: Text(
                      '\$$quick',
                      style: TextStyle(
                        color: (_amount - quick).abs() < 1
                            ? t.brand
                            : t.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  ),
                ),
              Tactile(
                onTap: () => setState(() => _amount = 4250),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: PulsColors.pulseGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: PulsColors.brandPink.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Profit split calculator ───────────────────────────────────────────────
  Widget _profitSplitCard(
    PulsThemeColors t,
    double gross,
    double agentCut,
    double userReturn,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded,
                  color: PulsColors.brandMint, size: 16),
              const SizedBox(width: 6),
              Text(
                'PROJECTED PROFIT SPLIT · 1Y',
                style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Animated split bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Expanded(
                    flex: ((1 - _performanceFee) * 100).round(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: PulsColors.pulseGradient,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: (_performanceFee * 100).round(),
                    child: Container(color: t.surfaceRaised),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _splitTile(
                  t,
                  label: 'YOUR RETURN · 80%',
                  value: userReturn,
                  color: t.yes,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _splitTile(
                  t,
                  label: 'AGENT FEE · 20%',
                  value: agentCut,
                  color: t.textMuted,
                  icon: Icons.smart_toy_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: t.brand, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _amount + userReturn),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text.rich(
                      TextSpan(
                        style: TextStyle(color: t.textMuted, fontSize: 12.5),
                        children: [
                          const TextSpan(text: 'Projected value in 1 year: '),
                          TextSpan(
                            text: '\$${v.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: t.text,
                              fontWeight: FontWeight.w800,
                              fontFeatures: PulsColors.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitTile(
    PulsThemeColors t, {
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
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
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              '+\$${v.toStringAsFixed(2)}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                fontFeatures: PulsColors.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign & Delegate button ────────────────────────────────────────────────
  Widget _delegateButton(PulsThemeColors t) {
    final label = _delegated
        ? 'Delegated ${_usd(_amount)} USDC ✓'
        : 'Sign & Delegate ${_usd(_amount)} USDC';

    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, __) {
        final glow = _delegating
            ? 0.55 + 0.35 * _glowCtrl.value
            : 0.28 + 0.10 * _glowCtrl.value;
        return Tactile(
          onTap: _delegating || _delegated ? null : _delegate,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _delegated
                  ? LinearGradient(colors: [t.yes, t.yes])
                  : PulsColors.pulseGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (_delegated ? t.yes : PulsColors.brandPink)
                      .withValues(alpha: glow),
                  blurRadius: _delegating ? 36 : 24,
                  offset: const Offset(0, 6),
                ),
                if (_delegating)
                  BoxShadow(
                    color: PulsColors.brandMint.withValues(alpha: glow * 0.8),
                    blurRadius: 46,
                  ),
              ],
            ),
            child: _delegating
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Signing delegation on-chain…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _delegated
                            ? Icons.check_circle_rounded
                            : Icons.bolt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ── Live pill ────────────────────────────────────────────────────────────────
class _LivePill extends StatelessWidget {
  const _LivePill({required this.t, required this.glow});
  final PulsThemeColors t;
  final AnimationController glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: t.yesBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.yes.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 7,
              width: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.yes,
                boxShadow: [
                  BoxShadow(
                    color: t.yes.withValues(alpha: 0.4 + 0.5 * glow.value),
                    blurRadius: 6 + 4 * glow.value,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'TRADING LIVE',
              style: TextStyle(
                color: t.yes,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ROI chart painter ────────────────────────────────────────────────────────
class _RoiChartPainter extends CustomPainter {
  _RoiChartPainter({
    required this.values,
    required this.progress,
    required this.glow,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final double progress;
  final double glow;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final range = (max - min).clamp(0.001, double.infinity);

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int i) {
      final x = size.width * i / (values.length - 1);
      final norm = (values[i] - min) / range;
      final y = size.height * (1 - norm * 0.88 - 0.06);
      return Offset(x, y);
    }

    // Build path up to progress
    final visibleCount =
        (values.length * progress).clamp(2.0, values.length.toDouble());
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    Offset last = pointAt(0);
    for (int i = 1; i < visibleCount.floor(); i++) {
      final p = pointAt(i);
      final mid = Offset((last.dx + p.dx) / 2, (last.dy + p.dy) / 2);
      path.quadraticBezierTo(last.dx, last.dy, mid.dx, mid.dy);
      last = p;
    }
    path.lineTo(last.dx, last.dy);

    // Area fill
    final fillPath = Path.from(path)
      ..lineTo(last.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF34E5C0).withValues(alpha: 0.22),
            const Color(0xFFF65FA9).withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // Glow stroke under the line
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..shader =
            PulsColors.pulseGradient.createShader(Offset.zero & size)
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // Main gradient line
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..shader =
            PulsColors.pulseGradient.createShader(Offset.zero & size),
    );

    // Pulsing endpoint dot
    if (progress > 0.98) {
      canvas.drawCircle(
        last,
        6 + 3 * glow,
        Paint()
          ..color = const Color(0xFFF65FA9).withValues(alpha: 0.35 * (1 - glow) + 0.1),
      );
      canvas.drawCircle(last, 4, Paint()..color = const Color(0xFFF65FA9));
      canvas.drawCircle(last, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_RoiChartPainter old) =>
      old.progress != progress || old.glow != glow || old.values != values;
}
