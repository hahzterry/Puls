import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/widgets/puls_page_route.dart';
import '../features/agent/agent_screen.dart' deferred as agent;
import '../features/agent/pulse_feed.dart' deferred as pulse_feed;
import '../features/agent/gladiator_arena_screen.dart' deferred as gladiator;
import '../features/agent/economy_feed.dart' deferred as economy;
import '../features/market/market_detail_screen.dart' deferred as market_detail;
import '../features/profile/user_profile_screen.dart' deferred as user_profile;
import '../features/onboarding/live_traction.dart';
import '../core/utils/web_url.dart';

/// A deep link parsed from an inbound URL (or constructed in-app for
/// `history.pushState` sync). Each subclass corresponds to a route that's
/// independently loadable via direct URL — refresh, share, browser back/forward
/// all work because the URL is the source of truth.
///
/// The pattern mirrors what already existed for `/m/<slug>` (see
/// `_parseDeepLinkSlug` in puls_app.dart): parse on startup → wait for shell
/// ready → push the right screen → update document.title + OG tags.
sealed class DeepLink {
  const DeepLink();

  /// Parse an inbound URL into a [DeepLink], or `null` if the URL doesn't
  /// match any known deep-linkable route (in which case the app just lands on
  /// the feed/home as before).
  ///
  /// Accepts the same dual encoding the existing market deep link supports:
  /// both path-segment (`/m/<slug>`) and query-param (`?m=<slug>`) forms.
  static DeepLink? parse(Uri uri) {
    // ── Path-segment routes ────────────────────────────────────────────────
    final segs = uri.pathSegments;
    if (segs.isNotEmpty) {
      switch (segs.first) {
        case 'm':
          if (segs.length >= 2 && segs[1].trim().isNotEmpty) {
            return MarketDeepLink(segs[1].trim());
          }
          break;
        case 'agent':
          // `/agent/<id>` — a specific agent's decision trace. `/agent` alone
          // (no second segment) routes to the Agent tab in the shell.
          if (segs.length >= 2 && segs[1].trim().isNotEmpty) {
            return AgentTraceDeepLink(segs[1].trim());
          }
          return const NamedRouteDeepLink.agent();
        case 'u':
          if (segs.length >= 2 && segs[1].trim().isNotEmpty) {
            return UserProfileDeepLink(segs[1].trim());
          }
          break;
        case 'pulse':
          return const NamedRouteDeepLink.pulse();
        case 'versus':
          return const NamedRouteDeepLink.versus();
        case 'explorer':
          return const NamedRouteDeepLink.explorer();
        case 'stats':
          return const NamedRouteDeepLink.stats();
      }
    }

    // ── Query-param fallback (legacy /?m=<slug> form, still supported) ────
    final m = uri.queryParameters['m'];
    if (m != null && m.trim().isNotEmpty) return MarketDeepLink(m.trim());

    return null;
  }

  /// Push the corresponding screen onto the navigator. Returns the route name
  /// (also used as the URL path for `history.pushState`).
  ///
  /// Subclasses override to load their deferred library + push the right
  /// screen + update document.title/OG tags. The [navKey] provides both the
  /// navigator state and a build context (via `currentContext`) that's safe
  /// to use across async gaps because it's accessed via the GlobalKey
  /// getter, not captured in a closure.
  Future<String?> open(GlobalKey<NavigatorState> navKey);
}

/// `/m/<slug>` — a specific market's detail page. Already worked before this
/// sprint; folded into the unified [DeepLink] hierarchy so all routes share
/// the same parse + open + URL-sync flow.
class MarketDeepLink extends DeepLink {
  const MarketDeepLink(this.slug);
  final String slug;

  @override
  Future<String?> open(GlobalKey<NavigatorState> navKey) async {
    await market_detail.loadLibrary();
    final routeName = '/m/$slug';
    // Access navKey.currentContext directly in the push call — capturing it in
    // a local variable would trip use_build_context_synchronously, but the
    // GlobalKey getter is safe across async gaps (it always returns the
    // navigator's current context, or null if detached).
    navKey.currentState?.push(
      pulsRoute<void>(
        navKey.currentContext,
        settings: RouteSettings(name: routeName),
        builder: (_) => market_detail.MarketDetailScreen(marketId: slug),
      ),
    );
    return routeName;
  }
}

/// `/agent/<id>` — a specific agent's decision trace. Renders the agent's
/// roster entry (identity, reputation, recent decisions) as a routed screen.
class AgentTraceDeepLink extends DeepLink {
  const AgentTraceDeepLink(this.agentId);
  final String agentId;

  @override
  Future<String?> open(GlobalKey<NavigatorState> navKey) async {
    await agent.loadLibrary();
    final routeName = '/agent/$agentId';
    navKey.currentState?.push(
      pulsRoute<void>(
        navKey.currentContext,
        settings: RouteSettings(name: routeName),
        builder: (_) => agent.AgentScreen(initialAgentId: agentId),
      ),
    );
    return routeName;
  }
}

