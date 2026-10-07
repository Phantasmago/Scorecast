import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../contracts/models.dart';
import 'notifications.dart';
import 'widget_bridge.dart';

/// Must be a TOP-LEVEL function: FCM spins up a background isolate to run it when
/// the app is backgrounded/terminated. This is what updates the home-screen widget
/// with near-zero delay the moment a goal push arrives.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _applyPush(message);
}

Future<void> _applyPush(RemoteMessage message) async {
  final data = message.data;
  final matchJson = data['match'];
  if (matchJson == null) return;

  try {
    final match = SportMatch.fromJson(jsonDecode(matchJson) as Map<String, dynamic>);
    await WidgetBridge.mergeMatch(match); // updates prefs + re-renders widget

    if (data['notify'] == 'true') {
      await Notifications.init(); // idempotent; also covers the background isolate
      await Notifications.show(
        '${match.home.shortName} ${match.scoreText()} ${match.away.shortName}',
        '${match.leagueName} · ${match.displayStatus()}',
      );
    }
  } catch (_) {
    // Never throw out of a push handler.
  }
}

/// Foreground-side FCM wiring: permissions, topic subscriptions, live updates.
class FcmService {
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  /// Call once at startup (after Firebase.initializeApp and registering the bg handler).
  Future<void> init() async {
    await _fm.requestPermission();

    // Foreground data messages: update the widget + the in-app UI immediately.
    FirebaseMessaging.onMessage.listen(_applyPush);

    // User tapped a notification that opened the app — routing handled by the router
    // via the deep link carried in the payload (Step 5).
  }

  /// Subscribe to the topics for everything the user follows. The backend fans out
  /// by OR-ing these topics, so following a team = getting its pushes. (Step 2.)
  Future<void> syncSubscriptions({
    required List<String> teamIds,
    required List<String> leagueIds,
    required List<String> pinnedMatchIds,
  }) async {
    for (final id in teamIds) {
      await _fm.subscribeToTopic(_sanitize('team_$id'));
    }
    for (final id in leagueIds) {
      await _fm.subscribeToTopic(_sanitize('league_$id'));
    }
    for (final id in pinnedMatchIds) {
      await _fm.subscribeToTopic(_sanitize('match_$id'));
    }
  }

  Future<void> unsubscribeTeam(String id) => _fm.unsubscribeFromTopic(_sanitize('team_$id'));

  // Must mirror the backend's FcmPushService.Sanitize.
  String _sanitize(String topic) =>
      topic.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');
}
