import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../wallet/wallet_service.dart';
import '../shell/web_layout.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = WalletServiceScope.of(context);
      wallet.refreshBalance();
      if (wallet.state.userId != null && (wallet.state.walletAddress == null || wallet.state.walletAddress!.isEmpty)) {
        wallet.reloadWallet();
      }
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

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = kIsWeb && width >= 900;

    Widget body;
    if (isDesktop) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Profile Card + Wallet Control Panel
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileCard(t: t, supaUser: supaUser),
                    const SizedBox(height: 20),
                    _WalletCard(ws: ws, wallet: wallet, t: t),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Preferences, Arc Testnet details, About L1/Circle
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: 'Preferences',
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
                    const SizedBox(height: 16),
                    _FastBuySection(appState: appState, t: t),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Arc Testnet Operations',
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
                          trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
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
                          trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
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
                          trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      title: 'Platform Architecture',
                      t: t,
                      children: [
                        _Row(
                          icon: Icons.layers_rounded,
                          title: 'Built on Arc L1',
                          subtitle: 'USDC-native gas · L1 ecosystem',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://arc.network'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.account_balance_rounded,
                          title: 'Powered by Circle SDKs',
                          subtitle: 'Non-custodial MPC wallets · USDC rails',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://circle.com'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
                        ),
                        _Row(
                          icon: Icons.show_chart_rounded,
                          title: 'Market data',
                          subtitle: 'Polymarket odds engine',
                          t: t,
                          onTap: () => launchUrl(
                            Uri.parse('https://polymarket.com'),
                            mode: LaunchMode.externalApplication,
                          ),
                          trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          FadeInUp(
            delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 350),
            child: _ProfileCard(t: t, supaUser: supaUser),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            duration: const Duration(milliseconds: 350),
            child: _WalletCard(ws: ws, wallet: wallet, t: t),
          ),
          const SizedBox(height: 16),
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            duration: const Duration(milliseconds: 350),
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
            delay: const Duration(milliseconds: 120),
            duration: const Duration(milliseconds: 350),
            child: _FastBuySection(appState: appState, t: t),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 140),
            duration: const Duration(milliseconds: 350),
            child: _Section(
              title: 'Arc Testnet',
              t: t,
              children: [
                _Row(
                  icon: Icons.water_drop_outlined,
                  title: 'Get testnet USDC',
                  subtitle: 'faucet.circle.com',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://faucet.circle.com'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
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
                  trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
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
                  trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 160),
            duration: const Duration(milliseconds: 350),
            child: _Section(
              title: 'About',
              t: t,
              children: [
                _Row(
                  icon: Icons.layers_rounded,
                  title: 'Built on Arc',
                  subtitle: 'USDC-native gas · L1 L2 ecosystem',
                  t: t,
                  onTap: () => launchUrl(
                    Uri.parse('https://arc.network'),
                    mode: LaunchMode.externalApplication,
                  ),
                  trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
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
                  trailing: Icon(Icons.open_in_new_rounded, size: 14, color: t.textSubtle),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text('Profile Settings', style: TextStyle(color: t.text, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: t.brand,
          onRefresh: wallet.refreshBalance,
          child: isDesktop ? WebLayout(maxWidth: 1200, child: body) : body,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                Text(name, style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: t.textMuted, fontSize: 13)),
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
                          fontWeight: FontWeight.bold)),
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
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
        ],
      ),
    );
  }

  Widget _fallback(String name) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: t.brandSubtle, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: TextStyle(color: t.brand, fontSize: 20, fontWeight: FontWeight.bold),
          ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  color: t.textSubtle,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: Icon(icon, color: t.textMuted, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: t.textMuted, fontSize: 12)),
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
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: t.brand,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: t.brand.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Onchain Trading Wallet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create an automated secure USDC trading account on Arc Testnet',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.3),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: ws.isLoading ? null : wallet.signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: t.brand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: ws.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Connect Google Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                  ),
                ),
                if (ws.error != null) ...[
                  const SizedBox(height: 10),
                  Text(ws.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(Icons.account_balance_wallet_rounded, color: t.brand, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arc Testnet Wallet', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 14)),
                    if (ws.walletAddress != null && ws.walletAddress!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: ws.walletAddress!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}',
                              style: TextStyle(color: t.textMuted, fontSize: 12, decoration: TextDecoration.underline),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 12, color: t.textSubtle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: ws.isLoading ? null : wallet.refreshBalance,
                icon: ws.isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded, color: t.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USDC Balance', style: TextStyle(color: t.textMuted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '\$${double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance} USDC',
                    style: TextStyle(color: t.text, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PulsColors.greenLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Arc L1 Testnet',
                  style: TextStyle(color: PulsColors.green, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ws.walletAddress != null && ws.walletAddress!.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: ws.walletAddress!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied to clipboard'), duration: Duration(seconds: 2)),
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
                      child: Text(
                        ws.walletAddress!,
                        style: TextStyle(color: t.textMuted, fontSize: 11, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 14, color: t.brand),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if ((double.tryParse(ws.usdcBalance) ?? 0) == 0)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://faucet.circle.com'), mode: LaunchMode.externalApplication),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PulsColors.amberLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PulsColors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.water_drop_rounded, size: 16, color: PulsColors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Wallet is empty. Click here to get free gas + testnet USDC from faucet.circle.com →',
                        style: TextStyle(color: PulsColors.amber, fontSize: 12, fontWeight: FontWeight.bold, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: Text(
                'Top up gas / USDC anytime at faucet.circle.com (select Arc Testnet network)',
                style: TextStyle(color: t.textSubtle, fontSize: 11, height: 1.3),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showWalletInfo(context, ws, wallet, t),
                icon: Icon(Icons.info_outline_rounded, size: 14, color: t.brand),
                label: Text('Diagnostic Info', style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
              const Spacer(),
              TextButton(
                onPressed: wallet.signOut,
                style: TextButton.styleFrom(foregroundColor: PulsColors.red, padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text('Disconnect Wallet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            Text('Technical Details', style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _InfoRow('Target Network', 'Arc Testnet L1', t),
            _InfoRow('Chain ID', '5042002', t),
            _InfoRow('Gas Fee Asset', 'USDC (Native gas)', t),
            _InfoRow('Provider type', 'Circle Programmable Wallet (MPC)', t),
            if (ws.walletAddress != null) ...[
              const SizedBox(height: 12),
              Text('Full Wallet Hex Address', style: TextStyle(color: t.textMuted, fontSize: 12)),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: t.textMuted, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 13)),
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
      padding: const EdgeInsets.all(18),
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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
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
                width: 38,
                height: 38,
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
                    Text('Fast Buy Console',
                        style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      appState.fastBuyEnabled
                          ? 'Swipe to trade instantly · \$${appState.fastBuyAmount.toStringAsFixed(appState.fastBuyAmount % 1 == 0 ? 0 : 1)} USDC'
                          : 'Skip confirmations & trade with swipe actions',
                      style: TextStyle(color: t.textMuted, fontSize: 12),
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
            Text('Auto-buy Amount limit',
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: _amounts.map((amt) {
                final selected = appState.fastBuyAmount == amt;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => appState.setFastBuyAmount(amt),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
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
                  Expanded(
                    child: Text(
                      'Swipe Right = Buy YES · Swipe Left = Buy NO (Instantly executes)',
                      style: TextStyle(
                          color: t.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
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
