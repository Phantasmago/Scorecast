using ScoreCast.Server.Ingestion;
using ScoreCast.Server.Push;

namespace ScoreCast.Server.Sync;

public sealed class SyncOptions
{
    /// <summary>Poll interval while at least one match is live.</summary>
    public int LiveIntervalSeconds { get; set; } = 45;
    /// <summary>Poll interval when nothing is live (just keeping schedules fresh).</summary>
    public int IdleIntervalSeconds { get; set; } = 3600;
    /// <summary>Pause between individual league calls, to stay under upstream rate limits
    /// (football-data free = 10 calls/min -> ~6s spacing is safe).</summary>
    public int PerLeagueDelayMs { get; set; } = 6500;
}

/// <summary>
/// The engine. On each tick it polls every tracked league through its adapter,
/// runs change detection against the cache, pushes only what changed, and then
/// sleeps for an interval that ADAPTS to whether anything is live.
///
/// This is the whole "free data behaves like real-time" story in one loop:
/// one backend, one quota, fan-out via FCM.
/// </summary>
public sealed class SyncHostedService : BackgroundService
{
    private readonly SportsSourceRegistry _registry;
    private readonly MatchCache _cache;
    private readonly IFcmPushService _push;
    private readonly SyncOptions _opts;
    private readonly ILogger<SyncHostedService> _log;

    public SyncHostedService(
        SportsSourceRegistry registry,
        MatchCache cache,
        IFcmPushService push,
        SyncOptions opts,
        ILogger<SyncHostedService> log)
    {
        _registry = registry;
        _cache = cache;
        _push = push;
        _opts = opts;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _log.LogInformation("Sync loop started.");
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunOnce(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _log.LogError(ex, "Sync tick failed; continuing.");
            }

            // Adaptive cadence: tight while live, relaxed when idle. Battery/quota win.
            var delay = _cache.AnyLive() ? _opts.LiveIntervalSeconds : _opts.IdleIntervalSeconds;
            _log.LogDebug("Next sync in {Delay}s (live={Live})", delay, _cache.AnyLive());
            await SafeDelay(TimeSpan.FromSeconds(delay), stoppingToken);
        }
    }

    private async Task RunOnce(CancellationToken ct)
    {
        foreach (var league in SportsSourceRegistry.DefaultTrackedLeagues)
        {
            var source = _registry.SourceFor(league.Sport);
            if (source is null)
            {
                _log.LogWarning("No source for {Sport}; skipping {League}", league.Sport, league.LeagueId);
                continue;
            }

            var matches = await source.GetMatchesAsync(league.LeagueId, ct);
            foreach (var incoming in matches)
            {
                var previous = _cache.TryGet(incoming.Id);
                var change = ChangeDetector.Detect(previous, incoming);

                _cache.Upsert(incoming);                 // cache always reflects latest

                if (change is not null)
                    await _push.PushAsync(change, ct);   // but we only push real changes
            }

            // Space calls out so we never trip the upstream rate limit.
            await SafeDelay(TimeSpan.FromMilliseconds(_opts.PerLeagueDelayMs), ct);
        }
    }

    private static async Task SafeDelay(TimeSpan d, CancellationToken ct)
    {
        try { await Task.Delay(d, ct); } catch (TaskCanceledException) { /* shutting down */ }
    }
}
