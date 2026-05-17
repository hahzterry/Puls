import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';

import '../../core/config.dart' show backendUrl;
const _backendUrl = backendUrl;

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Map<String, dynamic>> _positions = [];
  String _totalSpent = '0.00';
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final ws = WalletServiceScope.of(context).state;
    if (ws.userId == null) {
      setState(() { _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(
        Uri.parse('$_backendUrl/api/portfolio?userId=${ws.userId}'),
      );
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200) throw Exception(data['error']);
      setState(() {
        _positions = (data['positions'] as List).cast<Map<String, dynamic>>();
        _totalSpent = data['totalSpent'] as String? ?? '0.00';
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final ws = WalletServiceScope.of(context).state;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInDown(
                        duration: const Duration(milliseconds: 400),
                        child: Text('Portfolio',
                            style: Theme.of(context).textTheme.displaySmall),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        delay: const Duration(milliseconds: 80),
                        duration: const Duration(milliseconds: 400),
                        child: _HeroCard(
                          totalSpent: _totalSpent,
                          positionCount: _positions.where((p) => p['state'] == 'COMPLETE').length,
                          t: t,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text('Positions',
                              style: Theme.of(context).textTheme.titleLarge),
                          const Spacer(),
                          Text('${_positions.length} trades',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              if (ws.userId == null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _Empty(
                      icon: Icons.account_balance_wallet_outlined,
                      message: 'Sign in to see your portfolio',
                      sub: 'Connect your wallet in the Profile tab.',
                      t: t,
                    ),
                  ),
                )
              else if (_loading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _Empty(
                      icon: Icons.wifi_off_rounded,
                      message: 'Could not load portfolio',
                      sub: _error!,
                      t: t,
                    ),
                  ),
                )
              else if (_positions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _Empty(
                      icon: Icons.bar_chart_rounded,
                      message: 'No positions yet',
                      sub: 'Buy YES or NO on any prediction to get started.',
                      t: t,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList.builder(
                    itemCount: _positions.length,
                    itemBuilder: (context, i) => FadeInUp(
                      delay: Duration(milliseconds: 100 + i * 50),
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PositionCard(position: _positions[i], t: t),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalSpent,
    required this.positionCount,
    required this.t,
  });
  final String totalSpent;
  final int positionCount;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total invested',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('\$$totalSpent USDC',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1.1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$positionCount confirmed position${positionCount == 1 ? '' : 's'} · Arc Testnet',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position, required this.t});
  final Map<String, dynamic> position;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final isYes = position['side'] == 'YES';
    final sideBg = isYes ? PulsColors.greenLight : PulsColors.redLight;
    final sideFg = isYes ? PulsColors.green : PulsColors.red;
    final state = position['state'] as String? ?? 'UNKNOWN';
    final amount = (position['usdcAmount'] as num?)?.toDouble() ?? 0.0;
    final question = position['question'] as String? ?? 'Prediction';
    final txHash = position['txHash'] as String?;
    final timestamp = position['timestamp'] as String?;

    Color stateColor;
    String stateLabel;
    switch (state) {
      case 'COMPLETE':
        stateColor = PulsColors.green;
        stateLabel = 'Confirmed';
        break;
      case 'FAILED':
      case 'DENIED':
        stateColor = PulsColors.red;
        stateLabel = 'Failed';
        break;
      default:
        stateColor = PulsColors.amber;
        stateLabel = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
              const Spacer(),
              Text('\$${amount.toStringAsFixed(2)} USDC',
                  style: TextStyle(
                      color: t.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(question,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (txHash != null || timestamp != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (timestamp != null)
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(color: t.textSubtle, fontSize: 11),
                  ),
                const Spacer(),
                if (txHash != null)
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://testnet.arcscan.app/tx/$txHash'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${txHash.substring(0, 8)}...${txHash.substring(txHash.length - 6)}',
                          style: TextStyle(color: t.brand, fontSize: 11),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.open_in_new_rounded, size: 11, color: t.brand),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.message,
    required this.sub,
    required this.t,
  });
  final IconData icon;
  final String message;
  final String sub;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: t.textSubtle, size: 32),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(sub,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
