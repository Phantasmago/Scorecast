package com.scorecast.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Reschedules widget sync after a device reboot so the board doesn't go stale. */
class BootReceiver : BroadcastReceiver {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            SyncScheduler.start(context)
        }
    }

    // Secondary constructor so the class is instantiable by the system.
    constructor() : super()
}
