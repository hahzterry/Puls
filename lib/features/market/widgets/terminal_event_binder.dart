import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/motion.dart';
import '../../../core/network/websocket_service.dart';
import '../../agent/widgets/decision_log_panel.dart';
import '../../agent/widgets/swarm_visualizer.dart';
import '../../../core/rendering/swarm_painter.dart';

/// Wraps the [MarketTerminalScreen] subtree and binds the live WebSocket
/// event stream to the three cyberpunk UI elements:
///
///   • [SwarmVisualizer]    — pulses on trades + signal publishes.
///   • [DecisionLogPanel]   — a terminal log line per major event.
///   • [CameraShake]         — fires on negative events (slashed / failed).
///
/// This is an invisible widget (renders [child] unchanged) — it only adds
/// a subscription in [initState] and tears it down in [dispose]. Put it
/// high enough in the tree that all three target widgets are descendants
/// (the [MarketTerminalScreen] is the natural host).
class TerminalEventBinder extends StatefulWidget {
  const TerminalEventBinder({super.key, required this.child});

  final Widget child;

  @override
  State<TerminalEventBinder> createState() => _TerminalEventBinderState();
}

class _TerminalEventBinderState extends State<TerminalEventBinder> {
  StreamSubscription<PulsSocketEvent>? _sub;
  final math.Random _rnd = math.Random();

  // Brand colors — kept here so the log formatter has them without needing
  // a BuildContext (the stream listener fires outside build).
  static const _mint = Color(0xFF2DD4BF);
  static const _pink = Color(0xFFEC4899);
  static const _amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    // Connect once at boot (idempotent — the service no-ops if already on).
    WebSocketService.instance.connect();
    _sub = WebSocketService.instance.events.listen(_handleEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleEvent(PulsSocketEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'trade:created':
        _onTradeCreated(event);
        break;
      case 'trade:complete':
        _onTradeComplete(event);
        break;
      case 'trade:failed':
        _onTradeFailed(event);
        break;
      case 'signal:published':
        _onSignalPublished(event);
        break;
      case 'market:resolved':
        _onMarketResolved(event);
        break;
      case 'market:activated':
        _onMarketActivated(event);
        break;
      case 'order:limit_placed':
        _log('LIMIT ORDER PLACED', LogLevel.pay);
        break;
      case 'order:limit_filled':
        _log('LIMIT ORDER FILLED', LogLevel.ok);
        _spawnPulse(amount: 0.1, color: _mint);
        break;
      case 'order:limit_cancelled':
        _log('LIMIT ORDER CANCELLED', LogLevel.warn);
        break;
      case 'blog:published':
        _log('BLOG PUBLISHED', LogLevel.info);
        break;
      case 'comment:created':
        _log('COMMENT POSTED', LogLevel.info);
        break;
      case 'wallet:created':
        _log('WALLET CREATED', LogLevel.ok);
        break;
      case 'notification:created':
        _onNotification(event);
        break;
      // Other events (market:archived, signal:archived, wallet:balance_changed)
      // are silently ignored — they don't warrant a terminal line.
    }
  }

  // ── Per-event handlers ────────────────────────────────────────────────

  void _onTradeCreated(PulsSocketEvent e) {
    final side = e.field<String>('side') ?? 'YES';
    final amount = e.field<num>('usdc_amount');
    final question = e.field<String>('question') ?? '';
    final isAgent = _isAgent(e.field<String>('user_id'));
    final amtStr = amount != null ? '\$${_fmtUsd(amount)}' : '';
    _log(
      '${isAgent ? "AGENT" : "HUMAN"} TRADE OPEN: $side $amtStr'
      '${question.isNotEmpty ? ' · ${_short(question, 40)}' : ''}',
      LogLevel.info,
    );
  }

  void _onTradeComplete(PulsSocketEvent e) {
    final side = e.field<String>('side') ?? 'YES';
    final amount = e.field<num>('usdc_amount');
    final question = e.field<String>('question') ?? '';
    final userId = e.field<String>('user_id') ?? '';
    final isAgent = _isAgent(userId);
    final amtStr = amount != null ? '\$${_fmtUsd(amount)}' : '';

    // Swarm pulse: a USDC payment moving. Color by side (mint=YES, pink=NO).
    _spawnPulse(
      amount: (amount ?? 0).abs().toDouble(),
      color: side.toUpperCase() == 'YES' ? _mint : _pink,
      isTrader: !isAgent,
    );

    _log(
      '${isAgent ? "AGENT" : "HUMAN"} TRADE FILLED: $side $amtStr'
      '${question.isNotEmpty ? ' · ${_short(question, 40)}' : ''}',
      LogLevel.ok,
    );
  }

  void _onTradeFailed(PulsSocketEvent e) {
    final side = e.field<String>('side') ?? 'YES';
    _log('TRADE FAILED: $side', LogLevel.err);
    _shake(); // negative event → camera shake
  }

