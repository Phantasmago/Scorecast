// =============================================================================
//  ScoreCast — Shared Data Contract (SOURCE OF TRUTH)
// =============================================================================
//  This file defines the normalized wire model that EVERY layer codes against:
//    - C# backend  : produces these DTOs, serializes to JSON.
//    - Flutter app : deserializes the identical JSON (mirror in Dart).
//    - Glance widget: reads a projection of this written into DataStore by the app.
//
//  RULE: No layer invents its own shape for a match/team/score. If the model
//  needs to change, it changes HERE first, then the Dart + Kotlin mirrors follow.
//
//  JSON convention: camelCase on the wire (see JsonNamingPolicy in Program.cs).
//  All timestamps are UTC ISO-8601. Clients localize for display only.
// =============================================================================

using System.Text.Json.Serialization;

namespace ScoreCast.Contracts;

// -----------------------------------------------------------------------------
//  Enums
// -----------------------------------------------------------------------------

/// <summary>
/// The sports the system understands. v1 WIDGET support is team-vs-team sports
/// (Football..IceHockey). Tennis and Motorsport are ingested + shown in-app but
/// are NOT rendered as 2-team score cards on the widget in v1 (see CONTRACT.md).
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum Sport
{
    Football,        // Soccer
    Basketball,      // NBA / EuroLeague
    AmericanFootball,// NFL
    Baseball,        // MLB
    IceHockey,       // NHL
    Tennis,          // in-app only in v1
    Cricket,
    Motorsport       // F1 — in-app only in v1
}

/// <summary>
/// Lifecycle of a single match. The widget picks its layout off this.
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MatchStatus
{
    Upcoming,  // scheduled, not started
    Live,      // in progress
    Finished,  // completed
    Postponed, // delayed / suspended / cancelled bucket
    Unknown
}

// -----------------------------------------------------------------------------
//  Core entities
// -----------------------------------------------------------------------------

/// <summary>A team (or participant). CrestUrl may be null; clients show initials.</summary>
public sealed record TeamDto
{
    [JsonPropertyName("id")]        public required string Id { get; init; }
    [JsonPropertyName("name")]      public required string Name { get; init; }
    /// <summary>Short/abbreviated form for tight widget cells, e.g. "ARS", "LAL".</summary>
    [JsonPropertyName("shortName")] public required string ShortName { get; init; }
    [JsonPropertyName("crestUrl")]  public string? CrestUrl { get; init; }
}

/// <summary>
/// Normalized score. home/away integers cover soccer, NBA, NFL, MLB, NHL.
/// displayScore carries sports where an int pair is wrong (tennis "6-4, 3-2").
/// For Upcoming matches both ints are null.
/// </summary>
public sealed record ScoreDto
{
    [JsonPropertyName("home")]         public int? Home { get; init; }
    [JsonPropertyName("away")]         public int? Away { get; init; }
    /// <summary>Optional override string for display when int pair is insufficient.</summary>
    [JsonPropertyName("displayScore")] public string? DisplayScore { get; init; }
}

/// <summary>A competition/league, e.g. Premier League, NBA.</summary>
public sealed record LeagueDto
{
    [JsonPropertyName("id")]      public required string Id { get; init; }
    [JsonPropertyName("sport")]   public required Sport Sport { get; init; }
    [JsonPropertyName("name")]    public required string Name { get; init; }
    [JsonPropertyName("logoUrl")] public string? LogoUrl { get; init; }
}

/// <summary>
/// THE central object. One normalized match, source-agnostic. Whatever free API
/// an adapter reads, it maps INTO this. Widget + app only ever see this shape.
/// </summary>
public sealed record MatchDto
{
    [JsonPropertyName("id")]        public required string Id { get; init; }
    [JsonPropertyName("sport")]     public required Sport Sport { get; init; }
    [JsonPropertyName("leagueId")]  public required string LeagueId { get; init; }
    [JsonPropertyName("leagueName")]public required string LeagueName { get; init; }

    [JsonPropertyName("status")]      public required MatchStatus Status { get; init; }
    [JsonPropertyName("startTimeUtc")]public required DateTimeOffset StartTimeUtc { get; init; }

    [JsonPropertyName("home")]  public required TeamDto Home { get; init; }
    [JsonPropertyName("away")]  public required TeamDto Away { get; init; }
    [JsonPropertyName("score")] public required ScoreDto Score { get; init; }

    /// <summary>
    /// Sport-agnostic status string the WIDGET prints verbatim. The adapter is
    /// responsible for producing the right thing per sport:
    ///   soccer "78'", basketball "Q3 2:15", "HT", "FT", "Final", upcoming "19:30".
    /// This is why the widget never needs sport-specific clock logic.
    /// </summary>
    [JsonPropertyName("clockLabel")] public required string ClockLabel { get; init; }

    /// <summary>True only while Status == Live. Drives the red "LIVE" dot.</summary>
    [JsonPropertyName("isLive")] public bool IsLive => Status == MatchStatus.Live;

    /// <summary>
    /// Optional sport-specific flags for the Match Details view (red cards, etc.).
    /// Free-form so the normalized core never bloats. Null/empty on the widget path.
    /// </summary>
    [JsonPropertyName("extras")] public Dictionary<string, string>? Extras { get; init; }

    /// <summary>Server stamp of last change — used for change-detection + "updated Xs ago".</summary>
    [JsonPropertyName("lastUpdatedUtc")] public required DateTimeOffset LastUpdatedUtc { get; init; }
}

// -----------------------------------------------------------------------------
//  FCM push payload (server -> client, silent high-priority data message)
// -----------------------------------------------------------------------------

/// <summary>
/// Sent in the FCM message `data` map (all values are strings on the wire; this
/// record documents the shape — see FcmPushService for the actual serialization).
/// The client uses `type` to decide whether to update the widget, notify, or both.
/// </summary>
public sealed record ScoreUpdatePush
{
    /// <summary>"score" | "status" | "schedule" — what changed.</summary>
    [JsonPropertyName("type")] public required string Type { get; init; }

    [JsonPropertyName("matchId")] public required string MatchId { get; init; }

    /// <summary>Full normalized match JSON so the client can update with zero extra fetch.</summary>
    [JsonPropertyName("match")] public required MatchDto Match { get; init; }

    /// <summary>True for events worth a heads-up notification (goal, final whistle).</summary>
    [JsonPropertyName("notify")] public bool Notify { get; init; }
}
