package com.scorecast.app

import android.content.Context
import android.os.PowerManager
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * Owns the adaptive cadence. A self-rescheduling OneTimeWork lets us vary the gap
 * (live vs idle vs power-save) instead of being locked to PeriodicWork's fixed interval.
 */
object SyncScheduler {

    /** Called when the first widget is placed, and on boot. Runs once now, then cycles. */
    fun start(context: Context) = runNow(context)

    fun stop(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(SyncConfig.UNIQUE_WORK)
    }

    /** Immediate sync (used by start() and the widget's ↺ refresh button). */
    fun runNow(context: Context) {
        val req = OneTimeWorkRequestBuilder<WidgetSyncWorker>()
            .setConstraints(networkConstraint())
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(SyncConfig.UNIQUE_WORK, ExistingWorkPolicy.REPLACE, req)
    }

    /** Schedules the NEXT run. Battery/Low-Power Mode forces the idle cadence. */
    fun scheduleNext(context: Context, anyLive: Boolean) {
        val powerSave = context.getSystemService(PowerManager::class.java)?.isPowerSaveMode == true
        val minutes = when {
            powerSave -> SyncConfig.IDLE_INTERVAL_MIN
            anyLive   -> SyncConfig.LIVE_INTERVAL_MIN
            else      -> SyncConfig.IDLE_INTERVAL_MIN
        }
        val req = OneTimeWorkRequestBuilder<WidgetSyncWorker>()
            .setInitialDelay(minutes, TimeUnit.MINUTES)
            .setConstraints(networkConstraint())
            .build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(SyncConfig.UNIQUE_WORK, ExistingWorkPolicy.REPLACE, req)
    }

    private fun networkConstraint() = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()
}
