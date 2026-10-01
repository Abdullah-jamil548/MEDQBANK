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
  bool connected = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  void start() {
    _wanted = true;
    _connect();
  }

  void stop() {
    _wanted = false;
    _reconnect?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    connected = false;
    notifyListeners();
  }

  void _connect() {
    final token = _getToken();
    if (!_wanted || token == null || token.isEmpty) return;

    _sub?.cancel();
    _channel?.sink.close();

    final uri = Uri.parse(ApiConfig.wsUrl).replace(
      queryParameters: {'token': token},
    );

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        (raw) {
          if (!connected) {
            connected = true;
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
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {
          _scheduleReconnect();
        }
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    connected = false;
    notifyListeners();
    _ping?.cancel();
    if (!_wanted) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 2), _connect);
  }

  @override
  void dispose() {
    stop();
    _events.close();
    super.dispose();
  }
}
