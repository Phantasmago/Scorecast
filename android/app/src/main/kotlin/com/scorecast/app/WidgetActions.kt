package com.scorecast.app

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.updateAll

private val TAB_KEY = ActionParameters.Key<String>("tab")

fun tabParams(tabId: String): ActionParameters = actionParametersOf(TAB_KEY to tabId)

/**
 * Tapping a filter tab updates the active_tab pref and re-renders the widget — all
 * natively, WITHOUT launching the app (per the brief's §C requirement).
 */
class TabSwitchAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val tab = parameters[TAB_KEY] ?: "favorites"
        context.getSharedPreferences(WidgetKeys.PREFS_FILE, Context.MODE_PRIVATE)
            .edit().putString(WidgetKeys.ACTIVE_TAB, tab).apply()
        ScoreCastGlanceWidget().updateAll(context)
    }
}

/**
 * The "↺" button. Kicks off a one-time background sync that fetches fresh data from
 * the backend and writes it back to prefs. The worker lives in Step 5; until then
 * this still re-renders from current prefs so the button is never dead.
 */
class RefreshAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        // Kick an immediate background fetch (writes prefs + re-renders when done)...
        SyncScheduler.runNow(context)
        // ...and re-render now so the ↺ feels responsive while the fetch runs.
        ScoreCastGlanceWidget().updateAll(context)
    }
}
