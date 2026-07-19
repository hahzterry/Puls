import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart' show backendUrl;
import '../../../core/theme/app_theme.dart';

/// Command bar — text input at the bottom of the terminal.
/// Sends questions to /api/agent/chat and displays the AI agent's response.
class CommandBar extends StatefulWidget {
  const CommandBar({super.key});

  @override
  State<CommandBar> createState() => _CommandBarState();
}

class _CommandBarState extends State<CommandBar> {
  final _ctrl = TextEditingController();
  final List<_ChatMsg> _messages = [];
  bool _sending = false;
  String _selectedAgent = 'vega';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_ChatMsg(text, true));
      _sending = true;
    });

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/agent/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text, 'agentKey': _selectedAgent}),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = (data['reply'] as String?) ?? 'No response';
        if (mounted) setState(() {
          _messages.add(_ChatMsg(reply, false));
          _sending = false;
        });
      } else {
        if (mounted) setState(() {
          _messages.add(_ChatMsg('Error: ${res.statusCode}', false));
          _sending = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _messages.add(_ChatMsg('Connection failed', false));
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF05080F),
        border: Border.all(color: const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF0C0F19),
            child: Row(
              children: [
                const Text('COMMAND',
                    style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 9, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono, letterSpacing: 1.5)),
                const SizedBox(width: 8),
                _agentSelector(),
                const Spacer(),
                if (_sending)
                  const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1, color: Color(0xFF2DD4BF))),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('Ask an agent anything…', style: TextStyle(color: const Color(0xFF5E6A85), fontSize: 11, fontFamily: PulsColors.fontMono)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _msg(_messages[i]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E293B)))),
            child: Row(
              children: [
                const Text('>', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 14, fontWeight: FontWeight.w900, fontFamily: PulsColors.fontMono)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Color(0xFFEAF0FF), fontSize: 12, fontFamily: PulsColors.fontMono),
                    decoration: const InputDecoration(
                      hintText: 'Why did Vega go YES on btc-100k?',
                      hintStyle: TextStyle(color: Color(0xFF5E6A85), fontSize: 11, fontFamily: PulsColors.fontMono),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2DD4BF), borderRadius: BorderRadius.circular(4)),
                    child: const Text('SEND', style: TextStyle(color: Color(0xFF000000), fontSize: 10, fontWeight: FontWeight.w900, fontFamily: PulsColors.fontMono, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _agentSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: const Color(0xFF2DD4BF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: DropdownButton<String>(
        value: _selectedAgent,
        underline: const SizedBox(),
        isDense: true,
        style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 9, fontWeight: FontWeight.w700, fontFamily: PulsColors.fontMono),
        dropdownColor: const Color(0xFF0C0F19),
        items: const [
          DropdownMenuItem(value: 'vega', child: Text('VEGA ⚡', style: TextStyle(fontSize: 9, fontFamily: PulsColors.fontMono))),
          DropdownMenuItem(value: 'cygnus', child: Text('CYGNUS 🛡️', style: TextStyle(fontSize: 9, fontFamily: PulsColors.fontMono))),
          DropdownMenuItem(value: 'orion', child: Text('ORION 🔭', style: TextStyle(fontSize: 9, fontFamily: PulsColors.fontMono))),
          DropdownMenuItem(value: 'atlas', child: Text('ATLAS 📈', style: TextStyle(fontSize: 9, fontFamily: PulsColors.fontMono))),
          DropdownMenuItem(value: 'nova', child: Text('NOVA 🌐', style: TextStyle(fontSize: 9, fontFamily: PulsColors.fontMono))),
          DropdownMenuItem(value: 'striker', child: Text('STRIKER ⚽', style: TextStyle(fontSize: 9, fontFamily: PulsColors.fontMono))),
        ],
        onChanged: (v) => setState(() => _selectedAgent = v ?? 'vega'),
      ),
    );
  }

  Widget _msg(_ChatMsg m) {
    final isUser = m.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: (isUser ? const Color(0xFFEC4899) : const Color(0xFF2DD4BF)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(isUser ? 'YOU' : _selectedAgent.toUpperCase(),
                style: TextStyle(color: isUser ? const Color(0xFFEC4899) : const Color(0xFF2DD4BF), fontSize: 8, fontWeight: FontWeight.w800, fontFamily: PulsColors.fontMono)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(m.text, style: const TextStyle(color: Color(0xFFEAF0FF), fontSize: 11, height: 1.4, fontFamily: PulsColors.fontMono))),
        ],
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg(this.text, this.isUser);
}
