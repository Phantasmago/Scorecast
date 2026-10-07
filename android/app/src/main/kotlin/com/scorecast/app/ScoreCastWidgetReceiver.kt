package com.scorecast.app

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

/**
 * The AppWidget host. Its fully-qualified name — com.scorecast.app.ScoreCastWidgetReceiver —
 * is EXACTLY what Flutter's WidgetBridge.refresh() targets via
 * HomeWidget.updateWidget(qualifiedAndroidName: ...). If you rename this, update
 * WidgetConfig.qualifiedAndroidReceiver in the Dart side too.
 */
class ScoreCastWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ScoreCastGlanceWidget()

    // First widget placed -> start the baseline sync cycle.
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        SyncScheduler.start(context)
    }

    // Last widget removed -> stop burning battery on background sync.
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        SyncScheduler.stop(context)
    }
}
