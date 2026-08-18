import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart' show backendUrl;

class LiveEvent {
  const LiveEvent({
    required this.type,
    required this.id,
    this.userId,
    this.side,
    this.amount,
    this.question,
    this.marketId,
    this.entryPrice,
    this.txHash,
    this.commentBody,
    this.isDuel = false,
    this.createdAt,
  });

  final String type; // 'trade' | 'comment' | 'connected'
  final String id;
  final String? userId;
  final String? side;
  final dynamic amount;
  final String? question;
  final String? marketId;
  final dynamic entryPrice;
  final String? txHash;
  final String? commentBody;
  final bool isDuel;
  final String? createdAt;

  factory LiveEvent.fromJson(String type, Map<String, dynamic> j) {
    return LiveEvent(
      type: type,
      id: j['id']?.toString() ?? '',
      userId: j['userId'] as String?,
      side: j['side'] as String?,
      amount: j['amount'],
      question: j['question'] as String?,
      marketId: j['marketId'] as String?,
      entryPrice: j['entryPrice'],
      txHash: j['txHash'] as String?,
      commentBody: j['body'] as String?,
      isDuel: j['isDuel'] == true,
      createdAt: j['createdAt'] as String?,
    );
  }
}

class LiveStreamService {
  LiveStreamService._();
  static final LiveStreamService instance = LiveStreamService._();

  final _controller = StreamController<LiveEvent>.broadcast();
  Stream<LiveEvent> get stream => _controller.stream;

  http.Client? _client;
  bool _running = false;
  Timer? _reconnectTimer;

  void start() {
    if (_running) return;
    _running = true;
    _connect();
  }

  void stop() {
    _running = false;
    _reconnectTimer?.cancel();
    _client?.close();
    _client = null;
  }

  void _connect() async {
    if (!_running) return;
    _client?.close();
    _client = http.Client();

    try {
      final request = http.Request('GET', Uri.parse('$backendUrl/api/trade/stream'));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);
      if (response.statusCode != 200) throw Exception('bad status ${response.statusCode}');

      String? currentEvent;
      StringBuffer dataBuffer = StringBuffer();

      response.stream
          .transform(const Utf8Decoder())
          .transform(const LineSplitter())
          .listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) {
            if (currentEvent != null && dataBuffer.isNotEmpty) {
              try {
                final json = jsonDecode(dataBuffer.toString()) as Map<String, dynamic>;
                _controller.add(LiveEvent.fromJson(currentEvent!, json));
              } catch (_) {}
            }
            currentEvent = null;
            dataBuffer.clear();
            return;
          }

          if (trimmed.startsWith('event:')) {
            currentEvent = trimmed.substring(6).trim();
          } else if (trimmed.startsWith('data:')) {
            dataBuffer.write(trimmed.substring(5).trim());
          }
        },
        onError: (err) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running) return;
    _client?.close();
    _client = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_running) _connect();
    });
  }
}
