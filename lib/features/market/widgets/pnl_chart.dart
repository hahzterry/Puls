import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Live P&L chart — fetches /api/agents/pnl and draws a multi-line chart
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
      final res = await http.get(Uri.parse('$backendUrl/api/agents/pnl')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final agents = (data['agents'] as List? ?? []).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _agents = agents.take(6).toList(); _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const _colors = [
    Color(0xFF2DD4BF), Color(0xFFEC4899), Color(0xFFA855F7),
    Color(0xFF06B6D4), Color(0xFFEAB308), Color(0xFF3B82F6),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F19),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('AGENT P&L',
                  style: TextStyle(color: Color(0xFF5E6A85), fontSize: 10, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1.5)),
              const Spacer(),
              if (_loading)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2DD4BF)))
              else
                Text('TOTAL: \$${(_agents.fold<double>(0, (s, a) => s + ((a['net'] as num?)?.toDouble() ?? 0))).toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
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
              final name = (e.value['agent'] as String? ?? 'agent').split('_').last;
              final net = (e.value['net'] as num?)?.toDouble() ?? 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${name.toUpperCase()} ${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(2)}',
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono)),
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
    final gridPaint = Paint()..color = const Color(0xFF1E293B)..strokeWidth = 0.5;
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
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY),
        Paint()..color = const Color(0xFF5E6A85)..strokeWidth = 0.5);

    final colors = [
      const Color(0xFF2DD4BF), const Color(0xFFEC4899), const Color(0xFFA855F7),
      const Color(0xFF06B6D4), const Color(0xFFEAB308), const Color(0xFF3B82F6),
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
          RRect.fromRectAndRadius(Rect.fromLTWH(x, zeroY - barH, w, barH), const Radius.circular(2)),
          Paint()..color = color,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, zeroY, w, barH), const Radius.circular(2)),
          Paint()..color = color.withValues(alpha: 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PnlPainter old) => old.agents != agents;
}
