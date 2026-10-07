using System.Collections.Concurrent;
using ScoreCast.Contracts;

namespace ScoreCast.Server.Sync;

/// <summary>
/// The server's live picture of the world. The sync loop writes here; the REST
/// API reads here. In-memory is fine for v1 (rebuilds from the API on restart);
/// swap for Redis if you run multiple instances.
/// </summary>
public sealed class MatchCache
{
    private readonly ConcurrentDictionary<string, MatchDto> _byId = new();

    public MatchDto? TryGet(string id) => _byId.TryGetValue(id, out var m) ? m : null;

    public void Upsert(MatchDto match) => _byId[match.Id] = match;

    public bool AnyLive() => _byId.Values.Any(m => m.Status == MatchStatus.Live);

    /// <summary>Filtered snapshot for GET /api/matches. All filters optional.</summary>
    public IReadOnlyList<MatchDto> Query(Sport? sport = null, MatchStatus? status = null, string? leagueId = null)
    {
        IEnumerable<MatchDto> q = _byId.Values;
        if (sport is not null)    q = q.Where(m => m.Sport == sport);
        if (status is not null)   q = q.Where(m => m.Status == status);
        if (leagueId is not null) q = q.Where(m => m.LeagueId == leagueId);

        // Live first, then soonest upcoming, then most-recently finished.
        return q.OrderByDescending(m => m.Status == MatchStatus.Live)
                .ThenBy(m => m.Status == MatchStatus.Upcoming ? m.StartTimeUtc : DateTimeOffset.MaxValue)
                .ThenByDescending(m => m.StartTimeUtc)
                .ToList();
    }
}
