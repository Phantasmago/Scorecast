package com.scorecast.app

object SyncConfig {
    // Baseline WorkManager keeps the board fresh; FCM delivers the real-time goals.
    // 10.0.2.2 = host machine from the Android emulator. Change for device / prod.
    const val BACKEND_BASE_URL = "http://10.0.2.2:5000"

    const val LIVE_INTERVAL_MIN = 15L   // Android's background floor; FCM covers faster
    const val IDLE_INTERVAL_MIN = 90L   // nothing live -> back off hard for battery
    const val UNIQUE_WORK = "scorecast_widget_sync"
}
