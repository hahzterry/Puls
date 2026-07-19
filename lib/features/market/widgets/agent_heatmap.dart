import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Agent activity heatmap — X axis = time buckets, Y axis = agents.
/// Cell intensity = number of trades/decisions in that time window.
class AgentHeatmap extends StatefulWidget {
  const AgentHeatmap({super.key});

  @override
  State<AgentHeatmap> createState() => _AgentHeatmapState();
}

class _AgentHeatmapState extends State<AgentHeatmap> {
  List<Map<String, dynamic>> _events = [];
  List<String> _agentNames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/agents/feed?limit=200')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final events = (data['events'] as List? ?? []).cast<Map<String, dynamic>>();
        final names = <String>{};
        for (final e in events) {
          final name = (e['agentName'] as String?) ?? 'Agent';
          names.add(name);
        }
        if (mounted) setState(() { _events = events; _agentNames = names.toList(); _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('AGENT ACTIVITY HEATMAP',
              style: TextStyle(color: Color(0xFF5E6A85), fontSize: 10, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2DD4BF)))
                : _agentNames.isEmpty
                    ? Center(child: Text('No activity data', style: TextStyle(color: const Color(0xFF5E6A85), fontSize: 12, fontFamily: PulsColors.fontMono)))
                    : RepaintBoundary(
                        child: CustomPaint(
                          painter: _HeatmapPainter(_events, _agentNames),
                          size: Size.infinite,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter(this.events, this.agentNames);
  final List<Map<String, dynamic>> events;
  final List<String> agentNames;

  @override
  void paint(Canvas canvas, Size size) {
    if (events.isEmpty || agentNames.isEmpty) return;

    // 12 time buckets (last 12 hours)
    final buckets = 12;
    final grid = List.generate(agentNames.length, (_) => List.filled(buckets, 0));
    final now = DateTime.now();

    for (final e in events) {
      final name = (e['agentName'] as String?) ?? 'Agent';
      final atStr = e['at'] as String? ?? '';
      if (atStr.isEmpty) continue;
      final at = DateTime.tryParse(atStr);
      if (at == null) continue;
      final hoursAgo = now.difference(at).inHours;
      if (hoursAgo < 0 || hoursAgo >= buckets) continue;
      final bucket = buckets - 1 - hoursAgo;
      final agentIdx = agentNames.indexOf(name);
      if (agentIdx >= 0 && agentIdx < grid.length) grid[agentIdx][bucket]++;
    }

    final maxVal = grid.fold<int>(0, (m, row) => row.fold(m, (mm, v) => v > mm ? v : mm)).clamp(1, 999);
    final cellW = size.width / buckets;
    final cellH = size.height / agentNames.length;
    final radius = math.min(cellW, cellH) * 0.35;

    for (var row = 0; row < agentNames.length; row++) {
      for (var col = 0; col < buckets; col++) {
        final val = grid[row][col];
        final intensity = val / maxVal;
        final x = col * cellW + cellW * 0.5;
        final y = row * cellH + cellH * 0.5;

        if (val > 0) {
          final color = Color.lerp(const Color(0xFF0C0F19), const Color(0xFF2DD4BF), intensity)!;
          canvas.drawCircle(Offset(x, y), radius * (0.3 + intensity * 0.7), Paint()..color = color);
        } else {
          canvas.drawCircle(Offset(x, y), radius * 0.2, Paint()..color = const Color(0xFF1E293B));
        }
      }
    }

    // Agent name labels (left side)
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < agentNames.length; i++) {
      final name = agentNames[i].split(' ').first;
      tp.text = TextSpan(
        text: name,
        style: const TextStyle(color: Color(0xFF9AA6C0), fontSize: 8, fontFamily: 'DM Sans', fontWeight: FontWeight.w600),
      );
      tp.layout();
      tp.paint(canvas, Offset(2, i * cellH + cellH * 0.5 - tp.height * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) => old.events != events;
}
