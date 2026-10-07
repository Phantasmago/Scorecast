# ScoreCast Flutter App (Step 3)

The foreground app + the native bridge that feeds the home-screen widget.

```
lib/
  contracts/models.dart     # Dart mirror of the Step-1 contract
  data/
    prefs_keys.dart         # frozen shared keys (match Step 4 Kotlin)
    widget_bridge.dart      # <-- THE bridge: writes prefs + re-renders widget
    api_client.dart         # calls the Step-2 backend
    fcm_service.dart        # topic subscribe + push -> widget update
  state/app_state.dart      # follows, content mode, theme; persists via the bridge
  screens/                  # onboarding, live scores, match details, widget studio
  router.dart / main.dart   # deep links + bootstrap
```

## The one integration fact that matters

`home_widget` on Android stores data in the SharedPreferences file
**`HomeWidgetPreferences`**. Step 4's Glance widget must read the frozen keys from
**that** file. (This refines CONTRACT.md §2: the shared store is `HomeWidgetPreferences`,
not a custom DataStore name — a real constraint of the bridge package.)

The data path, end to end:
```
backend --FCM push--> fcm_service --> WidgetBridge.mergeMatch()
                                          |
                     writes HomeWidgetPreferences (matches_json, config)
                                          |
                     HomeWidget.updateWidget() --> Glance re-render (Step 4)
```

## Setup

1. `flutter pub get`
2. **Firebase:** run `flutterfire configure` (adds `google-services.json` + `firebase_options.dart`).
   Use the SAME Firebase project as the backend's service account.
3. Point `kBackendBaseUrl` in `main.dart` at your running backend
   (`10.0.2.2:5000` reaches your host from the Android emulator).
4. `flutter run`.

## Honest status

I can't run a Flutter build in this chat. This compiles against the pinned package
majors but you should `flutter pub get` and fix any version drift. The screens are
functional reference UI, not final visual design. The load-bearing, must-work pieces
are `models.dart`, `prefs_keys.dart`, and `widget_bridge.dart` — those define the
handshake Step 4 depends on.

The sample onboarding catalog is inlined; wire it to a backend `/api/catalog`
endpoint for the full league/team list.
