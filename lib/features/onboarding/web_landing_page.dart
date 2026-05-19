import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app_state.dart';

// ── Brand palette (matches app theme) ────────────────────────────────────────
const _bg = Color(0xFF09090B);
const _surface = Color(0xFF18181B);
const _surfaceRaised = Color(0xFF27272A);
const _border = Color(0xFF3F3F46);
const _brand = Color(0xFF4F46E5);
const _brandSubtle = Color(0xFF1E1B4B);
const _white = Color(0xFFFAFAFA);
const _muted = Color(0xFFA1A1AA);
const _subtle = Color(0xFF71717A);
const _green = Color(0xFF16A34A);

class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  final _scrollCtrl = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollCtrl.offset);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        child: Column(
          children: [
            _HeroSection(scrollOffset: _scrollOffset),
            const _FeaturesSection(),
            const _HowItWorksSection(),
            const _StatsSection(),
            const _FooterSection(),
          ],
        ),
      ),
    );
  }
}

// ── Navbar ────────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  const _Navbar();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: _border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _brandSubtle, borderRadius: BorderRadius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          const Text('Puls',
              style: TextStyle(color: _white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const Spacer(),
          _NavLink('GitHub', 'https://github.com/rdmbtc/Puls'),
          const SizedBox(width: 8),
          _NavLink('Explorer', 'https://testnet.arcscan.app/address/0xca048d69BaA38C6364d3E107c2b389BB8D1320dB'),
          const SizedBox(width: 16),
          _PrimaryButton(
            label: 'Launch App',
            onTap: appState.completeOnboarding,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink(this.label, this.url);
  final String label;
  final String url;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(widget.label,
              style: TextStyle(
                color: _hovered ? _white : _muted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              )),
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.scrollOffset});
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final parallaxY = -(scrollOffset * 0.25).clamp(0.0, h * 0.3);
    final heroOpacity = (1 - scrollOffset / (h * 0.6)).clamp(0.0, 1.0);

    return SizedBox(
      height: h,
      child: Stack(
        children: [
          // Radial glow behind hero
          Positioned(
            top: h * 0.1, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 600, height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _brand.withValues(alpha: 0.15),
                      blurRadius: 200,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Navbar
          const Positioned(top: 0, left: 0, right: 0, child: _Navbar()),
          // Hero content with parallax
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, parallaxY),
              child: Opacity(
                opacity: heroOpacity,
                child: const _HeroContent(),
              ),
            ),
          ),
          // Bottom fade
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_bg, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _brandSubtle,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _brand.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(color: _brand, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('Live on Arc Testnet · Chain ID 5042002',
                  style: TextStyle(color: _brand, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
        const SizedBox(height: 28),
        // Title
        const Text(
          'Predict Markets.\nSwipe YES or NO.\nWin USDC.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _white,
            fontSize: 68,
            fontWeight: FontWeight.w700,
            height: 1.08,
            letterSpacing: -2.5,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.2, delay: 100.ms),
        const SizedBox(height: 20),
        // Subtitle
        const Text(
          'Real Polymarket predictions. Real USDC on-chain.\nNo ETH, no seed phrase — just Google sign-in.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 18, height: 1.6, fontWeight: FontWeight.w400),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.2, delay: 200.ms),
        const SizedBox(height: 36),
        // CTAs
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PrimaryButton(label: 'Launch App', onTap: appState.completeOnboarding)
                .animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(begin: 0.2, delay: 300.ms),
            const SizedBox(width: 12),
            _SecondaryButton(
              label: 'View Contract ↗',
              onTap: () => launchUrl(
                Uri.parse('https://testnet.arcscan.app/address/0xca048d69BaA38C6364d3E107c2b389BB8D1320dB'),
                mode: LaunchMode.externalApplication,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 350.ms).slideY(begin: 0.2, delay: 350.ms),
          ],
        ),
        const SizedBox(height: 48),
        // Live stats strip
        _LiveStatsStrip()
            .animate().fadeIn(duration: 600.ms, delay: 500.ms),
      ],
    );
  }
}

