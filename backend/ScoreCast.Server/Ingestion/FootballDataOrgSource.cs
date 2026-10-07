using System.Text.Json;
using System.Text.Json.Serialization;
using ScoreCast.Contracts;

namespace ScoreCast.Server.Ingestion;

/// <summary>
/// Free-forever adapter for https://www.football-data.org (v4 REST).
/// Free tier: 12 competitions, 10 calls/min, scores slightly delayed (good enough
/// with our ~45s live polling). Auth = X-Auth-Token header with a free key.
///
/// NOTE ON CLOCKLABEL: for LIVE/FINISHED we author the label here (the widget prints
/// it verbatim). For UPCOMING we emit "" and let the client format startTimeUtc in
/// the device's own timezone — the backend can't know the user's tz.
/// </summary>
public sealed class FootballDataOrgSource : ISportsSource
{
    private readonly IHttpClientFactory _httpFactory;
    private readonly ILogger<FootballDataOrgSource> _log;

    public string Name => "football-data.org";
    public IReadOnlySet<Sport> SupportedSports { get; } = new HashSet<Sport> { Sport.Football };

    public FootballDataOrgSource(IHttpClientFactory httpFactory, ILogger<FootballDataOrgSource> log)
    {
        _httpFactory = httpFactory;
        _log = log;
    }

    public async Task<IReadOnlyList<MatchDto>> GetMatchesAsync(string leagueId, CancellationToken ct)
    {
        try
        {
            // leagueId here is football-data's competition code, e.g. "PL", "BL1", "SA".
            var client = _httpFactory.CreateClient(nameof(FootballDataOrgSource));
            using var resp = await client.GetAsync($"competitions/{leagueId}/matches", ct);

            if (!resp.IsSuccessStatusCode)
            {
                _log.LogWarning("football-data {League} -> {Status}", leagueId, (int)resp.StatusCode);
                return Array.Empty<MatchDto>();
            }

            await using var stream = await resp.Content.ReadAsStreamAsync(ct);
            var payload = await JsonSerializer.DeserializeAsync<FdMatchesResponse>(stream, JsonOpts, ct);
            if (payload?.Matches is null) return Array.Empty<MatchDto>();

            var result = new List<MatchDto>(payload.Matches.Count);
            foreach (var m in payload.Matches)
            {
                var mapped = Map(m, leagueId);
                if (mapped is not null) result.Add(mapped);
            }
            return result;
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _log.LogError(ex, "football-data fetch failed for {League}", leagueId);
            return Array.Empty<MatchDto>();   // never break the sync loop on one bad source
        }
    }

    // --- normalization ------------------------------------------------------

    private static MatchDto? Map(FdMatch m, string leagueCode)
    {
        if (m.HomeTeam is null || m.AwayTeam is null) return null;

        var status = MapStatus(m.Status);
        var score = new ScoreDto
        {
            Home = m.Score?.FullTime?.Home,
            Away = m.Score?.FullTime?.Away
        };

        return new MatchDto
        {
            Id            = $"fd-{m.Id}",
            Sport         = Sport.Football,
            LeagueId      = leagueCode,
            LeagueName    = m.Competition?.Name ?? leagueCode,
            Status        = status,
            StartTimeUtc  = m.UtcDate ?? DateTimeOffset.UnixEpoch,
            Home          = MapTeam(m.HomeTeam),
            Away          = MapTeam(m.AwayTeam),
            Score         = score,
            ClockLabel    = BuildClockLabel(status, m),
            LastUpdatedUtc= DateTimeOffset.UtcNow
        };
    }

    private static TeamDto MapTeam(FdTeam t) => new()
    {
        Id        = t.Id?.ToString() ?? t.Name ?? "unknown",
        Name      = t.Name ?? "Unknown",
        ShortName = t.Tla ?? Abbreviate(t.ShortName ?? t.Name ?? "UNK"),
        CrestUrl  = t.Crest
    };

    private static MatchStatus MapStatus(string? s) => s switch
    {
        "SCHEDULED" or "TIMED"                 => MatchStatus.Upcoming,
        "IN_PLAY" or "PAUSED"                  => MatchStatus.Live,
        "FINISHED" or "AWARDED"                => MatchStatus.Finished,
        "POSTPONED" or "SUSPENDED" or "CANCELLED" => MatchStatus.Postponed,
        _                                      => MatchStatus.Unknown
    };

    /// <summary>Authoritative display string for live/finished; "" for upcoming (client formats tz).</summary>
    private static string BuildClockLabel(MatchStatus status, FdMatch m) => status switch
    {
        MatchStatus.Live     => m.Status == "PAUSED" ? "HT"
                                : m.Minute is int min ? $"{min}'"
                                : "LIVE",
        MatchStatus.Finished => "FT",
        MatchStatus.Postponed=> "PP",
        _                    => ""      // Upcoming: client renders localized kickoff from startTimeUtc
    };

    private static string Abbreviate(string name)
    {
        var parts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 1) return parts[0][..Math.Min(3, parts[0].Length)].ToUpperInvariant();
        return string.Concat(parts.Take(3).Select(p => p[0])).ToUpperInvariant();
    }

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        NumberHandling = JsonNumberHandling.AllowReadingFromString
    };

    // --- upstream DTOs (only the fields we use) ------------------------------
    private sealed record FdMatchesResponse([property: JsonPropertyName("matches")] List<FdMatch>? Matches);

    private sealed record FdMatch(
        [property: JsonPropertyName("id")]          long Id,
        [property: JsonPropertyName("utcDate")]     DateTimeOffset? UtcDate,
        [property: JsonPropertyName("status")]      string? Status,
        [property: JsonPropertyName("minute")]      int? Minute,
        [property: JsonPropertyName("competition")] FdCompetition? Competition,
        [property: JsonPropertyName("homeTeam")]    FdTeam? HomeTeam,
        [property: JsonPropertyName("awayTeam")]    FdTeam? AwayTeam,
        [property: JsonPropertyName("score")]       FdScore? Score);

    private sealed record FdCompetition([property: JsonPropertyName("name")] string? Name);

    private sealed record FdTeam(
        [property: JsonPropertyName("id")]        long? Id,
        [property: JsonPropertyName("name")]      string? Name,
        [property: JsonPropertyName("shortName")] string? ShortName,
        [property: JsonPropertyName("tla")]       string? Tla,     // 3-letter code, perfect for widget
        [property: JsonPropertyName("crest")]     string? Crest);

    private sealed record FdScore([property: JsonPropertyName("fullTime")] FdScoreLine? FullTime);
    private sealed record FdScoreLine(
        [property: JsonPropertyName("home")] int? Home,
        [property: JsonPropertyName("away")] int? Away);
}
