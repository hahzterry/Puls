import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../app/puls_app.dart';
import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trade_math.dart';
import '../../data/mock/mock_videos.dart';
import '../../data/models/market.dart';
import '../../data/models/mock_video.dart';
import '../market/market_detail_screen.dart';
import '../market/trade_preview_sheet.dart';
import '../shell/web_layout.dart';
import '../wallet/wallet_service.dart';
import 'web_video_player.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Desktop web → static grid, mobile web/PWA → real video feed
    if (kIsWeb && MediaQuery.sizeOf(context).width >= 600) {
      return const _WebHomeScreen();
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: mockVideos.length,
          itemBuilder: (context, i) =>
              _VideoPage(video: mockVideos[i], autoPlay: i == 0),
        ),
      ),
    );
  }
}

class _WebHomeScreen extends StatelessWidget {
  const _WebHomeScreen();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final wallet = WalletServiceScope.of(context);
    final ws = wallet.state;
    final t = context.puls;
    final size = MediaQuery.sizeOf(context);

    // Find the main contract market or pick first featured, or fallback to mock
    final featuredMarket = appState.markets.firstWhere(
      (m) => m.isFeatured,
      orElse: () => appState.markets.isNotEmpty
          ? appState.markets.first
          : Market(
              id: '0xca048d69BaA38C6364d3E107c2b389BB8D1320dB',
              question: 'Will Donald Trump launch a new token in 2026?',
              category: 'Crypto',
              context: 'Resolves to YES if Donald Trump officially launches a new token on-chain in 2026.',
              yesPrice: 0.62,
              noPrice: 0.38,
              volume: '\$2.4M',
              liquidity: '\$120K',
              deadline: DateTime.now().add(const Duration(days: 90)),
              trend: 8.5,
              imageUrl: '',
              clobTokenId: '',
              volume24hr: 82000,
              spread: 0.01,
              bestBid: 0.61,
              bestAsk: 0.62,
              isFeatured: false,
              tags: const [],
              history: const [],
              comments: const [],
              news: const [],
            ),
    );

    final trendingMarkets = appState.markets
        .where((m) => m.id != featuredMarket.id)
        .take(6)
        .toList();

    final bodyContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (70%)
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeaturedHeroBanner(market: featuredMarket, t: t),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('Trending Predictions',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => PulsStateScope.of(context).refresh(),
                    icon: Icon(Icons.refresh_rounded, size: 16, color: t.brand),
                    label: Text('Refresh', style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.45,
                ),
                itemCount: trendingMarkets.length,
                itemBuilder: (context, i) => _WebTrendingCard(market: trendingMarkets[i], t: t),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column (30%)
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WebWalletBox(ws: ws, wallet: wallet, t: t),
              const SizedBox(height: 28),
              Text('Live Video Feed',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mockVideos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _WebSidebarVideoCard(video: mockVideos[i], t: t),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: WebLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: size.width < 900
              ? Column(
                  children: [
                    _FeaturedHeroBanner(market: featuredMarket, t: t),
                    const SizedBox(height: 24),
                    _WebWalletBox(ws: ws, wallet: wallet, t: t),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Trending Predictions',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: size.width > 600 ? 2 : 1,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: size.width > 600 ? 1.45 : 1.6,
                      ),
                      itemCount: trendingMarkets.length,
                      itemBuilder: (context, i) => _WebTrendingCard(market: trendingMarkets[i], t: t),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text('Live Video Feed',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mockVideos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => SizedBox(
                          width: 200,
                          child: _WebSidebarVideoCard(video: mockVideos[i], t: t),
                        ),
                      ),
                    ),
                  ],
                )
              : bodyContent,
        ),
      ),
    );
  }
}

