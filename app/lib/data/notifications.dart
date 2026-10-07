import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a heads-up notification when an FCM push is flagged `notify == "true"`
/// (a goal, a final whistle). Silent widget-only updates don't call this.
class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'scorecast_goals',
    'Score updates',
    description: 'Goals and final results for your teams',
    importance: Importance.high,
  );

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> show(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scorecast_goals',
          'Score updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
