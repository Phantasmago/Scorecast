import 'package:flutter/foundation.dart';
import '../contracts/models.dart';
import '../data/api_client.dart';
import '../data/fcm_service.dart';
import '../data/widget_bridge.dart';

/// A selectable league/team catalog entry for onboarding. In production this is
/// fetched from the backend; a small sample is inlined to keep the app runnable.
class CatalogLeague {
  final String id;
  final Sport sport;
  final String name;
  final List<Team> teams;
  const CatalogLeague(this.id, this.sport, this.name, this.teams);
}

const sampleCatalog = <CatalogLeague>[
  CatalogLeague('PL', Sport.football, 'Premier League', [
    Team(id: '57', name: 'Arsenal', shortName: 'ARS'),
    Team(id: '61', name: 'Chelsea', shortName: 'CHE'),
    Team(id: '64', name: 'Liverpool', shortName: 'LIV'),
    Team(id: '65', name: 'Manchester City', shortName: 'MCI'),
  ]),
  CatalogLeague('PD', Sport.football, 'La Liga', [
    Team(id: '86', name: 'Real Madrid', shortName: 'RMA'),
    Team(id: '81', name: 'Barcelona', shortName: 'BAR'),
  ]),
];

enum ContentMode { auto, pinned }

class AppState extends ChangeNotifier {
  final ApiClient api;
  final FcmService fcm;

  AppState({required this.api, required this.fcm});

  // --- user selections ---
  final Set<String> favoriteTeamIds = {};
  final Set<String> followedLeagueIds = {};
  final Set<String> pinnedMatchIds = {};

  ContentMode contentMode = ContentMode.auto;
  String? pinnedTeamId;
  String theme = 'system'; // light | dark | system
  String accentColor = '#E11D48';
  String refreshMode = 'balanced'; // realtime | balanced | battery

  // --- live data ---
  List<SportMatch> matches = [];
  bool loading = false;
  String? error;

  bool isOnboarded() => favoriteTeamIds.isNotEmpty || followedLeagueIds.isNotEmpty;

  Future<void> toggleTeam(String id, String leagueId) async {
    if (favoriteTeamIds.contains(id)) {
      favoriteTeamIds.remove(id);
      await fcm.unsubscribeTeam(id);
    } else {
      favoriteTeamIds.add(id);
      followedLeagueIds.add(leagueId);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setContentMode(ContentMode mode, {String? teamId}) async {
    contentMode = mode;
    pinnedTeamId = mode == ContentMode.pinned ? teamId : null;
    notifyListeners();
    await _persist();
  }

  Future<void> setTheme(String t) async { theme = t; notifyListeners(); await _persist(); }
  Future<void> setAccent(String hex) async { accentColor = hex; notifyListeners(); await _persist(); }
  Future<void> setRefreshMode(String m) async { refreshMode = m; notifyListeners(); await _persist(); }

  /// Pull the latest snapshot from the backend, cache it, and push it to the widget.
  Future<void> refreshMatches({MatchStatus? status, Sport? sport}) async {
    loading = true; error = null; notifyListeners();
    try {
      matches = await api.getMatches(status: status, sport: sport);
      await WidgetBridge.saveMatches(_widgetProjection());
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// What the widget should show: favorites first, live first, trimmed.
  List<SportMatch> _widgetProjection() {
    final mine = matches.where((m) =>
        favoriteTeamIds.contains(m.home.id) ||
        favoriteTeamIds.contains(m.away.id) ||
        followedLeagueIds.contains(m.leagueId));
    final chosen = (mine.isEmpty ? matches : mine).toList()
      ..sort((a, b) {
        if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
        return a.startTimeUtc.compareTo(b.startTimeUtc);
      });
    return chosen.take(10).toList();
  }

  Future<void> _persist() async {
    await WidgetBridge.saveConfig(
      contentMode: contentMode == ContentMode.auto ? 'auto' : 'pinned',
      pinnedTeamId: pinnedTeamId,
      theme: theme,
      accentColor: accentColor,
      refreshMode: refreshMode,
      favoriteTeamIds: favoriteTeamIds.toList(),
    );
    await fcm.syncSubscriptions(
      teamIds: favoriteTeamIds.toList(),
      leagueIds: followedLeagueIds.toList(),
      pinnedMatchIds: pinnedMatchIds.toList(),
    );
  }
}
