using ScoreCast.Contracts;

namespace ScoreCast.Server.Ingestion;

/// <summary>
/// The ONLY thing the rest of the system knows about a data provider.
/// Every free source (football-data.org, SportScore, Highlightly, ...) implements
/// this and maps its wire format INTO MatchDto. When a free source changes its
/// shape or dies, you write/replace ONE class here — nothing else moves.
/// </summary>
public interface ISportsSource
{
    /// <summary>Stable id for logging/attribution, e.g. "football-data.org".</summary>
    string Name { get; }

    /// <summary>Which sports this source can serve. The registry routes by this.</summary>
    IReadOnlySet<Sport> SupportedSports { get; }

    /// <summary>
    /// Fetch and normalize the current matches for one competition/league.
    /// MUST return fully-normalized MatchDto objects (adapter owns clockLabel etc.).
    /// Should be defensive: a bad/empty upstream response returns an empty list,
    /// never throws for "no data".
    /// </summary>
    Task<IReadOnlyList<MatchDto>> GetMatchesAsync(string leagueId, CancellationToken ct);

    /// <summary>
    /// Rough cost in "upstream calls" of one GetMatchesAsync for quota accounting.
    /// football-data.org = 1 call/league; some sources batch many leagues in one call.
    /// </summary>
    int CallCostPerLeague => 1;
}
