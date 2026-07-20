import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Market resolution timeline — shows resolved markets with outcome,
/// timestamp, and which side (YES/NO) agents were on.
class ResolutionTimeline extends StatefulWidget {
  const ResolutionTimeline({super.key});

  @override
  State<ResolutionTimeline> createState() => _ResolutionTimelineState();
}

class _ResolutionTimelineState extends State<ResolutionTimeline> {
  List<Map<String, dynamic>> _resolved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/markets?limit=200')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final all = (data is List ? data : (data['markets'] as List? ?? []))
            .cast<Map<String, dynamic>>();
        final resolved = all.where((m) {
          final r = m['resolved'];
          return r == true || r == 'true';
        }).toList();
        if (mounted) setState(() { _resolved = resolved; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        border: Border.all(color: const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF05080F),
            child: Row(
              children: [
                const Text('MARKET RESOLUTION TIMELINE',
                    style: TextStyle(color: Color(0xFF5E6A85), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1.5)),
                const Spacer(),
                Text('${_resolved.length} RESOLVED',
                    style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 10, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2DD4BF)))
                : _resolved.isEmpty
                    ? Center(child: Text('No resolved markets', style: TextStyle(color: const Color(0xFF5E6A85), fontSize: 12, fontFamily: PulsColors.fontMono)))
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _resolved.length,
                        itemBuilder: (context, i) => _ResolutionRow(market: _resolved[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ResolutionRow extends StatelessWidget {
  const _ResolutionRow({required this.market});
  final Map<String, dynamic> market;

  @override
  Widget build(BuildContext context) {
    final outcome = market['outcome'];
    final isYes = outcome == true || outcome == 'true';
    final outcomeColor = isYes ? const Color(0xFF2DD4BF) : const Color(0xFFEC4899);
    final slug = (market['slug'] as String? ?? 'unknown');
    final question = slug.replaceAll('-', ' ');
    final q = question.length > 40 ? '${question.substring(0, 39)}…' : question;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF0A0E1A), width: 0.5))),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: outcomeColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(q,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFEAF0FF), fontSize: 10, fontFamily: PulsColors.fontMono)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: outcomeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(isYes ? 'YES' : 'NO',
                style: TextStyle(color: outcomeColor, fontSize: 10, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
          ),
        ],
      ),
    );
  }
}