class _LiveStatsStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatChip(icon: Icons.bolt_rounded, label: '100 Live Markets', color: _brand),
          _Divider(),
          _StatChip(icon: Icons.account_balance_wallet_rounded, label: 'Circle MPC Wallets', color: _green),
          _Divider(),
          _StatChip(icon: Icons.speed_rounded, label: 'Sub-second Finality', color: Color(0xFFD97706)),
          _Divider(),
          _StatChip(icon: Icons.water_drop_rounded, label: 'USDC Gas Token', color: Color(0xFF0EA5E9)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: _border,
    );
  }
}


// ── Features Section ──────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _features = [
    _Feature(
      icon: Icons.swipe_rounded,
      color: Color(0xFF4F46E5),
      title: 'Swipe to Trade',
      body: 'Swipe right for YES, left for NO. Buy any Polymarket prediction in under a second — no confirmation modal.',
    ),
    _Feature(
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF16A34A),
      title: 'Instant MPC Wallet',
      body: 'Sign in with Google and get a Circle MPC wallet on Arc Testnet automatically. No seed phrase, no setup.',
    ),
    _Feature(
      icon: Icons.show_chart_rounded,
      color: Color(0xFF0EA5E9),
      title: 'Real Polymarket Data',
      body: '100 live markets from Polymarket with real odds, sparkline charts, bid/ask spread, and 24h volume.',
    ),
    _Feature(
      icon: Icons.water_drop_rounded,
      color: Color(0xFFD97706),
      title: 'USDC — No ETH Needed',
      body: 'Arc Testnet uses USDC as the native gas token. Pay fees in USDC. No ETH, no bridging, no friction.',
    ),
    _Feature(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFEC4899),
      title: 'Portfolio & PNL',
      body: 'Track every trade with entry price, current price, and real-time PNL. View transactions on Arc Explorer.',
    ),
    _Feature(
      icon: Icons.play_circle_rounded,
      color: Color(0xFF8B5CF6),
      title: 'TikTok-style Feed',
      body: 'Vertical video feed with prediction pills. Swipe through content and lock in your prediction without leaving.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _brandSubtle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _brand.withValues(alpha: 0.3)),
            ),
            child: const Text('FEATURES', style: TextStyle(color: _brand, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 16),
          const Text('Everything you need to trade predictions',
              textAlign: TextAlign.center,
              style: TextStyle(color: _white, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.2)),
          const SizedBox(height: 12),
          const Text('Built on Circle\'s full-stack: MPC wallets, USDC, Arc Testnet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 16, height: 1.6)),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _features.map((f) => SizedBox(
                width: (constraints.maxWidth - (cols - 1) * 16) / cols,
                child: _FeatureCard(feature: f),
              )).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovered ? _surfaceRaised : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? f.color.withValues(alpha: 0.4) : _border),
          boxShadow: _hovered ? [BoxShadow(color: f.color.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(f.icon, color: f.color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(f.title, style: const TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(f.body, style: const TextStyle(color: _muted, fontSize: 14, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

// ── How It Works ──────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const _steps = [
    ('01', 'Sign in with Google', 'One tap. A Circle MPC wallet is created on Arc Testnet automatically. No seed phrase.', Color(0xFF4F46E5)),
    ('02', 'Get testnet USDC', 'Visit faucet.circle.com → select Arc Testnet → paste your wallet address. Free USDC in seconds.', Color(0xFF16A34A)),
    ('03', 'Browse 100 live markets', 'Real Polymarket predictions with live odds, sparkline charts, and volume data.', Color(0xFF0EA5E9)),
    ('04', 'Swipe YES or NO', 'Swipe right for YES, left for NO. Your USDC is sent to the PulsMarket smart contract on-chain.', Color(0xFFD97706)),
    ('05', 'Track your PNL', 'Portfolio shows entry price, current price, and real-time PNL. Claim winnings when markets resolve.', Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _brandSubtle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _brand.withValues(alpha: 0.3)),
            ),
            child: const Text('HOW IT WORKS', style: TextStyle(color: _brand, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 16),
          const Text('From zero to on-chain in 60 seconds',
              textAlign: TextAlign.center,
              style: TextStyle(color: _white, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.2)),
          const SizedBox(height: 56),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: _steps.asMap().entries.map((e) {
                final step = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _StepRow(number: step.$1, title: step.$2, body: step.$3, color: step.$4,
                      isLast: e.key == _steps.length - 1),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.title, required this.body, required this.color, required this.isLast});
  final String number, title, body;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(child: Text(number, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1, color: _border, margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(color: _white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(color: _muted, fontSize: 14, height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Section ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            const Text('Built on Circle\'s full stack',
                textAlign: TextAlign.center,
                style: TextStyle(color: _white, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1)),
            const SizedBox(height: 8),
            const Text('Real infrastructure. Real trades. Testnet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 16)),
            const SizedBox(height: 48),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 700 ? 4 : 2;
              return Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  statCard('100+', 'Live Markets', 'From Polymarket Gamma API', const Color(0xFF4F46E5), constraints, cols),
                  statCard('< 1s', 'Trade Speed', 'Arc Testnet sub-second finality', const Color(0xFF16A34A), constraints, cols),
                  statCard('\$0 ETH', 'Gas Cost', 'USDC is the native gas token', const Color(0xFFD97706), constraints, cols),
                  statCard('MPC', 'Wallet Type', 'Circle developer-controlled wallets', const Color(0xFF0EA5E9), constraints, cols),
                ].toList(),
              );
            }),
            const SizedBox(height: 48),
            // Contract address
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _brandSubtle, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.code_rounded, color: _brand, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PulsMarket.sol — Arc Testnet',
                            style: TextStyle(color: _white, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('0xca048d69BaA38C6364d3E107c2b389BB8D1320dB',
                            style: const TextStyle(color: _muted, fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  _SecondaryButton(
                    label: 'View ↗',
                    onTap: () => launchUrl(
                      Uri.parse('https://testnet.arcscan.app/address/0xca048d69BaA38C6364d3E107c2b389BB8D1320dB'),
                      mode: LaunchMode.externalApplication,
                    ),
                    small: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget statCard(String value, String label, String sub, Color color, BoxConstraints constraints, int cols) {
  return SizedBox(
    width: (constraints.maxWidth - (cols - 1) * 16) / cols,
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: _muted, fontSize: 12, height: 1.4)),
        ],
      ),
    ),
  );
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    return Container(
      color: _surface.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand.withValues(alpha: 0.15), _brandSubtle.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _brand.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                const Text('Ready to predict?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _white, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1)),
                const SizedBox(height: 12),
                const Text('Sign in with Google. Get a wallet. Trade in 60 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 16, height: 1.6)),
                const SizedBox(height: 28),
                _PrimaryButton(label: 'Launch Puls →', onTap: appState.completeOnboarding),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: _brandSubtle, borderRadius: BorderRadius.circular(6)),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text('Puls', style: TextStyle(color: _white, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('Built on Arc Testnet · Circle MPC Wallets · Polymarket Data',
                  style: TextStyle(color: _subtle, fontSize: 12)),
              const Spacer(),
              _FooterLink('GitHub', 'https://github.com/rdmbtc/Puls'),
              const SizedBox(width: 16),
              _FooterLink('Explorer', 'https://testnet.arcscan.app/address/0xca048d69BaA38C6364d3E107c2b389BB8D1320dB'),
              const SizedBox(width: 16),
              _FooterLink('Faucet', 'https://faucet.circle.com'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.url);
  final String label, url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
      ),
    );
  }
}

// ── Shared Buttons ────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.small ? 16 : 28,
              vertical: widget.small ? 9 : 14,
            ),
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(10),
              boxShadow: _hovered ? [BoxShadow(color: _brand.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4))] : [],
            ),
            child: Text(widget.label,
                style: TextStyle(
                  color: _white,
                  fontSize: widget.small ? 13 : 15,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 14 : 28,
            vertical: widget.small ? 9 : 14,
          ),
          decoration: BoxDecoration(
            color: _hovered ? _surfaceRaised : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? _muted : _border),
          ),
          child: Text(widget.label,
              style: TextStyle(
                color: _hovered ? _white : _muted,
                fontSize: widget.small ? 13 : 15,
                fontWeight: FontWeight.w500,
              )),
        ),
      ),
    );
  }
}
