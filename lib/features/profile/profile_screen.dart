import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../wallet/wallet_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    // Auto-refresh balance when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WalletServiceScope.of(context).refreshBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final wallet = WalletServiceScope.of(context);
    final t = context.puls;
    final isDark = appState.themeMode == ThemeMode.dark;
    final ws = wallet.state;
    final supaUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: wallet.refreshBalance,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Text('Profile',
                      style: Theme.of(context).textTheme.displaySmall),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Wallet card ──────────────────────────────────────────────────
            FadeInUp(
              delay: const Duration(milliseconds: 60),
              duration: const Duration(milliseconds: 400),
              child: _WalletCard(ws: ws, wallet: wallet, t: t),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              delay: const Duration(milliseconds: 80),
              duration: const Duration(milliseconds: 400),
              child: _ProfileCard(t: t, supaUser: supaUser),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 140),
              duration: const Duration(milliseconds: 400),
              child: _Section(
                title: 'Appearance',
                t: t,
                children: [
                  _Row(
                    icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    title: 'Dark mode',
                    subtitle: isDark ? 'Currently dark' : 'Currently light',
                    t: t,
                    trailing: Switch(
                      value: isDark,
                      activeTrackColor: t.brand,
                      onChanged: (_) => appState.toggleThemeMode(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 160),
              duration: const Duration(milliseconds: 400),
              child: _FastBuySection(appState: appState, t: t),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 180),
              duration: const Duration(milliseconds: 400),
              child: _Section(
                title: 'Arc Testnet',
                t: t,
                children: [
                  _Row(
                    icon: Icons.water_drop_outlined,
                    title: 'Get testnet USDC',
                    subtitle: 'faucet.circle.com → Arc Testnet',
                    t: t,
                    onTap: () => launchUrl(
                      Uri.parse('https://faucet.circle.com'),
                      mode: LaunchMode.externalApplication,
                    ),
                    trailing: Icon(Icons.open_in_new_rounded, size: 16, color: t.textSubtle),
                  ),
                  _Row(
                    icon: Icons.search_rounded,
                    title: 'Arc Explorer',
                    subtitle: 'testnet.arcscan.app',
                    t: t,
                    onTap: () => launchUrl(
                      Uri.parse('https://testnet.arcscan.app'),
                      mode: LaunchMode.externalApplication,
                    ),
                    trailing: Icon(Icons.open_in_new_rounded, size: 16, color: t.textSubtle),
                  ),
                  _Row(
                    icon: Icons.info_outline_rounded,
                    title: 'Market contract',
                    subtitle: '0xca048d...20dB',
                    t: t,
                    onTap: () => launchUrl(
                      Uri.parse('https://testnet.arcscan.app/address/0xca048d69BaA38C6364d3E107c2b389BB8D1320dB'),
                      mode: LaunchMode.externalApplication,
                    ),
                    trailing: Icon(Icons.open_in_new_rounded, size: 16, color: t.textSubtle),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FadeInUp(
              delay: const Duration(milliseconds: 220),
              duration: const Duration(milliseconds: 400),
              child: _Section(
                title: 'About',
                t: t,
                children: [
                  _Row(
                    icon: Icons.layers_rounded,
                    title: 'Built on Arc',
                    subtitle: 'USDC-native L1 · Chain ID 5042002',
                    t: t,
                    onTap: () => launchUrl(
                      Uri.parse('https://arc.network'),
                      mode: LaunchMode.externalApplication,
                    ),
                    trailing: Icon(Icons.open_in_new_rounded, size: 16, color: t.textSubtle),
                  ),
                  _Row(
                    icon: Icons.account_balance_rounded,
                    title: 'Powered by Circle',
                    subtitle: 'MPC wallets · USDC payments',
                    t: t,
                    onTap: () => launchUrl(
                      Uri.parse('https://circle.com'),
                      mode: LaunchMode.externalApplication,
                    ),
                    trailing: Icon(Icons.open_in_new_rounded, size: 16, color: t.textSubtle),
                  ),
                  _Row(
                    icon: Icons.show_chart_rounded,
                    title: 'Market data',
                    subtitle: 'Polymarket · Real odds',
                    t: t,
                    onTap: () => launchUrl(
                      Uri.parse('https://polymarket.com'),
                      mode: LaunchMode.externalApplication,
                    ),
                    trailing: Icon(Icons.open_in_new_rounded, size: 16, color: t.textSubtle),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.t, this.supaUser});
  final PulsThemeColors t;
  final dynamic supaUser;

  @override
  Widget build(BuildContext context) {
    final name = (supaUser?.userMetadata?['full_name']
            ?? supaUser?.userMetadata?['name']
            ?? 'Puls Trader') as String;
    final email = (supaUser?.email ?? '@puls_demo') as String;
    final avatarUrl = supaUser?.userMetadata?['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: avatarUrl != null
                ? Image.network(avatarUrl, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(name))
                : _fallback(name),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(email, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          supaUser != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: PulsColors.greenLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Connected',
                      style: TextStyle(
                          color: PulsColors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: PulsColors.amberLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('DEMO',
                      style: TextStyle(
                          color: PulsColors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
        ],
      ),
    );
  }

  Widget _fallback(String name) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: t.brandSubtle, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/logo.png',
          fit: BoxFit.cover,
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.t,
    required this.children,
  });
  final String title;
  final PulsThemeColors t;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                      color: t.textSubtle,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.t,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final PulsThemeColors t;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.border),
            ),
            child: Icon(icon, color: t.textMuted, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right_rounded,
                  color: onTap != null ? t.textSubtle : Colors.transparent, size: 16),
        ],
      ),
    ),
    );
  }
}


