/// The frozen keys the app writes and the Glance widget reads.
/// MUST match CONTRACT.md §2 and the Kotlin constants in Step 4 exactly.
///
/// On Android the `home_widget` plugin stores these in the SharedPreferences file
/// named "HomeWidgetPreferences" — that's the file Step 4's widget reads from.
class PrefsKeys {
  static const contentMode = 'content_mode'; // "auto" | "pinned"
  static const pinnedTeamId = 'pinned_team_id';
  static const theme = 'theme'; // "light" | "dark" | "system"
  static const accentColor = 'accent_color'; // hex "#RRGGBB"
  static const activeTab = 'active_tab'; // "favorites" | "soccer" | "nba" ...
  static const favoriteTeamIds = 'favorite_team_ids'; // JSON array of ids
  static const matchesJson = 'matches_json'; // JSON array of MatchDto
  static const lastSyncUtc = 'last_sync_utc'; // ISO-8601
  static const refreshMode = 'refresh_mode'; // "realtime" | "balanced" | "battery"
}

/// Android widget receiver class (Step 4). Used by home_widget to target updates.
class WidgetConfig {
  static const androidReceiver = 'ScoreCastWidgetReceiver';
  static const qualifiedAndroidReceiver = 'com.scorecast.app.ScoreCastWidgetReceiver';
}
