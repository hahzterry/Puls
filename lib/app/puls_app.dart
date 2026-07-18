import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/puls_emoji.dart';
import '../core/widgets/puls_page_route.dart';
import '../data/mock/mock_market_repository.dart';
import '../features/market/market_detail_screen.dart' deferred as market_detail;
import '../features/market/screens/market_terminal_screen.dart'
    deferred as terminal;
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/puls_shell.dart';
import '../features/wallet/wallet_service.dart';
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

  /// Slug from a share deep link (https://pulsmarket.tech/m/<slug> redirects
  /// to /?m=<slug>). Held until the shell + market feed are ready, then the
  /// market detail screen is pushed once.
  String? _pendingDeepLinkSlug;
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
    _pendingDeepLinkSlug = _parseDeepLinkSlug(Uri.base);
    _themeMode = ValueNotifier<ThemeMode>(_state.themeMode);
    _shellVisible = ValueNotifier<bool>(_computeShellVisible());
    // Lightweight listeners — only notify when the derived value actually
    // flips. This is O(1) per tick vs the old O(widget-tree) rebuild.
    _state.addListener(_onStateChanged);
    _walletService.addListener(_onWalletChanged);
  }

  void _onStateChanged() {
    final newTheme = _state.themeMode;
    if (_themeMode.value != newTheme) _themeMode.value = newTheme;
    final newShell = _computeShellVisible();
    if (_shellVisible.value != newShell) {
      _shellVisible.value = newShell;
      // Side-effects only fire when shell visibility actually changes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeOpenDeepLink(newShell);
        _maybeOpenTerminal(newShell);
      });
    }
  }

  void _onWalletChanged() {
    final newShell = _computeShellVisible();
    if (_shellVisible.value != newShell) {
      _shellVisible.value = newShell;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeOpenDeepLink(newShell);
        _maybeOpenTerminal(newShell);
      });
    }
  }

  bool _computeShellVisible() {
    final isLandingHost = kIsWeb &&
        (Uri.base.host == 'pulsmarket.tech' ||
            Uri.base.host == 'www.pulsmarket.tech');
    return _pendingDeepLinkSlug != null ||
        (!isLandingHost &&
            (_state.onboardingComplete ||
                _walletService.state.userId != null));
  }

  static String? _parseDeepLinkSlug(Uri uri) {
    final q = uri.queryParameters['m'];
    if (q != null && q.trim().isNotEmpty) return q.trim();
    final segs = uri.pathSegments;
    if (segs.length >= 2 && segs[0] == 'm' && segs[1].trim().isNotEmpty) {
      return segs[1].trim();
    }
    return null;
  }

  void _maybeOpenDeepLink(bool shellVisible) {
    final slug = _pendingDeepLinkSlug;
    if (slug == null || _deepLinkOpening || !shellVisible) return;
    if (_state.feedStatus == FeedStatus.loading) return;
    _deepLinkOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      () async {
        final market = await _state.ensureMarketBySlug(slug);
        _pendingDeepLinkSlug = null;
        if (market == null) return; // unknown slug — stay on the feed
        await market_detail.loadLibrary();
        _navigatorKey.currentState?.push(
          pulsRoute<void>(
            _navigatorKey.currentContext,
            settings: RouteSettings(name: '/m/${market.slug}'),
            builder: (_) => market_detail.MarketDetailScreen(marketId: market.id),
          ),
        );
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

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _walletService.removeListener(_onWalletChanged);
    _shellVisible.dispose();
    _themeMode.dispose();
    _walletService.dispose();
    super.dispose();
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
                  home: shellVisible
                      ? const PulsShell()
                      : const OnboardingScreen(),
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
