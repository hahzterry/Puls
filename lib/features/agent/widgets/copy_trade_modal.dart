import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/utils/kv_store.dart' show kvGet;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/puls_avatar.dart';
import '../../../core/widgets/puls_snack.dart';

class CopyTradeModal extends StatefulWidget {
  const CopyTradeModal({
    super.key,
    required this.leaderId,
    required this.leaderName,
    this.avatarUrl,
    this.role,
    this.strategy,
    this.winRate,
  });

  final String leaderId;
  final String leaderName;
  final String? avatarUrl;
  final String? role;
  final String? strategy;
  final int? winRate;

  static Future<void> show(
    BuildContext context, {
    required String leaderId,
    required String leaderName,
    String? avatarUrl,
    String? role,
    String? strategy,
    int? winRate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CopyTradeModal(
        leaderId: leaderId,
        leaderName: leaderName,
        avatarUrl: avatarUrl,
        role: role,
        strategy: strategy,
        winRate: winRate,
      ),
    );
  }

  @override
  State<CopyTradeModal> createState() => _CopyTradeModalState();
}

class _CopyTradeModalState extends State<CopyTradeModal> {
  double _amount = 2.0;
  bool _isFollowing = false;
  bool _loading = true;
  bool _submitting = false;

  Map<String, String> get _authHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final raw = kvGet('direct_auth');
      if (raw != null && raw.isNotEmpty) {
        final saved = jsonDecode(raw) as Map<String, dynamic>?;
        final token = saved?['token'] as String?;
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (_) {}
    return headers;
  }

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/copy/status?leaderUserId=${Uri.encodeComponent(widget.leaderId)}'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _isFollowing = data['following'] == true;
            if (data['maxPerTradeUsdc'] != null) {
              _amount = (data['maxPerTradeUsdc'] as num).toDouble();
            }
            _loading = false;
          });
        }
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleFollow() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final snack = PulsSnack.of(context);
    try {
      if (_isFollowing) {
        final res = await http.post(
          Uri.parse('$backendUrl/api/copy/unfollow'),
          headers: _authHeaders,
          body: jsonEncode({'leaderUserId': widget.leaderId}),
        );
        if (res.statusCode == 200) {
          setState(() => _isFollowing = false);
          snack.show('Unfollowed ${widget.leaderName}');
        } else {
          snack.show('Failed to unfollow');
        }
      } else {
        final res = await http.post(
          Uri.parse('$backendUrl/api/copy/follow'),
          headers: _authHeaders,
          body: jsonEncode({
            'leaderUserId': widget.leaderId,
            'maxPerTradeUsdc': _amount,
          }),
        );
        if (res.statusCode == 200) {
          setState(() => _isFollowing = true);
          snack.show('Now copying ${widget.leaderName} (Max \$$_amount/trade)!');
        } else {
          final err = jsonDecode(res.body)['error'] ?? 'Failed to follow';
          snack.show(err.toString());
        }
      }
    } catch (e) {
      snack.show('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: t.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  PulsAvatar(url: widget.avatarUrl, name: widget.leaderName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.leaderName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (widget.winRate != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: t.yes.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${widget.winRate}% Win',
                                  style: TextStyle(color: t.yes, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.role ?? 'Autonomous Swarm Agent',
                          style: TextStyle(color: t.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.strategy != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.bg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.border.withOpacity(0.5)),
                  ),
                  child: Text(
                    widget.strategy!,
                    style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.35),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Max Spend per Copied Trade (USDC)',
                style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [1.0, 2.0, 5.0, 10.0, 25.0].map((val) {
                  final sel = (_amount == val);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _amount = val),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? t.brand : t.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? t.brand : t.border),
                        ),
                        child: Center(
                          child: Text(
                            '\$${val.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: sel ? Colors.white : t.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading || _submitting ? null : _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFollowing ? t.no : t.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _isFollowing ? 'Stop Copying' : 'Start 1-Click Copy Trading',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
