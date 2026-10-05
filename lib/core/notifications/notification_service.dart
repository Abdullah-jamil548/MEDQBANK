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

  Future<void> showStudyAlert({
    required String title,
    required String body,
    bool penalty = false,
  }) async {
    if (!_ready || kIsWeb || !notificationsAllowed) return;
    final android = AndroidNotificationDetails(
      penalty ? 'medqbank_study_penalty' : 'medqbank_study_reward',
      penalty ? 'Study reminders' : 'Study rewards',
      channelDescription: penalty
          ? 'Penalties when you fall behind your study goal'
          : 'Rewards when you hit your study goal',
      importance: penalty ? Importance.max : Importance.high,
      priority: penalty ? Priority.max : Priority.high,
    );
    final details = NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000) + (penalty ? 7 : 3),
      title,
      body,
      details,
    );
  }

  /// Fire a burst of reminder notifications (penalty "bomb").
  Future<void> showPenaltyBomb({
    required String title,
    required String body,
    int count = 4,
  }) async {
    if (!_ready || kIsWeb || !notificationsAllowed) return;
    for (var i = 0; i < count; i++) {
      await showStudyAlert(
        title: i == 0 ? title : '$title (${i + 1})',
        body: body,
        penalty: true,
      );
      if (i < count - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
  }
}