// ── Wallet Card ───────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.ws,
    required this.wallet,
    required this.t,
  });

  final WalletState ws;
  final WalletService wallet;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    if (ws.userId == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: t.brand,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connect Wallet',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in with Google to get a USDC wallet on Arc Testnet',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: ws.isLoading ? null : wallet.signInWithGoogle,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: t.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: ws.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue with Google',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            if (ws.error != null) ...[
              const SizedBox(height: 8),
              Text(ws.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      );
    }

    // Signed in — show balance
    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 36,
                height: 36,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arc Testnet Wallet',
                        style: TextStyle(
                            color: t.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (ws.walletAddress != null && ws.walletAddress!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: ws.walletAddress!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Wallet address copied!')),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}',
                              style: TextStyle(color: t.textMuted, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 12, color: t.textSubtle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: ws.isLoading ? null : wallet.refreshBalance,
                child: ws.isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: t.brand),
                      )
                    : Icon(Icons.refresh_rounded, color: t.textSubtle, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USDC Balance',
                      style: TextStyle(color: t.textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '\$${double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance} USDC',
                    style: TextStyle(
                        color: t.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        letterSpacing: -0.5),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: PulsColors.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Arc Testnet',
                  style: TextStyle(
                      color: PulsColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Get testnet USDC: faucet.circle.com',
            style: TextStyle(color: t.textSubtle, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showWalletInfo(context, ws, wallet, t),
                icon: Icon(Icons.info_outline_rounded, size: 14, color: t.brand),
                label: Text('Wallet info', style: TextStyle(color: t.brand, fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: wallet.signOut,
                style: TextButton.styleFrom(
                  foregroundColor: PulsColors.red,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Sign out', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWalletInfo(BuildContext context, WalletState ws, WalletService wallet, PulsThemeColors t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Wallet Info', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoRow('Network', 'Arc Testnet', t),
            _InfoRow('Chain ID', '5042002', t),
            _InfoRow('Balance', '\$${double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance} USDC', t),
            if (ws.walletAddress != null) ...[
              const SizedBox(height: 8),
              Text('Address', style: TextStyle(color: t.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: ws.walletAddress!));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(ws.walletAddress!,
                            style: TextStyle(color: t.text, fontSize: 12, fontFamily: 'monospace')),
                      ),
                      Icon(Icons.copy_rounded, size: 16, color: t.brand),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PulsColors.amberLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: PulsColors.amber, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a Circle MPC wallet. Private key is secured by Circle\'s infrastructure and cannot be exported.',
                      style: const TextStyle(color: PulsColors.amber, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, this.t);
  final String label;
  final String value;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: t.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _FastBuySection extends StatelessWidget {
  const _FastBuySection({required this.appState, required this.t});
  final PulsAppState appState;
  final PulsThemeColors t;

  static const _amounts = [0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appState.fastBuyEnabled
              ? t.brand.withValues(alpha: 0.4)
              : t.border,
        ),
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appState.fastBuyEnabled
                      ? t.brand
                      : t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: appState.fastBuyEnabled ? Colors.white : t.textMuted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fast Buy',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      appState.fastBuyEnabled
                          ? 'Swipe to buy instantly · \$${appState.fastBuyAmount.toStringAsFixed(appState.fastBuyAmount % 1 == 0 ? 0 : 1)} USDC'
                          : 'Swipe left/right to buy without confirmation',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Switch(
                value: appState.fastBuyEnabled,
                activeTrackColor: t.brand,
                onChanged: (_) => appState.toggleFastBuy(),
              ),
            ],
          ),
          if (appState.fastBuyEnabled) ...[
            const SizedBox(height: 14),
            Text('Auto-buy amount',
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: _amounts.map((amt) {
                final selected = appState.fastBuyAmount == amt;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => appState.setFastBuyAmount(amt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? t.brand : t.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? t.brand : t.border,
                        ),
                      ),
                      child: Text(
                        '\$${amt.toStringAsFixed(amt % 1 == 0 ? 0 : 1)}',
                        style: TextStyle(
                          color: selected ? Colors.white : t.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.brandSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.swipe_rounded, color: t.brand, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Swipe right = YES · Swipe left = NO · No confirmation',
                    style: TextStyle(
                        color: t.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
