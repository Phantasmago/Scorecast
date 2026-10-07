package com.scorecast.app

/**
 * The frozen keys the Glance widget reads. MUST match CONTRACT.md §2 and the Dart
 * PrefsKeys in Step 3 exactly. The app (via the home_widget plugin) writes these
 * into the SharedPreferences file named below.
 */
object WidgetKeys {
    // home_widget's Android SharedPreferences file. The app writes here; we read here.
    const val PREFS_FILE = "HomeWidgetPreferences"

    const val CONTENT_MODE = "content_mode"       // "auto" | "pinned"
    const val PINNED_TEAM_ID = "pinned_team_id"
    const val THEME = "theme"                       // "light" | "dark" | "system"
    const val ACCENT_COLOR = "accent_color"         // hex "#RRGGBB"
    const val ACTIVE_TAB = "active_tab"             // "favorites" | "soccer" | "nba" ...
    const val FAVORITE_TEAM_IDS = "favorite_team_ids"
    const val MATCHES_JSON = "matches_json"         // JSON array of MatchDto
    const val LAST_SYNC_UTC = "last_sync_utc"
    const val REFRESH_MODE = "refresh_mode"
}
