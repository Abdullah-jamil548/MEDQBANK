import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';

typedef TokenGetter = String? Function();

/// Persistent WebSocket for chat + friend events.
class RealtimeClient extends ChangeNotifier {
  RealtimeClient({required TokenGetter getToken}) : _getToken = getToken;

  final TokenGetter _getToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnect;
  Timer? _ping;
  bool _wanted = false;
  bool _connecting = false;
  bool connected = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isStarted => _wanted;

  /// Send a JSON frame to the server (typing, delivery ack, etc.).
  void sendJson(Map<String, dynamic> payload) {
    if (!connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (_) {
      _handleDrop();
    }
  }

  /// Idempotent: safe to call on every Provider rebuild.
  void start() {
    _wanted = true;
    if (connected || _connecting || _channel != null) return;
    _connect();
  }

  void stop() {
    _wanted = false;
    _connecting = false;
    _reconnect?.cancel();
    _reconnect = null;
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (connected) {
      connected = false;
      notifyListeners();
    } else {
      connected = false;
    }
  }

  Future<void> _connect() async {
    final token = _getToken();
    if (!_wanted || token == null || token.isEmpty) return;
    if (_connecting) return;

    _connecting = true;
    _reconnect?.cancel();

    _sub?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    final uri = Uri.parse(ApiConfig.wsUrl).replace(
      queryParameters: {'token': token},
    );

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // Wait until the socket is ready (fails fast if server rejects).
      await channel.ready.timeout(const Duration(seconds: 15));

      if (!_wanted) {
        await channel.sink.close();
        _connecting = false;
        return;
      }

      _sub = channel.stream.listen(
        (raw) {
          if (!connected) {
            connected = true;
            _connecting = false;
            notifyListeners();
          }
          try {
            final decoded = raw is String ? jsonDecode(raw) : raw;
            if (decoded is Map) {
              _events.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {
            // ignore malformed frames
          }
        },
        onError: (_) => _handleDrop(),
        onDone: _handleDrop,
        cancelOnError: true,
      );

      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {
          _handleDrop();
        }
      });

      // Mark connected even before first server frame (ready succeeded).
      if (!connected) {
        connected = true;
        _connecting = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Realtime WS connect failed: $e');
      _connecting = false;
      _channel = null;
      _scheduleReconnect();
    }
  }

  void _handleDrop() {
    final wasConnected = connected;
    connected = false;
    _connecting = false;
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    if (wasConnected) notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_wanted) return;
    if (_reconnect?.isActive ?? false) return;
    _reconnect = Timer(const Duration(seconds: 2), () {
      if (_wanted && !connected && !_connecting) {
        _connect();
      }
    });
  }

  @override
  void dispose() {
    stop();
    _events.close();
    super.dispose();
  }
}