  void _onSignalPublished(PulsSocketEvent e) {
    final title = e.field<String>('title') ?? 'Untitled Signal';
    final creator = e.field<String>('creator_user_id') ?? '';
    final stance = e.field<String>('stance') ?? 'YES';
    final confidence = e.field<num>('confidence');
    final price = e.field<num>('price_usdc');

    // Signal publish = a creator is putting alpha on the market — pulse
    // from a creator node.
    _spawnPulse(
      amount: (price ?? 0).toDouble(),
      color: _pink, // creators are pink in the swarm viz
      isTrader: false,
    );

    final confStr = confidence != null ? ' ${(confidence * 100).round()}%' : '';
    _log(
      'SIGNAL PUBLISHED · ${stance.toUpperCase()}$confStr · ${_short(title, 48)}'
      '${creator.isNotEmpty ? ' by ${_shortAgentId(creator)}' : ''}',
      LogLevel.pay,
    );
  }

  void _onMarketResolved(PulsSocketEvent e) {
    final slug = e.field<String>('slug') ?? 'unknown';
    final outcome = e.field<bool>('outcome');
    final outcomeStr = outcome == null
        ? 'UNKNOWN'
        : (outcome ? 'YES' : 'NO');
    _log('MARKET RESOLVED · $slug → $outcomeStr', LogLevel.warn);
    // A resolution is dramatic — a small celebratory pulse + a soft shake.
    _spawnPulse(amount: 0.05, color: _amber);
    _shake(intensity: 6);
  }

  void _onMarketActivated(PulsSocketEvent e) {
    final slug = e.field<String>('slug') ?? 'unknown';
    _log('MARKET LIVE · ${_short(slug, 40)}', LogLevel.ok);
  }

  void _onNotification(PulsSocketEvent e) {
    final type = e.field<String>('type') ?? '';
    final title = e.field<String>('title') ?? '';
    final message = e.field<String>('message') ?? '';

    // Agent decisions carry a JSON-encoded message. Parse out the action
    // for a richer log line; treat slashes / refunds / losses as ERR + shake.
    if (type == 'agent_decision') {
      String? action;
      String? reasoning;
      try {
        // Agent_decision messages are JSON-encoded; decode defensively.
        final decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic>) {
          action = decoded['action'] as String?;
          reasoning = decoded['reasoning'] as String?;
        }
      } catch (_) {}

      final isSlash = _isNegativeAction(action, message, title);
      final level = isSlash ? LogLevel.err : LogLevel.info;
      final prefix = _agentActionLabel(action) ?? 'AGENT';
      _log(
        '$prefix · ${_short(title, 36)}'
        '${reasoning != null ? ' · ${_short(reasoning, 50)}' : ''}',
        level,
      );
      if (isSlash) _shake();
    } else if (type == 'trade') {
      // Skip — already covered by trade:complete.
    } else if (type == 'resolution') {
      _log('RESOLUTION NOTIFY · ${_short(title, 40)}', LogLevel.warn);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _log(String message, LogLevel level) {
    if (!mounted) return;
    DecisionLogPanel.log(
      context,
      DecisionLog(message: message, level: level, timestamp: DateTime.now()),
    );
  }

  void _spawnPulse({
    required double amount,
    required Color color,
    bool isTrader = true,
  }) {
    if (!mounted) return;
    // The swarm viz has fixed node IDs (vega, cygnus, orion, lyra, sage, nova).
    // Pick a pseudo-random pair based on the event payload so a single event
    // always produces the same pulse (idempotent on replay).
    final pick = (amount * 1000).toInt().abs();
    final fromPool = isTrader
        ? const ['vega', 'cygnus', 'orion', 'lyra']
        : const ['sage', 'nova'];
    final toPool = isTrader
        ? const ['sage', 'nova']
        : const ['vega', 'cygnus', 'orion', 'lyra'];
    final from = fromPool[pick % fromPool.length];
    final to = toPool[(pick ~/ 7) % toPool.length];
    SwarmVisualizer.addPulse(
      context,
      SwarmPulse(
        from: from,
        to: to,
        amountUsdc: amount > 0 ? amount : 0.01 + _rnd.nextDouble() * 0.5,
        color: color,
        speed: 0.8 + _rnd.nextDouble() * 0.6,
      ),
    );
  }

  void _shake({double intensity = 14}) {
    if (!mounted) return;
    triggerCameraShake(context, intensity: intensity);
  }

  static bool _isAgent(String? userId) =>
      userId != null && userId.startsWith('agent_');

  static String _fmtUsd(num n) {
    final d = n.toDouble().abs();
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}k';
    return d.toStringAsFixed(d < 1 ? 4 : 2);
  }

  static String _short(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  static String _shortAgentId(String id) {
    if (id.length <= 14) return id;
    return '${id.substring(0, 11)}…';
  }

  static bool _isNegativeAction(String? action, String message, String title) {
    final hay = '${action ?? ''} $message $title'.toLowerCase();
    return hay.contains('slash') ||
        hay.contains('fail') ||
        hay.contains('lost') ||
        hay.contains('refund') ||
        hay.contains('error') ||
        hay.contains('denied');
  }

  static String? _agentActionLabel(String? action) {
    if (action == null) return null;
    switch (action) {
      case 'go':
        return 'AGENT TRADE';
      case 'comment':
        return 'AGENT COMMENT';
      case 'stream':
        return 'AGENT STREAM';
      case 'stream_skip':
        return 'AGENT STREAM SKIP';
      case 'create_market':
        return 'AGENT CREATE MARKET';
      case 'director_refund':
        return 'AGENTBOND REFUND';
      default:
        return 'AGENT ${action.toUpperCase()}';
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

