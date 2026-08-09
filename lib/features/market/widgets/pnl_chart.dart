import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Live P&L chart вЂ” fetches /api/agents/pnl and draws a multi-line chart
/// of each agent's net PNL over time.
class PnlChart extends StatefulWidget {
  const PnlChart({super.key});

  @override
  State<PnlChart> createState() => _PnlChartState();
}

class _PnlChartState extends State<PnlChart> {
  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  void _fetch() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/agents/pnl'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final agents =
            (data['agents'] as List? ?? []).cast<Map<String, dynamic>>();
        if (mounted) {
          final next = agents.take(6).toList();
          if (_sameAgents(_agents, next)) return;
          setState(() {
            _agents = next;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Skips a rebuild when the polled payload is unchanged — the terminal's
  // ticker strip below repaints on every trade, so we never want to add a
  // whole-chart repaint on top for identical data.
  bool _sameAgents(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i]['agent'] ?? '') != (b[i]['agent'] ?? '')) return false;
      if ((a[i]['net'] as num?)?.toDouble() !=
          (b[i]['net'] as num?)?.toDouble()) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _colors = [
    PulsColors.brandMint,
    PulsColors.brandPink,
    Color(0xFFA855F7),
    Color(0xFF06B6D4),
    Color(0xFFEAB308),
    Color(0xFF3B82F6),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PulsColors.dark50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PulsColors.dark300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AGENT P&L',
                  style: TextStyle(
                      color: PulsColors.dark400,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono,
                      letterSpacing: 1.5)),
              const Spacer(),
              if (_loading)
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: PulsColors.brandMint))
              else
                Text(
                    'TOTAL: \$${(_agents.fold<double>(0, (s, a) => s + ((a['net'] as num?)?.toDouble() ?? 0))).toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: PulsColors.brandMint,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: PulsColors.fontMono)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PnlPainter(_agents),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: _agents.asMap().entries.map((e) {
              final color = _colors[e.key % _colors.length];
              final name =
                  (e.value['agent'] as String? ?? 'agent').split('_').last;
              final net = (e.value['net'] as num?)?.toDouble() ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(
                      '${name.toUpperCase()} ${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: PulsColors.fontMono)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PnlPainter extends CustomPainter {
  _PnlPainter(this.agents);
  final List<Map<String, dynamic>> agents;

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridPaint = Paint()
      ..color = PulsColors.dark300
      ..strokeWidth = 0.5;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Zero line
    final zeroY = size.height * 0.5;
    canvas.drawLine(
        Offset(0, zeroY),
        Offset(size.width, zeroY),
        Paint()
          ..color = PulsColors.dark400
          ..strokeWidth = 0.5);

    final colors = [
      PulsColors.brandMint,
      PulsColors.brandPink,
      const Color(0xFFA855F7),
      const Color(0xFF06B6D4),
      const Color(0xFFEAB308),
      const Color(0xFF3B82F6),
    ];

    // Draw a bar chart of net PNL per agent
    final n = agents.length;
    if (n == 0) return;

    final maxAbs = agents.fold<double>(0.01, (m, a) {
      final v = ((a['net'] as num?)?.toDouble() ?? 0).abs();
      return v > m ? v : m;
    });

    final barW = size.width / n;
    for (var i = 0; i < n; i++) {
      final net = (agents[i]['net'] as num?)?.toDouble() ?? 0;
      final barH = (net.abs() / maxAbs) * (size.height * 0.4);
      final x = i * barW + barW * 0.2;
      final w = barW * 0.6;
      final color = colors[i % colors.length];

      if (net >= 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, zeroY - barH, w, barH),
              const Radius.circular(2)),
          Paint()..color = color,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, zeroY, w, barH), const Radius.circular(2)),
          Paint()..color = color.withValues(alpha: 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PnlPainter old) => old.agents != agents;
}
