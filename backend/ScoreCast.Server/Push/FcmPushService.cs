using System.Text.Json;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using ScoreCast.Contracts;
using ScoreCast.Server.Sync;

namespace ScoreCast.Server.Push;

public interface IFcmPushService
{
    Task PushAsync(ChangeEvent change, CancellationToken ct);
}

/// <summary>
/// Fans a single changed match out to everyone who follows it, using FCM TOPICS.
///
/// The scaling trick: clients subscribe (client-side) to topics for the teams and
/// leagues they follow — e.g. "team_ars", "team_che", "league_PL". We send ONE
/// message with a CONDITION that ORs those topics together. FCM delivers it to every
/// subscribed device and dedupes per device. So a goal = one send regardless of
/// whether 10 or 100,000 people follow that match. No per-user loop, no token registry.
/// </summary>
public sealed class FcmPushService : IFcmPushService
{
    private readonly ILogger<FcmPushService> _log;
    private static readonly JsonSerializerOptions WireJson = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
    };

    public FcmPushService(IConfiguration cfg, ILogger<FcmPushService> log)
    {
        _log = log;

        // Initialize the Firebase app once from a service-account JSON.
        // Path comes from config / env (GOOGLE_APPLICATION_CREDENTIALS also works).
        if (FirebaseApp.DefaultInstance is null)
        {
            var credPath = cfg["Fcm:ServiceAccountPath"];
            var credential = !string.IsNullOrWhiteSpace(credPath) && File.Exists(credPath)
                ? GoogleCredential.FromFile(credPath)
                : GoogleCredential.GetApplicationDefault();

            FirebaseApp.Create(new AppOptions { Credential = credential });
        }
    }

    public async Task PushAsync(ChangeEvent change, CancellationToken ct)
    {
        var m = change.Match;

        // Topics this match belongs to (max 5 in an FCM condition; we use up to 4).
        var topics = new List<string>
        {
            $"team_{m.Home.Id}",
            $"team_{m.Away.Id}",
            $"league_{m.LeagueId}",
            $"match_{m.Id}"          // for Level-3 pinned individual matches
        };
        var condition = string.Join(" || ", topics.Select(t => $"'{Sanitize(t)}' in topics"));

        // The contract's ScoreUpdatePush, flattened into FCM's string-only data map.
        var data = new Dictionary<string, string>
        {
            ["type"]    = ChangeDetector.ToPushType(change.Type),
            ["matchId"] = m.Id,
            ["match"]   = JsonSerializer.Serialize(m, WireJson),
            ["notify"]  = change.Notify ? "true" : "false"
        };

        var message = new Message
        {
            Condition = condition,
            Data = data,
            // HIGH priority data message so it wakes the app in Doze and the widget
            // updates with near-zero delay. No `Notification` block -> stays silent;
            // the client decides whether to show one based on data["notify"].
            Android = new AndroidConfig { Priority = Priority.High }
        };

        try
        {
            var id = await FirebaseMessaging.DefaultInstance.SendAsync(message, ct);
            _log.LogInformation("FCM {Type} {Match} -> {MsgId}", change.Type, m.Id, id);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "FCM send failed for {Match}", m.Id);
            // swallow: a failed push must not kill the sync loop
        }
    }

    // FCM topic names allow [a-zA-Z0-9-_.~%]; team/league ids can contain other chars.
    private static string Sanitize(string topic) =>
        new string(topic.Select(c => char.IsLetterOrDigit(c) || c is '-' or '_' or '.' or '~' ? c : '_').ToArray());
}
