# ScoreCast — Frozen Contract (Step 1)

This is the agreement every layer builds against. Lock it before fanning out.
If the three layers ever disagree, **this document wins** and the code is wrong.

Stack: **Flutter app · ASP.NET Core (C#) backend · Kotlin + Jetpack Glance widget · FCM**.
Android widgets only. iOS = app without home-screen widget.

---

## 1. The normalized match (wire JSON)

`SportContracts.cs` is the source of truth. On the wire it serializes to camelCase.
Example of a **live soccer** match exactly as the backend emits it and the app/widget consume it:

```json
{
  "id": "pl-2026-0412",
  "sport": "Football",
  "leagueId": "PL",
  "leagueName": "Premier League",
  "status": "Live",
  "startTimeUtc": "2026-10-06T18:30:00Z",
  "home": { "id": "ars", "name": "Arsenal", "shortName": "ARS", "crestUrl": "https://.../ars.png" },
  "away": { "id": "che", "name": "Chelsea", "shortName": "CHE", "crestUrl": "https://.../che.png" },
  "score": { "home": 2, "away": 1, "displayScore": null },
  "clockLabel": "78'",
  "isLive": true,
  "extras": { "homeRedCards": "1" },
  "lastUpdatedUtc": "2026-10-06T19:48:12Z"
}
```

**Rules that make the widget dumb (and therefore reliable):**
- `clockLabel` is produced by the backend adapter per sport (`"78'"`, `"Q3 2:15"`, `"HT"`, `"Final"`, or kickoff time for upcoming). The widget prints it verbatim — it owns **no** sport-specific clock logic.
- `isLive` drives the red dot. `status` drives which layout state renders.
- `score.home/away` are null for `Upcoming`. `displayScore` only used when an int pair is wrong (tennis).

### v1 scope decision
Widget renders team-vs-team sports: **Football, Basketball, AmericanFootball, Baseball, IceHockey.**
**Tennis** and **Motorsport (F1)** are ingested and shown **in-app only** in v1 (they don't fit a 2-team score card cleanly). The contract already carries them; the widget just skips them. This keeps "working 100%" honest instead of faking F1 onto a scoreboard.

---

## 2. App → Widget shared state (DataStore keys)

The Flutter app writes user config + a small match projection into the SAME
`Preferences DataStore` file the Glance widget reads. Keys are frozen here so the
Dart bridge and the Kotlin widget never drift.

DataStore name: **`scorecast_widget_prefs`**

| Key (string)              | Type   | Written by | Meaning |
|---------------------------|--------|-----------|---------|
| `content_mode`            | String | app       | `"auto"` or `"pinned"` |
| `pinned_team_id`          | String | app       | team id when `content_mode=pinned` |
| `theme`                   | String | app       | `"light"` \| `"dark"` \| `"system"` |
| `accent_color`            | String | app       | hex, e.g. `"#E11D48"` |
| `active_tab`              | String | widget/app| current filter tab: `"favorites"` \| `"soccer"` \| `"nba"` … |
| `favorite_team_ids`       | String | app       | JSON array of team ids |
| `matches_json`            | String | app       | JSON array of `MatchDto` (the projection the widget renders) |
| `last_sync_utc`           | String | app       | ISO-8601 of last successful sync |
| `refresh_mode`            | String | app       | `"realtime"` \| `"balanced"` \| `"battery"` |

> The widget never calls the network. It only ever reads `matches_json` + the config keys.
> Freshness comes from the app/WorkManager/FCM writing new `matches_json` then calling
> `GlanceAppWidgetManager(...).update()`.

---

## 3. Deep-link scheme

Single canonical form, handled by the Flutter router and emitted by widget taps:

```
app://match/{matchId}        -> opens Match Details view for that match
app://tab/{tabId}            -> opens the app on a given tab (optional)
```

Widget match-card tap → explicit Intent carrying `app://match/{id}` → Flutter
`onGenerateRoute` parses it → Match Details. Tab taps on the widget do NOT open the
app; they only rewrite the `active_tab` DataStore key and re-render the widget.

---

## 4. FCM payload (silent data push)

High-priority **data** message (not notification-only, so it arrives in Doze).
All `data` values are strings. `match` is the stringified `MatchDto` JSON from §1.

```json
{
  "data": {
    "type": "score",            // "score" | "status" | "schedule"
    "matchId": "pl-2026-0412",
    "match": "{...MatchDto JSON...}",
    "notify": "true"
  },
  "android": { "priority": "high" }
}
```

Client handler: parse `match` → overwrite that entry in `matches_json` → call widget
`update()`. If `notify == "true"`, also post a local notification. Covered in Step 5.

---

## 5. Data sourcing (the "0 payment" architecture)

- Backend is the **single consumer** of the free API quota. Clients never call sports APIs.
- Ingestion is **adapter-based**: `ISportsSource` with one implementation per free provider.
  Swapping a dead/changed free source = new adapter, no change to app/widget/contract.
- Planned free adapters: `FootballDataOrgSource` (free-forever leagues/tables, delayed),
  `SportScoreSource` (~10k req/day, attribution link required), optional `HighlightlySource`
  (US sports, ~100 req/day — cached hard). Latency target ~30–60s during live windows.
- Attribution: if SportScore is used, a visible "Powered by SportScore" link is required
  by its free terms — must appear on any screen rendering its data.

---

## Frozen list (don't change without updating this file)
1. `MatchDto` / `TeamDto` / `ScoreDto` / `LeagueDto` shape + camelCase JSON.
2. `Sport` + `MatchStatus` enum string values.
3. DataStore name + all keys in §2.
4. Deep-link scheme §3.
5. FCM `data` shape §4.
