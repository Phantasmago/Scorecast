package com.scorecast.app

import android.content.Context
import androidx.glance.appwidget.updateAll
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

/**
 * The baseline background sync. Pulls the latest matches from the C# backend, writes
 * a favorites-filtered projection into HomeWidgetPreferences, re-renders the widget,
 * then reschedules itself with an interval that adapts to whether anything is live.
 *
 * This is the "when games are active -> 15-min tasks / idle -> hourly" behavior from
 * the brief. Sub-15-minute freshness comes from FCM, not from here.
 */
class WidgetSyncWorker(
    private val ctx: Context,
    params: WorkerParameters
) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        var anyLive = false
        try {
            val body = httpGet("${SyncConfig.BACKEND_BASE_URL}/api/matches")
            val all = MatchJson.parse(body)
            anyLive = all.any { it.isLive }

            val projection = project(all)
            val prefs = ctx.getSharedPreferences(WidgetKeys.PREFS_FILE, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(WidgetKeys.MATCHES_JSON, MatchJson.encode(projection))
                .putString(WidgetKeys.LAST_SYNC_UTC, Instant.now().toString())
                .apply()

            ScoreCastGlanceWidget().updateAll(applicationContext)
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        } finally {
            // Always keep the cycle alive, even after a failure.
            SyncScheduler.scheduleNext(applicationContext, anyLive)
        }
    }

    /** Favorites (and followed leagues) first; fall back to everything if no favorites set. */
    private fun project(all: List<WidgetMatch>): List<WidgetMatch> {
        val prefs = ctx.getSharedPreferences(WidgetKeys.PREFS_FILE, Context.MODE_PRIVATE)
        val favs = parseIds(prefs.getString(WidgetKeys.FAVORITE_TEAM_IDS, null))
        val mine = all.filter { it.home.id in favs || it.away.id in favs }
        return (if (mine.isEmpty()) all else mine)
            .sortedWith(compareByDescending<WidgetMatch> { it.isLive }.thenBy { it.startTimeUtc })
            .take(20)
    }

    private fun parseIds(raw: String?): Set<String> =
        if (raw.isNullOrBlank()) emptySet()
        else runCatching { Json.decodeFromString<List<String>>(raw).toSet() }.getOrDefault(emptySet())

    private fun httpGet(urlStr: String): String {
        val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 10_000
            readTimeout = 10_000
        }
        return conn.inputStream.use { it.bufferedReader().readText() }
    }
}
