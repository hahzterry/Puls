import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../config.dart' show backendUrl;

/// Canonical event types emitted by the backend (mirror of lib/events.js
/// EVENTS.* — kept in sync manually; a mismatch surfaces as a silent no-op
/// on the wire because the channel name won't match).
class PulsEventType {
  const PulsEventType._(this.name);
  final String name;

  static const tradeCreated = PulsEventType._('trade:created');
  static const tradeComplete = PulsEventType._('trade:complete');
  static const tradeFailed = PulsEventType._('trade:failed');
  static const marketCreated = PulsEventType._('market:created');
  static const marketActivated = PulsEventType._('market:activated');
  static const marketResolved = PulsEventType._('market:resolved');
  static const marketArchived = PulsEventType._('market:archived');
  static const walletCreated = PulsEventType._('wallet:created');
  static const walletBalanceChanged =
      PulsEventType._('wallet:balance_changed');
  static const signalPublished = PulsEventType._('signal:published');
  static const signalArchived = PulsEventType._('signal:archived');
  static const orderLimitPlaced = PulsEventType._('order:limit_placed');
  static const orderLimitFilled = PulsEventType._('order:limit_filled');
  static const orderLimitCancelled = PulsEventType._('order:limit_cancelled');
  static const commentCreated = PulsEventType._('comment:created');
  static const blogPublished = PulsEventType._('blog:published');
  static const notificationCreated = PulsEventType._('notification:created');

  /// All known event types — useful for diagnostics / a "subscribe to all"
  /// stream.
  static const all = <PulsEventType>[
    tradeCreated, tradeComplete, tradeFailed,
    marketCreated, marketActivated, marketResolved, marketArchived,
    walletCreated, walletBalanceChanged,
    signalPublished, signalArchived,
    orderLimitPlaced, orderLimitFilled, orderLimitCancelled,
    commentCreated, blogPublished, notificationCreated,
  ];

  @override
  String toString() => name;
}

/// One event on the wire. `type` is the canonical event name; `payload` is
/// the already-sanitized JSON object from the backend (Map<String, dynamic>).
@immutable
class PulsSocketEvent {
  const PulsSocketEvent({required this.type, required this.payload, required this.receivedAt});

  final String type; // matches PulsEventType.name
  final Map<String, dynamic> payload;
  final DateTime receivedAt;

  /// Convenience: parse a known field with a default.
  T? field<T>(String key) => payload[key] as T?;

  @override
  String toString() => 'PulsSocketEvent($type @ $receivedAt)';
}

/// Connection status of the WebSocket gateway.
enum SocketConnectionStatus { disconnected, connecting, connected, reconnecting, error }

/// Singleton service that connects to the backend Socket.IO gateway and
/// exposes a unified `Stream<PulsSocketEvent>` plus per-event filtered
/// streams.
///
/// Lifecycle:
///   - `WebSocketService.instance.connect()` once at app boot.
///   - `WebSocketService.instance.events` is a broadcast stream — many
///     listeners can subscribe; closing one doesn't affect others.
///   - `dispose()` tears down the socket + controllers. The singleton stays
///     usable; the next `connect()` re-creates the socket.
class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  sio.Socket? _socket;
  StreamController<PulsSocketEvent>? _eventsCtrl;
  StreamController<SocketConnectionStatus>? _statusCtrl;
  SocketConnectionStatus _status = SocketConnectionStatus.disconnected;

  /// The unified event stream. Subscribe once, dispatch by `event.type`.
  /// Broadcast stream → safe for multiple listeners.
  Stream<PulsSocketEvent> get events {
    _eventsCtrl ??= StreamController<PulsSocketEvent>.broadcast();
    return _eventsCtrl!.stream;
  }

  /// Connection status stream (disconnected → connecting → connected → …).
  Stream<SocketConnectionStatus> get status {
    _statusCtrl ??= StreamController<SocketConnectionStatus>.broadcast();
    return _statusCtrl!.stream;
  }

  SocketConnectionStatus get currentStatus => _status;

  /// Connect to the backend Socket.IO gateway. Idempotent — calling when
  /// already connected is a no-op.
  ///
  /// [backendUrlOverride] lets a caller point at a different origin (e.g.
  /// `http://localhost:3000` during local dev) without changing [config].
  void connect({String? backendUrlOverride}) {
    if (_socket != null) return;
    final uri = backendUrlOverride ?? backendUrl;
    _setStatus(SocketConnectionStatus.connecting);

    _socket = sio.io(
      uri,
      sio.OptionBuilder()
          .setTransports(['websocket']) // skip HTTP long-polling fallback
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(1000)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(10_000)
          .build(),
    );

    _socket!.onConnect((_) {
      _setStatus(SocketConnectionStatus.connected);
      debugPrint('[ws] connected to $uri');
    });

    _socket!.onDisconnect((reason) {
      _setStatus(SocketConnectionStatus.disconnected);
      debugPrint('[ws] disconnected: $reason');
    });

    _socket!.onConnectError((err) {
      _setStatus(SocketConnectionStatus.error);
      debugPrint('[ws] connect error: $err');
    });

    _socket!.onReconnect((attempt) {
      _setStatus(SocketConnectionStatus.reconnecting);
      debugPrint('[ws] reconnecting (attempt $attempt)');
    });

    // ── Subscribe to the unified `puls:event` channel ────────────────
    // The backend emits every event on BOTH its own channel (`trade:complete`,
    // etc.) AND a unified `puls:event` envelope. Subscribing to the envelope
    // here means we add one listener instead of 17, and new event types
    // flow through automatically.
    _socket!.on('puls:event', (data) {
      if (data is Map<String, dynamic>) {
        final type = data['type'] as String?;
        final payload = data['payload'];
        if (type == null) return;
        final event = PulsSocketEvent(
          type: type,
          payload: (payload is Map<String, dynamic>)
              ? payload
              : <String, dynamic>{'raw': payload},
          receivedAt: DateTime.now(),
        );
        _eventsCtrl?.add(event);
      } else if (data is String) {
        // Some Socket.IO client transports deliver strings; decode defensively.
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            _eventsCtrl?.add(PulsSocketEvent(
              type: decoded['type'] as String? ?? '',
              payload: (decoded['payload'] as Map?)?.cast<String, dynamic>() ?? {},
              receivedAt: DateTime.now(),
            ));
          }
        } catch (_) {}
      }
    });

    _socket!.connect();
  }

  /// Subscribe to a single event type. Convenience wrapper around [events].
  Stream<PulsSocketEvent> on(PulsEventType type) =>
      events.where((e) => e.type == type.name);

  /// Send a subscription request to join a per-user private room (the
  /// backend supports `subscribe:user` to receive targeted notifications
  /// without the global firehose).
  void subscribeToUser(String userId) {
    _socket?.emit('subscribe:user', userId);
  }

  void _setStatus(SocketConnectionStatus s) {
    _status = s;
    _statusCtrl?.add(s);
  }

  /// Tear down the socket + stream controllers. The singleton stays
  /// usable; call [connect] to re-establish.
  void dispose() {
    _socket?.dispose();
    _socket = null;
    _eventsCtrl?.close();
    _eventsCtrl = null;
    _statusCtrl?.close();
    _statusCtrl = null;
    _status = SocketConnectionStatus.disconnected;
  }
}
