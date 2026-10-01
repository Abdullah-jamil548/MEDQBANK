import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Local/system notifications for chat and friend requests.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool notificationsAllowed = false;

  Future<void> init() async {
    if (kIsWeb) {
      _ready = true;
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      notificationsAllowed = false;
      return false;
    }
    final status = await Permission.notification.request();
    notificationsAllowed = status.isGranted;
    if (notificationsAllowed) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
    return notificationsAllowed;
  }

  Future<void> showChatMessage({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready || kIsWeb || !notificationsAllowed) return;
    const android = AndroidNotificationDetails(
      'medqbank_chat',
      'Chat',
      channelDescription: 'Messages from friends',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showFriendRequest({
    required String title,
    required String body,
  }) async {
    if (!_ready || kIsWeb || !notificationsAllowed) return;
    const android = AndroidNotificationDetails(
      'medqbank_friends',
      'Friends',
      channelDescription: 'Friend requests',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000) + 1,
      title,
      body,
      details,
    );
  }
}
