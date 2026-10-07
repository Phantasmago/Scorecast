package com.scorecast.app

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Kotlin mirror of ScoreCast.Contracts (Step 1). The @SerialName values match the
 * C# string enums on the wire ("Football", "Live", ...). The widget only ever reads
 * this shape; it never talks to a network or a sports API.
 */

@Serializable
enum class Sport {
    @SerialName("Football") FOOTBALL,
    @SerialName("Basketball") BASKETBALL,
    @SerialName("AmericanFootball") AMERICAN_FOOTBALL,
    @SerialName("Baseball") BASEBALL,
    @SerialName("IceHockey") ICE_HOCKEY,
    @SerialName("Tennis") TENNIS,
    @SerialName("Cricket") CRICKET,
    @SerialName("Motorsport") MOTORSPORT;

    /** Sports rendered as 2-team cards on the widget in v1 (see CONTRACT.md). */
    val widgetSupported: Boolean
        get() = this != TENNIS && this != MOTORSPORT
}

@Serializable
enum class MatchStatus {
    @SerialName("Upcoming") UPCOMING,
    @SerialName("Live") LIVE,
    @SerialName("Finished") FINISHED,
    @SerialName("Postponed") POSTPONED,
    @SerialName("Unknown") UNKNOWN
}

@Serializable
data class WidgetTeam(
    val id: String,
    val name: String,
    val shortName: String,
    val crestUrl: String? = null
)

@Serializable
data class WidgetScore(
    val home: Int? = null,
    val away: Int? = null,
    val displayScore: String? = null
)

@Serializable
data class WidgetMatch(
    val id: String,
    val sport: Sport,
    val leagueId: String,
    val leagueName: String,
    val status: MatchStatus,
    val startTimeUtc: String,
    val home: WidgetTeam,
    val away: WidgetTeam,
    val score: WidgetScore,
    val clockLabel: String,
    val isLive: Boolean = false,
    val extras: Map<String, String>? = null,
    val lastUpdatedUtc: String = ""
) {
    /** Score as "2 – 1", or "vs" for upcoming, or the sport's displayScore override. */
    fun scoreText(): String =
        score.displayScore ?: if (score.home != null && score.away != null)
            "${score.home} – ${score.away}" else "vs"

    /**
     * What prints under the score. For upcoming matches the backend sends an empty
     * clockLabel and we format local kickoff here (the one place the widget formats
     * time — timezone, not sport logic).
     */
    fun displayStatus(): String {
        if (status == MatchStatus.UPCOMING && clockLabel.isBlank()) {
            return runCatching {
                Instant.parse(startTimeUtc)
                    .atZone(ZoneId.systemDefault())
                    .format(DateTimeFormatter.ofPattern("HH:mm"))
            }.getOrDefault("")
        }
        return clockLabel
    }
}

object MatchJson {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    fun parse(raw: String?): List<WidgetMatch> {
        if (raw.isNullOrBlank()) return emptyList()
        return runCatching { json.decodeFromString<List<WidgetMatch>>(raw) }
            .getOrDefault(emptyList())   // bad/old data never crashes the widget
    }

    fun encode(matches: List<WidgetMatch>): String = json.encodeToString(matches)
}
