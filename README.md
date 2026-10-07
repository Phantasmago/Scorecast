# ScoreCast — live sports scores + native Android widgets

Flutter app · ASP.NET Core (C#) backend · Kotlin + Jetpack Glance widgets · FCM.
Android widgets only; iOS gets the app without a home-screen widget.

```
contracts/     Step 1 — the frozen data contract (source of truth)
backend/       Step 2 — C# ingestion + change detection + FCM fan-out
app/           Step 3 — Flutter app + the native bridge
android/       Step 4 + 5 — Glance widgets, WorkManager sync, deep links
```

## How a goal reaches your home screen

```
free sports API
      │  (one consumer: the backend polls, ~45s during live windows)
      ▼
C# backend ── ChangeDetector (only real changes) ── FCM topic fan-out
      │                                                   │ one send per match,
      │                                                   │ any number of users
      ▼                                                   ▼
GET /api/matches  (app launch / pull-to-refresh)   silent high-priority push
      │                                                   │
      ▼                                                   ▼
Flutter app ──► WidgetBridge ──► HomeWidgetPreferences ──► Glance widget re-render
                                        ▲
                WidgetSyncWorker (WorkManager, 15-min floor) writes here too
```

Two freshness paths, by design: **FCM** gives near-real-time goal updates; **WorkManager**
is the baseline that keeps the board current at Android's 15-minute background floor and
backs off to ~90 min (or on battery-saver) when nothing is live.

## The contracts that hold it together (don't let these drift)

| Contract | Defined in | Mirrored in |
|----------|-----------|-------------|
| `MatchDto`/`Team`/`Score` JSON | `contracts/SportContracts.cs` | `app/.../models.dart`, `android/.../WidgetModels.kt` |
| Shared prefs keys | `CONTRACT.md` §2 | `app/.../prefs_keys.dart`, `android/.../WidgetKeys.kt` |
| Shared store name | `HomeWidgetPreferences` | `WidgetKeys.PREFS_FILE` + home_widget plugin |
| Deep link `app://match/{id}` | `CONTRACT.md` §3 | widget `tapTo()`, Dart `DeepLinks`, manifest |
| FCM `data` payload | `CONTRACT.md` §4 | backend `FcmPushService`, Dart `fcm_service` |
| Widget receiver name | `com.scorecast.app.ScoreCastWidgetReceiver` | Dart `WidgetConfig`, Kotlin receiver |

## Assembly order

1. **Backend**: add a free football-data.org key + Firebase service-account JSON, `dotnet run`.
2. **Flutter**: `flutter create` a host project, drop in `app/lib/**` and `pubspec.yaml`,
   run `flutterfire configure`, `flutter pub get`.
3. **Android**: copy `android/app/src/main/kotlin/**` into the Flutter project's android module,
   add the `res/xml` + `res/values` files, merge `AndroidManifest_additions.xml`, apply the
   `gradle_snippets/README.md` deps. Same Firebase project as the backend.
4. Run the app, add the widget from the launcher, follow a team, watch a live match.

## Honest status (the "working 100%" question)

Everything here is a **reference implementation to run and verify locally** — I could not
compile Flutter, Android, or .NET in the environment this was written in. What that means
concretely:

- **Logic is reviewable and intended to compile** against the pinned versions; the thing
  most likely to need a nudge is **version compatibility** (Glance ↔ Kotlin ↔ Compose
  compiler; Flutter plugin majors). Run `flutter pub get`, `./gradlew :app:dependencies`,
  and `dotnet build` and resolve any drift.
- **The data layer can't be "never-breaks"** because it rides *free* third-party feeds.
  The adapter design means a changed/dead source is a one-class fix, not a rewrite — that's
  the realistic version of "always working" on a zero-budget data rule.
- **Unit-test the pure logic now**: `ChangeDetector` (backend) decides every push and needs
  no network to test — see `backend/README.md`.
- Known v1 simplifications, each noted at its site: team short-codes instead of remote crests
  on the widget; tennis/F1 ingested but not rendered as 2-team cards; onboarding catalog inlined.

## Multi-agent note

The tree now splits cleanly along the three seams you asked about at the start:
**backend/** , **app/** , and **android/** share only the contracts table above. With those
frozen (Step 1 did that), the three can be developed in parallel — e.g. three Claude Code
subagents or three people — without stepping on each other.
