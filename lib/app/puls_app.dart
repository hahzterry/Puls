import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/anim/pulse_governor.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/analytics.dart';
import '../core/utils/puls_emoji.dart';
import '../core/utils/web_url.dart';
import '../core/widgets/puls_page_route.dart';
import '../core/widgets/tab_visibility.dart';
import '../data/mock/mock_market_repository.dart';
import '../features/market/screens/market_terminal_screen.dart'
    deferred as terminal;
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/puls_shell.dart';
import '../features/wallet/wallet_service.dart';
import '../core/services/live_stream_service.dart';
import 'deep_link.dart';
import 'puls_app_state.dart';

class PulsApp extends StatefulWidget {
  const PulsApp({super.key});

  @override
  State<PulsApp> createState() => _PulsAppState();
}

class _PulsAppState extends State<PulsApp> {
  late final PulsAppState _state;
  final _walletService = WalletService();
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Deep link parsed from an inbound URL (e.g. `https://app.pulsmarket.tech/m/<slug>`
  /// or `/agent/<id>` or `/u/<handle>` or one of the named routes `/pulse`,
  /// `/versus`, `/explorer`, `/stats`, `/agent`). Held until the shell is ready,
  /// then the corresponding screen is pushed once. See [DeepLink] for the full
  /// list of supported routes.
  DeepLink? _pendingDeepLink;
  bool _deepLinkOpening = false;

  // ── Granular reactivity (replaces Listenable.merge at the root) ────────
  // The old root `AnimatedBuilder(animation: Listenable.merge([_state, _walletService]))`
  // rebuilt the ENTIRE MaterialApp on every wallet balance tick + every state
  // notification — catastrophic for the cyberpunk terminal's 60fps target.
  // Instead, we expose two tiny ValueNotifiers that ONLY fire when the values
  // the root actually cares about (shell visibility + theme mode) change.
  // Descendants read granular state via PulsStateScope / WalletServiceScope
  // (InheritedNotifier) — those don't rebuild the root.
  late final ValueNotifier<bool> _shellVisible;
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();
    _state = PulsAppState(mockRepo: MockMarketRepository());
    _pendingDeepLink = DeepLink.parse(Uri.base);
    _themeMode = ValueNotifier<ThemeMode>(_state.themeMode);
    _shellVisible = ValueNotifier<bool>(_computeShellVisible());
    // Lightweight listeners — only notify when the derived value actually
    // flips. This is O(1) per tick vs the old O(widget-tree) rebuild.
    _state.addListener(_onStateChanged);
    _walletService.addListener(_onWalletChanged);
    _registerPopStateListener();
    LiveStreamService.instance.start();
    _configureImageCache();
    // Fix: on a cold load where _shellVisible is already correct on the very
    // first frame (e.g. already-authenticated user on app.pulsmarket.tech/m/<slug>),
    // there's no false→true flip for the change listeners to detect, so the
    // deep-link callback never fires. Add an explicit call after the first
    // frame so cold loads of deep-linked routes actually resolve.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenDeepLink(_shellVisible.value);
      _maybeOpenTerminal(_shellVisible.value);
    });
  }

  // ── Image memory diet (FPS spec §2) ──────────────────────────────────────
  // The default cache (1000 entries / 100MB of decoded bitmaps) is oversized
  // for low-RAM machines: full-cache + live decodes push browser tab memory
  // into paging territory on 8GB PCs, and GC pauses show up as scroll jank.
  // While hidden, decoded bitmaps are released entirely — they re-decode
  // transparently (through FadeNetImage's fade-in) when the tab returns.
  void _configureImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes = 64 << 20; // 64 MB of decoded bitmaps
    cache.maximumSize = 400;
    TabVisibility.ensureListening();
    TabVisibility.listenable.addListener(_onTabVisibilityChanged);
  }

  void _onTabVisibilityChanged() {
    if (TabVisibility.visible) return;
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  void _onStateChanged() {
    final newTheme = _state.themeMode;
    if (_themeMode.value != newTheme) _themeMode.value = newTheme;
    final newShell = _computeShellVisible();
    final shellFlipped = _shellVisible.value != newShell;
    if (shellFlipped) {
      _shellVisible.value = newShell;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenDeepLink(newShell);
      _maybeOpenTerminal(newShell);
      if (shellFlipped && newShell && !_appShellViewedFired) {
        _appShellViewedFired = true;
        trackEvent('app_shell_viewed');
      }
    });
  }

  // Tracks whether `app_shell_viewed` has fired once this session. Without
  // this guard, the event would fire every time the shell visibility flipped
  // (sign-in, onboarding complete, deep-link open), inflating the funnel count.
  bool _appShellViewedFired = false;

  void _onWalletChanged() {
    final newShell = _computeShellVisible();
    if (_shellVisible.value != newShell) {
      _shellVisible.value = newShell;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenDeepLink(newShell);
      _maybeOpenTerminal(newShell);
    });
  }

  bool _computeShellVisible() {
    final isLandingHost = kIsWeb &&
        (Uri.base.host == 'pulsmarket.tech' ||
            Uri.base.host == 'www.pulsmarket.tech');
    // On the landing host, the full app shell is NEVER visible. Public routes
    // (/agent, /pulse, /versus, /explorer, /m/<slug>, /u/<handle>) render as
    // standalone previews via PublicPreviewHost, and everything else renders
    // the landing page (OnboardingScreen → WebLandingPage). Previously,
    // _pendingDeepLink != null forced PulsShell onto the marketing domain,
    // which dropped unauthenticated visitors into the full logged-in product.
    if (isLandingHost) return false;
    // On the app host (or local dev), a pending deep link makes the shell
    // visible so the deep-linked screen can be pushed on top of it.
    return _pendingDeepLink != null ||
        (_state.onboardingComplete ||
            _walletService.state.userId != null);
  }

  void _maybeOpenDeepLink(bool shellVisible) {
    final link = _pendingDeepLink;
    if (link == null || _deepLinkOpening || !shellVisible) return;

    // Market deep links wait for the feed to finish loading before pushing,
    // so the user goes straight from feed → detail without seeing a loader on
    // Market deep links no longer wait for feed — ensureMarketBySlug fetches
    // from API independently. This fixes cold-load deep links that never fired
    // because feedStatus stayed 'loading' too long on slow connections.
    // if (link is MarketDeepLink) {
    //   if (_state.feedStatus == FeedStatus.loading) return;
    // }

    _deepLinkOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      () async {
        // For market deep links, pre-resolve the slug via the app state so
        // the detail screen gets a known-loaded market id (and skips its
        // own loader). For unknown slugs, stay on the feed.
        if (link is MarketDeepLink) {
          final market = await _state.ensureMarketBySlug(link.slug);
          _pendingDeepLink = null;
          _deepLinkOpening = false;
          if (market == null) return;
          if (!mounted) return;
          await link.open(_navigatorKey);
          return;
        }
        _pendingDeepLink = null;
        _deepLinkOpening = false;
        if (!mounted) return;
        await link.open(_navigatorKey);
      }();
    });
  }

  bool _terminalOpening = false;

  void _maybeOpenTerminal(bool shellVisible) {
    if (!_state.pendingTerminal || _terminalOpening || !shellVisible) return;
    _terminalOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      () async {
        _state.pendingTerminal = false;
        _terminalOpening = false;
        await terminal.loadLibrary();
        _navigatorKey.currentState?.push(
          pulsRoute<void>(
            _navigatorKey.currentContext,
            settings: const RouteSettings(name: '/terminal'),
            builder: (_) => terminal.MarketTerminalScreen(),
          ),
        );
      }();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PulsEmoji.precacheAll(context);
  }

  // Browser back/forward button disposer. Registered once in initState on web
  // so the back button pops the in-app Navigator (matching what users expect
  // from a real website). Without this, the browser back button would either
  // navigate away from the app entirely or do nothing, since Flutter manages
  // its own Navigator stack by default.
  VoidCallback? _popStateDisposer;

  void _registerPopStateListener() {
    if (!kIsWeb) return;
    _popStateDisposer = onPopState((path) {
      // If the Navigator can still pop (there are routed screens above the
      // shell), pop the in-app Navigator — this is the "back goes to the
      // previous screen" behaviour users expect from a web app.
      if (_navigatorKey.currentState?.canPop() ?? false) {
        _navigatorKey.currentState?.pop();
      }
      // Otherwise the back button would exit to the previous browser entry,
      // which is the correct web default — no action needed.
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _walletService.removeListener(_onWalletChanged);
    TabVisibility.listenable.removeListener(_onTabVisibilityChanged);
    _shellVisible.dispose();
    _themeMode.dispose();
    _walletService.dispose();
    _popStateDisposer?.call();
    super.dispose();
  }

  /// Resolve the MaterialApp's `home:` widget. Three branches:
  ///
  /// 1. Landing host + pending deep link → [PublicPreviewHost]: a standalone
  ///    public preview with a lightweight header bar (logo + back to landing).
  ///    No app shell, no sign-in required. This is what makes
  ///    pulsmarket.tech/agent, /pulse, /versus, /explorer render as real
  ///    standalone pages instead of redirecting back to the landing.
  ///
  /// 2. App host (or local dev) + shellVisible → [PulsShell]: the full
  ///    authenticated app with bottom nav, wallet balance, portfolio tab, etc.
  ///
  /// 3. Otherwise → [OnboardingScreen]: the onboarding slides (or the
  ///    WebLandingPage on the landing host).
  Widget _resolveHome(bool shellVisible) {
    if (kIsWeb) {
      final isLandingHost =
          Uri.base.host == 'pulsmarket.tech' ||
              Uri.base.host == 'www.pulsmarket.tech';
      if (isLandingHost && _pendingDeepLink != null) {
        return PublicPreviewHost(link: _pendingDeepLink!);
      }
    }
    return shellVisible ? const PulsShell() : const OnboardingScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Two narrow ValueListenableBuilders replace Listenable.merge([_state, _walletService]).
    // - _shellVisible flips at most a handful of times per session (onboarding
    //   complete, sign-in, deep-link). It triggers a MaterialApp rebuild ONLY
    //   then — never on wallet balance ticks or feed updates.
    // - _themeMode flips only when the user toggles dark/light.
    // Everything else is read once here (title, navigatorKey) and descendants
    // pull granular state via PulsStateScope.of(context) / WalletServiceScope.of(context).
    return ValueListenableBuilder<bool>(
      valueListenable: _shellVisible,
      builder: (context, shellVisible, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: _themeMode,
          builder: (context, themeMode, _) {
            return WalletServiceScope(
              service: _walletService,
              child: PulsStateScope(
                notifier: _state,
                child: MaterialApp(
                  title:
                      'Puls — Prediction Markets on Arc Network, Traded by AI Agents',
                  debugShowCheckedModeBanner: false,
                  navigatorKey: _navigatorKey,
                  theme: PulsTheme.light(),
                  darkTheme: PulsTheme.dark(),
                  themeMode: themeMode,
                  // Global animation governor (FPS spec §1): mutes every
                  // ticker under the Navigator while the browser tab is
                  // hidden, so a background tab burns zero animation frames.
                  builder: (context, child) => TabPulseGate(
                    child: child ?? const SizedBox.shrink(),
                  ),
                  home: _resolveHome(shellVisible),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── InheritedNotifier scope for WalletService ─────────────────────────────────
class WalletServiceScope extends InheritedNotifier<WalletService> {
  const WalletServiceScope({
    required WalletService service,
    required super.child,
    super.key,
  }) : super(notifier: service);

  static WalletService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WalletServiceScope>();
    assert(scope != null, 'WalletServiceScope not found');
    return scope!.notifier!;
  }
}
