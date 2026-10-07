# ScoreCast Backend (ASP.NET Core)

The single consumer of the free sports API. Polls → detects changes → fans out via FCM.
Clients never call a sports API; they pull `/api/matches` on launch and ride FCM after.

```
backend/
  ScoreCast.Contracts/        # the frozen model from Step 1 (shared project)
  ScoreCast.Server/
    Ingestion/                # ISportsSource + football-data.org adapter + registry
    Sync/                     # cache, change detector, adaptive background loop
    Push/                     # FCM topic/condition fan-out
    Program.cs                # DI + REST endpoints for the app
    appsettings.json
```

## Run it

1. **Free key:** register at football-data.org, put the key in
   `appsettings.json` → `Sources:FootballDataOrg:ApiKey`.
2. **FCM:** in the Firebase console create a project, download a **service-account JSON**,
   save it as `ScoreCast.Server/firebase-service-account.json` (path set in `Fcm:ServiceAccountPath`).
3. Build & run:
   ```bash
   cd backend
   dotnet run --project ScoreCast.Server
   ```
4. Verify:
   ```bash
   curl http://localhost:5000/api/health
   curl "http://localhost:5000/api/matches?status=live"
   ```

The sync loop logs each tick; on a live-match day you'll see `FCM score <match> -> <msgId>` lines.

## How the fan-out scales

Clients subscribe (client-side, Step 5) to topics for what they follow:
`team_<id>`, `league_<id>`, and `match_<id>` for pinned matches. The server sends one
message per changed match with a condition OR-ing those topics. **One goal = one send**,
whether 10 or 100,000 people follow it. No per-user loop, no device-token registry.

## About "tested and working 100%"

I can't compile/run this inside the chat (no .NET SDK + network there), so treat this as a
**reference implementation to run and verify locally.** The one piece that's pure logic and
should be covered by fast unit tests is `ChangeDetector` — it decides every push:

```csharp
// xUnit sketch — add a ScoreCast.Server.Tests project:
[Fact] public void Score_change_emits_notifying_event() {
    var prev = Sample(home: 0, away: 0, MatchStatus.Live);
    var next = Sample(home: 1, away: 0, MatchStatus.Live);
    var ev = ChangeDetector.Detect(prev, next);
    Assert.Equal(ChangeType.Score, ev!.Type);
    Assert.True(ev.Notify);
}
[Fact] public void Identical_poll_emits_nothing() {
    var m = Sample(0, 0, MatchStatus.Live);
    Assert.Null(ChangeDetector.Detect(m, m));
}
```

The network-dependent parts (the football-data adapter, FCM send) are verified by running
against your real free key and a test device — those can't be unit-tested without mocking the
providers, and mocked tests wouldn't prove the live integration anyway.

## Swapping / adding free sources

Write a new `ISportsSource`, register it in `Program.cs`, add its leagues to the registry.
Nothing in the app, widget, or contract changes. That's the insurance policy against a free
source changing or dying.
```