class _FeaturedHeroBanner extends StatelessWidget {
  const _FeaturedHeroBanner({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final yesPct = (market.yesPrice * 100).round();
    final noPct = 100 - yesPct;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.surfaceRaised,
            t.brand.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: t.brand.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'FEATURED MARKET',
                  style: TextStyle(
                      color: t.brand,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, color: PulsColors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                'Volume: ${market.volume}',
                style: TextStyle(color: t.textSubtle, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MarketDetailScreen(marketId: market.id),
              ),
            ),
            child: Text(
              market.question,
              style: TextStyle(
                color: t.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            market.context,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _TradingPillButton(
                  label: 'Buy YES',
                  pct: '$yesPct%',
                  price: TradeMath.formatPrice(market.yesPrice),
                  color: PulsColors.green,
                  bg: PulsColors.greenLight,
                  onPressed: () => showTradePreviewSheet(
                      context: context, market: market, side: MarketSide.yes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TradingPillButton(
                  label: 'Buy NO',
                  pct: '$noPct%',
                  price: TradeMath.formatPrice(market.noPrice),
                  color: PulsColors.red,
                  bg: PulsColors.redLight,
                  onPressed: () => showTradePreviewSheet(
                      context: context, market: market, side: MarketSide.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebTrendingCard extends StatefulWidget {
  const _WebTrendingCard({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  State<_WebTrendingCard> createState() => _WebTrendingCardState();
}

class _WebTrendingCardState extends State<_WebTrendingCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final yesPct = (widget.market.yesPrice * 100).round();
    final noPct = 100 - yesPct;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MarketDetailScreen(marketId: widget.market.id),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered ? t.surfaceRaised : t.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hovered ? t.brand.withValues(alpha: 0.4) : t.border),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.market.category,
                      style: TextStyle(color: t.brand, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.market.volume,
                    style: TextStyle(color: t.textSubtle, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  widget.market.question,
                  style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w700, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickPill(label: 'YES $yesPct%', color: PulsColors.green, bg: PulsColors.greenLight),
                  const SizedBox(width: 6),
                  _QuickPill(label: 'NO $noPct%', color: PulsColors.red, bg: PulsColors.redLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _WebWalletBox extends StatelessWidget {
  const _WebWalletBox({required this.ws, required this.wallet, required this.t});
  final WalletState ws;
  final WalletService wallet;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final balance = double.tryParse(ws.usdcBalance)?.toStringAsFixed(2) ?? ws.usdcBalance;
    final isZero = (double.tryParse(ws.usdcBalance) ?? 0) == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: t.brand, size: 20),
              const SizedBox(width: 8),
              Text('Arc Wallet', style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (ws.walletAddress != null && ws.walletAddress!.isNotEmpty)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: PulsColors.green, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (ws.userId == null) ...[
            Text('Connect your wallet via the Profile tab to enable predicting on Arc Testnet.',
                style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.5)),
          ] else ...[
            Text('\$$balance USDC', style: TextStyle(color: t.text, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              ws.walletAddress != null && ws.walletAddress!.isNotEmpty
                  ? '${ws.walletAddress!.substring(0, 6)}...${ws.walletAddress!.substring(ws.walletAddress!.length - 4)}'
                  : 'Generating address...',
              style: TextStyle(color: t.textSubtle, fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 14),
            if (isZero) ...[
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://faucet.circle.com'), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: PulsColors.amberLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PulsColors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded, size: 14, color: PulsColors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Get testnet USDC faucet →',
                          style: const TextStyle(color: PulsColors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WebSidebarVideoCard extends StatefulWidget {
  const _WebSidebarVideoCard({required this.video, required this.t});
  final MockVideo video;
  final PulsThemeColors t;

  @override
  State<_WebSidebarVideoCard> createState() => _WebSidebarVideoCardState();
}

class _WebSidebarVideoCardState extends State<_WebSidebarVideoCard> {
  bool _hovered = false;

  void _playVideoPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.t.border, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: buildWebVideoPlayer(widget.video.videoUrl) ?? const SizedBox(),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.video.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(widget.video.caption, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _playVideoPopup(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hovered ? t.surfaceRaised : t.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? t.brand : t.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.username,
                      style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.video.caption,
                      style: TextStyle(color: t.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _TradingPillButton extends StatelessWidget {
  const _TradingPillButton({
    required this.label,
    required this.pct,
    required this.price,
    required this.color,
    required this.bg,
    required this.onPressed,
  });
  final String label;
  final String pct;
  final String price;
  final Color color;
  final Color bg;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(width: 8),
            Text(pct, style: TextStyle(color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(width: 4),
            Text('($price)', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Single video page ─────────────────────────────────────────────────────────
class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.video, this.autoPlay = false});
  final MockVideo video;
  final bool autoPlay;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _showComments = false;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _ctrl = (widget.video.isAsset
            ? VideoPlayerController.asset(widget.video.videoUrl)
            : VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl)))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
        }
      }).catchError((_) {
        if (mounted) setState(() => _ready = false);
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _openMarket(BuildContext context) {
    final appState = PulsStateScope.of(context);
    // Find market by matching question substring
    try {
      final market = appState.markets.firstWhere(
        (m) => m.question
            .toLowerCase()
            .contains(widget.video.linkedMarketQuestion.toLowerCase().split(' ').take(4).join(' ')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MarketDetailScreen(marketId: market.id),
        ),
      );
    } catch (_) {
      // No matching market found — show the preview sheet instead
      _showMarketSheet(context);
    }
  }

  void _showMarketSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MarketSheet(video: widget.video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: () {
        if (_showComments) {
          setState(() => _showComments = false);
        } else if (_ready) {
          setState(() {
            _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
          });
        }
      },
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video ───────────────────────────────────────────────────────
            const ColoredBox(color: Colors.black),
            if (kIsWeb)
              buildWebVideoPlayer(widget.video.videoUrl) ??
                  Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.3), size: 72)
            else if (_ready)
              Center(
                child: AspectRatio(
                  aspectRatio: _ctrl!.value.aspectRatio,
                  child: VideoPlayer(_ctrl!),
                ),
              )
            else
              Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                          const SizedBox(height: 12),
                          Text('Loading video…',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 13)),
                        ],
                      ),
              ),

            // ── Gradient overlays ────────────────────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0, 0.2, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),

            // ── Top bar ──────────────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // ── Pause indicator ──────────────────────────────────────────────
            if (_ready && !(_ctrl?.value.isPlaying ?? false) && !_showComments)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
              ),

            // ── Right action bar ─────────────────────────────────────────────
            Positioned(
              right: 12,
              bottom: 140,
              child: _ActionBar(
                video: widget.video,
                liked: _liked,
                onLike: () => setState(() => _liked = !_liked),
                onComments: () =>
                    setState(() => _showComments = !_showComments),
              ),
            ),

            // ── Bottom info ──────────────────────────────────────────────────
            Positioned(
              left: 16,
              right: 80,
              bottom: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.video.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.video.caption,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Prediction pill ──────────────────────────────────────────────
            Positioned(
              left: 16,
              right: 16,
              bottom: 72,
              child: GestureDetector(
                onTap: () => _openMarket(context),
                child: _PredictionPill(video: widget.video),
              ),
            ),

            // ── Comments overlay ─────────────────────────────────────────────
            if (_showComments) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showComments = false),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CommentsSheet(
                  video: widget.video,
                  onClose: () => setState(() => _showComments = false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Right action bar ──────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.video,
    required this.liked,
    required this.onLike,
    required this.onComments,
  });
  final MockVideo video;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PulsColors.indigo,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              video.avatar,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
            ),
          ),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: onLike,
          child: _Btn(
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: _fmt(video.likes + (liked ? 1 : 0)),
            color: liked ? Colors.red.shade400 : Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onComments,
          child: _Btn(
            icon: Icons.chat_bubble_outline_rounded,
            label: _fmt(video.comments.length),
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        _Btn(
          icon: Icons.remove_red_eye_outlined,
          label: _fmt(video.views),
          color: Colors.white,
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Prediction pill ───────────────────────────────────────────────────────────
class _PredictionPill extends StatelessWidget {
  const _PredictionPill({required this.video});
  final MockVideo video;

  @override
  Widget build(BuildContext context) {
    final yes = video.linkedMarketYesPrice;
    final no = 1 - yes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              video.linkedMarketQuestion,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _OddsBadge(yes: yes, no: no),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white54, size: 12),
        ],
      ),
    );
  }
}

class _OddsBadge extends StatelessWidget {
  const _OddsBadge({required this.yes, required this.no});
  final double yes;
  final double no;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            color: PulsColors.green,
            child: Text('${(yes * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            color: PulsColors.red,
            child: Text('${(no * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Market sheet (fallback when no live market found) ─────────────────────────
class _MarketSheet extends StatelessWidget {
  const _MarketSheet({required this.video});
  final MockVideo video;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final yes = video.linkedMarketYesPrice;
    final no = 1 - yes;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.brandSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('PREDICTION',
                    style: TextStyle(
                        color: t.brand,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, color: t.textSubtle, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(video.linkedMarketQuestion,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SheetBtn(
                    label: 'YES',
                    price: '${(yes * 100).round()}¢',
                    bg: PulsColors.greenLight,
                    fg: PulsColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetBtn(
                    label: 'NO',
                    price: '${(no * 100).round()}¢',
                    bg: PulsColors.redLight,
                    fg: PulsColors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('Demo only — no real trades',
                style: TextStyle(color: t.textSubtle, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  const _SheetBtn(
      {required this.label,
      required this.price,
      required this.bg,
      required this.fg});
  final String label;
  final String price;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
          Text(price,
              style: TextStyle(
                  color: fg.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Comments sheet ────────────────────────────────────────────────────────────
class _CommentsSheet extends StatelessWidget {
  const _CommentsSheet({required this.video, required this.onClose});
  final MockVideo video;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Text('${video.comments.length} comments',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.textSubtle, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Divider(color: t.border, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: video.comments.length,
              itemBuilder: (context, i) =>
                  _CommentTile(comment: video.comments[i], t: t),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.t});
  final VideoComment comment;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: t.brandSubtle,
                child: Text(comment.avatar,
                    style: TextStyle(
                        color: t.brand,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.username,
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(comment.text,
                        style: TextStyle(
                            color: t.text, fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border_rounded,
                      color: t.textSubtle, size: 14),
                  const SizedBox(width: 3),
                  Text(_fmt(comment.likes),
                      style:
                          TextStyle(color: t.textSubtle, fontSize: 11)),
                ],
              ),
            ],
          ),
          // Reply
          if (comment.reply != null)
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: PulsColors.greenLight,
                    child: Text(comment.reply!.avatar,
                        style: const TextStyle(
                            color: PulsColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comment.reply!.username,
                            style: TextStyle(
                                color: t.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(comment.reply!.text,
                            style: TextStyle(
                                color: t.text,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border_rounded,
                          color: t.textSubtle, size: 12),
                      const SizedBox(width: 3),
                      Text(_fmt(comment.reply!.likes),
                          style: TextStyle(
                              color: t.textSubtle, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}
