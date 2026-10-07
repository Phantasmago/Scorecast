import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'data/deep_links.dart';
import 'data/fcm_service.dart';
import 'data/notifications.dart';
import 'router.dart';
import 'state/app_state.dart';

// Point this at your running Step-2 backend.
const kBackendBaseUrl = 'http://10.0.2.2:5000'; // 10.0.2.2 = host machine from Android emulator

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(); // requires flutterfire-generated config / google-services.json
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Notifications.init();

  final api = ApiClient(baseUrl: kBackendBaseUrl);
  final fcm = FcmService();
  await fcm.init();

  final state = AppState(api: api, fcm: fcm);
  final router = buildRouter(state);

  // Catch app://match/{id} taps coming from the home-screen widget.
  await DeepLinks(router).init();

  runApp(ScoreCastApp(state: state, router: router));
}

class ScoreCastApp extends StatelessWidget {
  final AppState state;
  final GoRouter router;
  const ScoreCastApp({super.key, required this.state, required this.router});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp.router(
        title: 'ScoreCast',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFFE11D48), useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: const Color(0xFFE11D48), brightness: Brightness.dark, useMaterial3: true),
        routerConfig: router,
      ),
    );
  }
}
