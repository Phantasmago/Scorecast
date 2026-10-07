using ScoreCast.Contracts;

namespace ScoreCast.Server.Ingestion;

/// <summary>One league the server polls, and which source serves it.</summary>
public sealed record TrackedLeague(string LeagueId, Sport Sport, string DisplayName);

/// <summary>
/// Picks the adapter for a given sport and exposes the list of leagues the
/// sync loop should poll. Register more adapters here as you add free sources;
/// routing stays declarative.
/// </summary>
public sealed class SportsSourceRegistry
{
    private readonly IReadOnlyList<ISportsSource> _sources;

    public SportsSourceRegistry(IEnumerable<ISportsSource> sources) => _sources = sources.ToList();

    /// <summary>First source that supports the sport. Extend to prefer by quality/quota.</summary>
    public ISportsSource? SourceFor(Sport sport) =>
        _sources.FirstOrDefault(s => s.SupportedSports.Contains(sport));

    /// <summary>
    /// Leagues to poll. Kept in config/code for v1; in production you'd derive this
    /// from the union of what your users actually follow (so you never burn quota on
    /// leagues nobody watches).
    /// </summary>
    public static IReadOnlyList<TrackedLeague> DefaultTrackedLeagues { get; } = new[]
    {
        new TrackedLeague("PL",  Sport.Football, "Premier League"),
        new TrackedLeague("PD",  Sport.Football, "La Liga"),
        new TrackedLeague("SA",  Sport.Football, "Serie A"),
        new TrackedLeague("BL1", Sport.Football, "Bundesliga"),
        new TrackedLeague("CL",  Sport.Football, "Champions League"),
    };
}
