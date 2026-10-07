using ScoreCast.Contracts;

namespace ScoreCast.Server.Sync;

public enum ChangeType { New, Score, Status, Schedule }

/// <summary>A meaningful change worth pushing. `Notify` = also raise a user notification.</summary>
public sealed record ChangeEvent(ChangeType Type, MatchDto Match, bool Notify);

/// <summary>
/// The gate that stops us spamming FCM. Only score changes, status transitions,
/// and new/rescheduled matches produce events — identical polls produce nothing.
/// Pure + static so it's trivially unit-testable (see README test notes).
/// </summary>
public static class ChangeDetector
{
    public static ChangeEvent? Detect(MatchDto? previous, MatchDto incoming)
    {
        if (previous is null)
        {
            // Brand-new match we've never seen. Only notify if it's already live.
            return new ChangeEvent(ChangeType.New, incoming, Notify: incoming.Status == MatchStatus.Live);
        }

        // Score change — the money event (a goal, a basket). Always notify.
        if (previous.Score.Home != incoming.Score.Home ||
            previous.Score.Away != incoming.Score.Away ||
            previous.Score.DisplayScore != incoming.Score.DisplayScore)
        {
            return new ChangeEvent(ChangeType.Score, incoming, Notify: true);
        }

        // Status transition — kickoff, half-time, full-time, postponement.
        if (previous.Status != incoming.Status)
        {
            // Notify on the ones users care about; stay quiet on e.g. Upcoming->Unknown noise.
            var notify = incoming.Status is MatchStatus.Live or MatchStatus.Finished;
            return new ChangeEvent(ChangeType.Status, incoming, notify);
        }

        // Kickoff time moved (rescheduled). Silent widget update, no notification.
        if (previous.StartTimeUtc != incoming.StartTimeUtc)
        {
            return new ChangeEvent(ChangeType.Schedule, incoming, Notify: false);
        }

        // Clock ticked ("77'" -> "78'") but nothing material changed: refresh the widget
        // silently so the minute stays current, but don't notify.
        if (previous.ClockLabel != incoming.ClockLabel && incoming.Status == MatchStatus.Live)
        {
            return new ChangeEvent(ChangeType.Schedule, incoming, Notify: false);
        }

        return null; // nothing changed -> no push, no work
    }

    /// <summary>Maps a ChangeType to the FCM payload `type` string from the contract.</summary>
    public static string ToPushType(ChangeType t) => t switch
    {
        ChangeType.Score                        => "score",
        ChangeType.Status                       => "status",
        ChangeType.New or ChangeType.Schedule   => "schedule",
        _                                        => "status"
    };
}
