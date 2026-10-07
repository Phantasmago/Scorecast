package com.scorecast.app

import android.content.Context
import android.content.Intent
import android.graphics.Color as AndroidColor
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition

/**
 * The home-screen widget. Reads the match projection + config the Flutter app wrote
 * into HomeWidgetPreferences (via HomeWidgetGlanceStateDefinition), then renders a
 * layout chosen by the current grid size.
 *
 * Deliberately "dumb": it prints `clockLabel` verbatim and uses `isLive` for the dot,
 * so it carries zero sport-specific clock logic.
 */
class ScoreCastGlanceWidget : GlanceAppWidget() {

    // Read from the SAME SharedPreferences the home_widget plugin writes to.
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    // Three responsive buckets = the 2x2, 4x2, 4x4 targets from the brief.
    companion object {
        private val SMALL = DpSize(120.dp, 120.dp)   // 2x2
        private val MEDIUM = DpSize(250.dp, 120.dp)  // 4x2
        private val LARGE = DpSize(250.dp, 250.dp)   // 4x4
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences

            val matches = MatchJson.parse(prefs.getString(WidgetKeys.MATCHES_JSON, null))
            val activeTab = prefs.getString(WidgetKeys.ACTIVE_TAB, "favorites") ?: "favorites"
            val accent = parseAccent(prefs.getString(WidgetKeys.ACCENT_COLOR, "#E11D48"))

            val visible = applyTab(matches, activeTab).filter { it.sport.widgetSupported }

            GlanceTheme {
                val size = LocalSize.current
                when {
                    size.width < 180.dp -> SmallWidget(visible, accent)
                    size.height < 180.dp -> MediumWidget(visible, activeTab, accent)
                    else -> LargeWidget(visible, activeTab, accent)
                }
            }
        }
    }

    // --- 2x2: one high-priority match ---------------------------------------
    @Composable
    private fun SmallWidget(matches: List<WidgetMatch>, accent: Color) {
        Box(
            modifier = GlanceModifier.fillMaxSize().surface().padding(10.dp),
            contentAlignment = Alignment.Center
        ) {
            val m = matches.firstOrNull()
            if (m == null) EmptyState()
            else Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = tapTo(m)) {
                Text(m.leagueName, style = caption(), maxLines = 1)
                Spacer(GlanceModifier.size(4.dp))
                Text("${m.home.shortName}  ${m.scoreText()}  ${m.away.shortName}",
                    style = TextStyle(color = onSurface(), fontSize = 16.sp, fontWeight = FontWeight.Bold))
                Spacer(GlanceModifier.size(6.dp))
                StatusLine(m, accent)
            }
        }
    }

    // --- 4x2: 2–3 matches + filter tabs + manual refresh --------------------
    @Composable
    private fun MediumWidget(matches: List<WidgetMatch>, activeTab: String, accent: Color) {
        Column(modifier = GlanceModifier.fillMaxSize().surface().padding(8.dp)) {
            TabBar(activeTab, accent, showRefresh = true)
            Spacer(GlanceModifier.size(6.dp))
            if (matches.isEmpty()) EmptyState()
            else matches.take(3).forEach { m ->
                MatchRow(m, accent)
                Spacer(GlanceModifier.size(4.dp))
            }
        }
    }

    // --- 4x4: scrollable full board -----------------------------------------
    @Composable
    private fun LargeWidget(matches: List<WidgetMatch>, activeTab: String, accent: Color) {
        Column(modifier = GlanceModifier.fillMaxSize().surface().padding(10.dp)) {
            TabBar(activeTab, accent, showRefresh = true)
            Spacer(GlanceModifier.size(6.dp))
            if (matches.isEmpty()) {
                // No games match the tab: a league-table-style note placeholder.
                EmptyState("No games here right now")
            } else {
                LazyColumn {
                    items(matches) { m -> MatchRow(m, accent) }
                }
            }
        }
    }

    // --- shared pieces ------------------------------------------------------
    @Composable
    private fun MatchRow(m: WidgetMatch, accent: Color) {
        Row(
            modifier = GlanceModifier.fillMaxWidth().padding(vertical = 6.dp).then(tapTo(m)),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(m.home.shortName, style = team(), modifier = GlanceModifier.width(44.dp))
            Box(modifier = GlanceModifier.defaultWeight(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(m.scoreText(),
                        style = TextStyle(color = onSurface(), fontSize = 15.sp, fontWeight = FontWeight.Bold))
                    StatusLine(m, accent)
                }
            }
            Text(m.away.shortName, style = team(), modifier = GlanceModifier.width(44.dp))
        }
    }

    @Composable
    private fun StatusLine(m: WidgetMatch, accent: Color) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (m.isLive) {
                Box(modifier = GlanceModifier.size(7.dp)
                    .background(ColorProvider(Color(0xFFE11D48))))
                Spacer(GlanceModifier.width(4.dp))
            }
            Text(
                m.displayStatus(),
                style = TextStyle(
                    color = if (m.isLive) ColorProvider(Color(0xFFE11D48)) else caption().color,
                    fontSize = 11.sp
                )
            )
        }
    }

    @Composable
    private fun TabBar(activeTab: String, accent: Color, showRefresh: Boolean) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Tab("★", "favorites", activeTab, accent)
            Spacer(GlanceModifier.width(6.dp))
            Tab("⚽", "soccer", activeTab, accent)
            Spacer(GlanceModifier.width(6.dp))
            Tab("🏀", "nba", activeTab, accent)
            Box(modifier = GlanceModifier.defaultWeight()) {}
            if (showRefresh) {
                Text("↺",
                    style = TextStyle(color = onSurface(), fontSize = 16.sp),
                    modifier = GlanceModifier.clickable(actionRunCallback<RefreshAction>()))
            }
        }
    }

    @Composable
    private fun Tab(label: String, tabId: String, activeTab: String, accent: Color) {
        val selected = tabId == activeTab
        Text(
            label,
            style = TextStyle(
                color = if (selected) ColorProvider(accent) else caption().color,
                fontSize = 14.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal
            ),
            // Tapping a tab re-renders natively — it does NOT launch the app.
            modifier = GlanceModifier.clickable(
                actionRunCallback<TabSwitchAction>(tabParams(tabId))
            )
        )
    }

    @Composable
    private fun EmptyState(msg: String = "No matches yet — open ScoreCast") {
        Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(msg, style = caption(), maxLines = 2)
        }
    }

    // Tap any match -> deep link into its details page (app://match/{id}).
    private fun tapTo(m: WidgetMatch): GlanceModifier {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("app://match/${m.id}"))
        return GlanceModifier.clickable(actionStartActivity(intent))
    }

    // --- styling helpers ----------------------------------------------------
    @Composable private fun onSurface() = GlanceTheme.colors.onSurface
    @Composable private fun surfaceColor() = GlanceTheme.colors.surface
    @Composable private fun GlanceModifier.surface() = this.background(GlanceTheme.colors.surface)
    @Composable private fun team() = TextStyle(color = onSurface(), fontSize = 13.sp, fontWeight = FontWeight.Medium)
    @Composable private fun caption() = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 11.sp)

    private fun parseAccent(hex: String?): Color =
        runCatching { Color(AndroidColor.parseColor(hex ?: "#E11D48")) }.getOrDefault(Color(0xFFE11D48))
}
