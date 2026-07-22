import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A single log line in the terminal feed.
class DecisionLog {
  DecisionLog({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  final String message;
  final LogLevel level; // INFO / WARN / ERR / OK / PAY
  final DateTime timestamp;

  String get timeStr {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

enum LogLevel { info, warn, err, ok, pay }

/// A running terminal panel that streams agent decision logs in real time.
/// Black background, monospace neon-green/orange text — the Bloomberg
/// terminal aesthetic. Auto-scrolls to the latest line.
///
/// Performance:
///   - Uses a fixed-size ring buffer (default 200 lines) so memory stays
///     bounded over a long demo.
///   - The [ListView.builder] only builds visible lines.
///   - A [ScrollController] with `keepAlive: false` keeps off-screen lines
///     eligible for GC.
class DecisionLogPanel extends StatefulWidget {
  const DecisionLogPanel({
    super.key,
    this.title = 'AGENT DECISION STREAM',
    this.maxLines = 200,
    this.autoScroll = true,
    this.stream,
    this.demo = false,
    this.initialLogs = const [],
  });

  final String title;
  final int maxLines;
  final bool autoScroll;

  /// Optional external stream of logs to subscribe to (production wiring).
  /// When null + [demo] is true, the panel runs in demo mode (generates
  /// sample lines on a timer). When null + [demo] is false, the panel is
  /// empty and waits for real events via [DecisionLogPanel.log()].
  final Stream<DecisionLog>? stream;

  /// When true, generates demo log lines on a timer (for standalone preview).
  /// When false (default), the panel only shows real events pushed via log().
  final bool demo;

  /// Initial log entries to seed the panel with (e.g. historical agent
  /// decisions loaded from the backend). These are added once in initState.
  final List<DecisionLog> initialLogs;

  /// Push a log line programmatically (e.g. from an event-bus listener).
  static void log(BuildContext context, DecisionLog entry) {
    final state = context.findAncestorStateOfType<_DecisionLogPanelState>();
    state?._append(entry);
  }

  @override
  State<DecisionLogPanel> createState() => _DecisionLogPanelState();
}

class _DecisionLogPanelState extends State<DecisionLogPanel> {
  final ScrollController _scrollCtrl = ScrollController();
  final List<DecisionLog> _logs = [];
  Timer? _demoTimer;
  StreamSubscription<DecisionLog>? _sub;

  // Brand-aligned neon palette.
  static const _bg = Color(0xFF000000);
  static const _surface = Color(0xFF05080F);
  static const _border = Color(0xFF1B2236);
  static const _mint = Color(0xFF2DD4BF);
  static const _pink = Color(0xFFEC4899);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _textDim = Color(0xFF5E6A85);

  static const _demoLines = <(String, LogLevel)>[
    ('SCANNING SOURCES...', LogLevel.info),
    ('TAVILY → 4 HITS', LogLevel.ok),
    ('SERPER → 7 HITS', LogLevel.ok),
    ('EVALUATING EDGE...', LogLevel.info),
    ('LLM: gpt-oss → CONVICTION 0.73', LogLevel.info),
    ('x402 PAYMENT SENT: \$0.05', LogLevel.pay),
    ('SIGNAL UNLOCKED', LogLevel.ok),
    ('AGENTBOND STAKED: \$0.10', LogLevel.pay),
    ('EXECUTING TRADE: YES \$2.50', LogLevel.ok),
    ('REACTING TO HUMAN TRADE...', LogLevel.info),
    ('MARKET CREATED: agent-vega-…', LogLevel.ok),
    ('BOND RETURNED: +\$0.10', LogLevel.ok),
    ('BOND SLASHED: -\$0.10', LogLevel.err),
    ('STREAM OPENED @ \$0.004/s', LogLevel.pay),
    ('STREAM STOPPED: \$0.012', LogLevel.warn),
    ('DUEL MATCHED vs Cygnus', LogLevel.info),
    ('DUEL SETTLED: WON', LogLevel.ok),
    ('PORTFOLIO REVIEW: EXIT YES', LogLevel.warn),
  ];

  @override
  void initState() {
    super.initState();
    // Seed with initial logs (from backend) or demo lines.
    if (widget.initialLogs.isNotEmpty) {
      _logs.addAll(widget.initialLogs);
    } else if (widget.demo) {
      for (var i = 0; i < 8; i++) {
        _logs.add(_demoLine(i));
      }
    }
  }

  @override
  void didUpdateWidget(DecisionLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent passes updated initialLogs (e.g. after an async API
    // call completes), merge any NEW logs that aren't already in the panel.
    // Without this, the panel keeps its initial empty list forever — the
    // parent's setState updates the constructor arg but the State already
    // captured the old empty list in initState.
    if (widget.initialLogs.length > oldWidget.initialLogs.length) {
      final existing = _logs.toSet();
      for (final log in widget.initialLogs) {
        if (!existing.contains(log)) {
          _logs.add(log);
        }
      }
      if (_logs.length > widget.maxLines) {
        _logs.removeRange(0, _logs.length - widget.maxLines);
      }
      if (widget.autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients && mounted) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.stream != null && _sub == null) {
      _sub = widget.stream!.listen((log) => _append(log));
    } else if (widget.stream == null && widget.demo && _demoTimer == null) {
      _demoTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (!mounted) return;
        _append(_demoLine(_logs.length));
      });
    }
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _sub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _append(DecisionLog entry) {
    if (!mounted) return;
    setState(() {
      _logs.add(entry);
      if (_logs.length > widget.maxLines) {
        _logs.removeRange(0, _logs.length - widget.maxLines);
      }
    });
    if (widget.autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients && mounted) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  DecisionLog _demoLine(int seed) {
    final (msg, level) = _demoLines[seed % _demoLines.length];
    return DecisionLog(
      message: msg,
      level: level,
      timestamp: DateTime.now(),
    );
  }

  Color _levelColor(LogLevel l) {
    switch (l) {
      case LogLevel.info:
        return _textDim;
      case LogLevel.ok:
        return _mint;
      case LogLevel.warn:
        return _amber;
      case LogLevel.err:
        return _red;
      case LogLevel.pay:
        return _pink;
    }
  }

  String _levelLabel(LogLevel l) {
    switch (l) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.ok:
        return ' OK ';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.err:
        return 'ERR ';
      case LogLevel.pay:
        return 'PAY ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Terminal header bar ──────────────────────────────────
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: _surface,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _mint,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _mint, blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: _mint,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: _red,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          // ── Scrollable log feed ───────────────────────────────────
          Expanded(
            child: Container(
              color: _bg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _logs.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, i) {
                  final log = _logs[i];
                  final levelColor = _levelColor(log.level);
                  return _LogLine(
                    log: log,
                    levelColor: levelColor,
                    levelLabel: _levelLabel(log.level),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single monospace log line with timestamp + level tag + message.
/// Extracted as a const-friendly widget so the ListView can cheaply rebuild
/// individual lines without re-evaluating the whole panel.
class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.log,
    required this.levelColor,
    required this.levelLabel,
  });

  final DecisionLog log;
  final Color levelColor;
  final String levelLabel;

  static const _textDim = Color(0xFF5E6A85);
  static const _textBright = Color(0xFFEAF0FF);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontFamily: PulsColors.fontMono,
            fontSize: 11,
            height: 1.45,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          children: [
            TextSpan(
              text: '${log.timeStr} ',
              style: const TextStyle(color: _textDim),
            ),
            TextSpan(
              text: '[$levelLabel] ',
              style: TextStyle(color: levelColor, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: log.message,
              style: const TextStyle(color: _textBright),
            ),
          ],
        ),
      ),
    );
  }
}
