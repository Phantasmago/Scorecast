import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../contracts/models.dart';
import 'prefs_keys.dart';

/// The handshake between the Flutter app and the native Glance widget.
///
/// Everything the widget shows comes from here. The app (foreground, WorkManager,
/// or the FCM background isolate) writes config + the match projection into the
/// shared SharedPreferences, then calls [refresh] to re-render the widget.
class WidgetBridge {
  /// Persist user config. Called whenever the user changes a Widget Studio toggle.
  static Future<void> saveConfig({
    required String contentMode,
    String? pinnedTeamId,
    required String theme,
    required String accentColor,
    required String refreshMode,
    required List<String> favoriteTeamIds,
    String? activeTab,
  }) async {
    await HomeWidget.saveWidgetData<String>(PrefsKeys.contentMode, contentMode);
    await HomeWidget.saveWidgetData<String>(PrefsKeys.pinnedTeamId, pinnedTeamId ?? '');
    await HomeWidget.saveWidgetData<String>(PrefsKeys.theme, theme);
    await HomeWidget.saveWidgetData<String>(PrefsKeys.accentColor, accentColor);
    await HomeWidget.saveWidgetData<String>(PrefsKeys.refreshMode, refreshMode);
    await HomeWidget.saveWidgetData<String>(
        PrefsKeys.favoriteTeamIds, jsonEncode(favoriteTeamIds));
    if (activeTab != null) {
      await HomeWidget.saveWidgetData<String>(PrefsKeys.activeTab, activeTab);
    }
    await refresh();
  }

  /// Replace the full match projection the widget renders.
  static Future<void> saveMatches(List<SportMatch> matches) async {
    final jsonList = matches.map((m) => m.toJson()).toList();
    await HomeWidget.saveWidgetData<String>(PrefsKeys.matchesJson, jsonEncode(jsonList));
    await HomeWidget.saveWidgetData<String>(
        PrefsKeys.lastSyncUtc, DateTime.now().toUtc().toIso8601String());
    await refresh();
  }

  /// Merge a single updated match (from an FCM push) into the stored projection,
  /// then refresh. Runs in the background isolate with near-zero delay.
  static Future<void> mergeMatch(SportMatch updated) async {
    final raw = await HomeWidget.getWidgetData<String>(PrefsKeys.matchesJson);
    final List<dynamic> current = raw == null ? [] : jsonDecode(raw) as List<dynamic>;

    final list = current
        .map((e) => SportMatch.fromJson(e as Map<String, dynamic>))
        .where((m) => m.id != updated.id) // drop the stale copy
        .toList()
      ..add(updated);

    await saveMatches(list);
  }

  /// Trigger the Android widget to rebuild from the freshly-written prefs.
  static Future<void> refresh() async {
    await HomeWidget.updateWidget(
      androidName: WidgetConfig.androidReceiver,
      qualifiedAndroidName: WidgetConfig.qualifiedAndroidReceiver,
    );
  }
}