/// `/u/<handle>` — a specific user's profile. Delegates to the existing
/// [UserProfileScreen], which already takes a `userId`.
class UserProfileDeepLink extends DeepLink {
  const UserProfileDeepLink(this.handle);
  final String handle;

  @override
  Future<String?> open(GlobalKey<NavigatorState> navKey) async {
    await user_profile.loadLibrary();
    final routeName = '/u/$handle';
    navKey.currentState?.push(
      pulsRoute<void>(
        navKey.currentContext,
        settings: RouteSettings(name: routeName),
        builder: (_) => user_profile.UserProfileScreen(userId: handle),
      ),
    );
    return routeName;
  }
}

/// `/pulse`, `/versus`, `/explorer`, `/stats`, `/agent` — named flagship routes
/// that map to a specific Flutter screen. Each is independently shareable.
class NamedRouteDeepLink extends DeepLink {
  const NamedRouteDeepLink._(this.name, this._title);
  const NamedRouteDeepLink.agent() : this._('agent', 'Agent — Puls');
  const NamedRouteDeepLink.pulse() : this._('pulse', 'Pulse — the autonomous house agent');
  const NamedRouteDeepLink.versus() : this._('versus', 'Agents vs Humans — live PnL scoreboard');
  const NamedRouteDeepLink.explorer() : this._('explorer', 'Puls Explorer — live economy on Arc');
  const NamedRouteDeepLink.stats() : this._('stats', 'Live Traction — Puls');

  final String name;
  final String _title;

  @override
  Future<String?> open(GlobalKey<NavigatorState> navKey) async {
    final routeName = '/$name';
    // Each named route pushes a thin Scaffold wrapping the existing widget
    // that already represents that surface (PulseFeed, GladiatorArenaScreen,
    // EconomyFeed, LiveTractionSection). The widgets are unchanged — they're
    // just hosted in a routed screen so a direct URL load lands on them.
    switch (name) {
      case 'pulse':
        await pulse_feed.loadLibrary();
        navKey.currentState?.push(
          pulsRoute<void>(
            navKey.currentContext,
            settings: RouteSettings(name: routeName),
            builder: (_) => _NamedRouteScreen(
              title: _title,
              routeName: routeName,
              child: pulse_feed.PulseFeed(),
            ),
          ),
        );
        break;
      case 'versus':
        await gladiator.loadLibrary();
        navKey.currentState?.push(
          pulsRoute<void>(
            navKey.currentContext,
            settings: RouteSettings(name: routeName),
            builder: (_) => _NamedRouteScreen(
              title: _title,
              routeName: routeName,
              child: gladiator.GladiatorArenaScreen(),
            ),
          ),
        );
        break;
      case 'explorer':
        await economy.loadLibrary();
        navKey.currentState?.push(
          pulsRoute<void>(
            navKey.currentContext,
            settings: RouteSettings(name: routeName),
            builder: (_) => _NamedRouteScreen(
              title: _title,
              routeName: routeName,
              child: economy.EconomyFeed(),
            ),
          ),
        );
        break;
      case 'stats':
        // LiveTractionSection is a landing-page section widget (not a Screen),
        // but it fetches /api/stats and renders the same numbers the static
        // /stats.html advertises. Hosted in a Scaffold here so direct URL
        // loads land on the live data rather than the static HTML.
        navKey.currentState?.push(
          pulsRoute<void>(
            navKey.currentContext,
            settings: RouteSettings(name: routeName),
            builder: (_) => _NamedRouteScreen(
              title: _title,
              routeName: routeName,
              child: const LiveTractionSection(),
            ),
          ),
        );
        break;
      case 'agent':
        await agent.loadLibrary();
        navKey.currentState?.push(
          pulsRoute<void>(
            navKey.currentContext,
            settings: RouteSettings(name: routeName),
            builder: (_) => _NamedRouteScreen(
              title: _title,
              routeName: routeName,
              child: agent.AgentScreen(),
            ),
          ),
        );
        break;
    }
    return routeName;
  }
}

/// Thin wrapper that hosts a body widget in a routed Scaffold, and keeps the
/// browser URL + document.title in sync via [web_url]. Used by
/// [NamedRouteDeepLink.open] so all the named flagship routes share the same
/// URL-sync behaviour.
class _NamedRouteScreen extends StatefulWidget {
  const _NamedRouteScreen({
    required this.title,
    required this.routeName,
    required this.child,
  });

  final String title;
  final String routeName;
  final Widget child;

  @override
  State<_NamedRouteScreen> createState() => _NamedRouteScreenState();
}

class _NamedRouteScreenState extends State<_NamedRouteScreen> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      pushUrl(widget.routeName, title: widget.title);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      // When leaving a shareable screen, reset the OG tags to the site
      // defaults so a subsequent share of the home/feed URL shows the
      // generic Puls card, not the stale per-page one.
      resetShareMetadata();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
