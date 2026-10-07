// Dart mirror of ScoreCast.Contracts (Step 1). Wire format is camelCase JSON,
// enums are strings. If the C# contract changes, change this to match.

enum Sport {
  football,
  basketball,
  americanFootball,
  baseball,
  iceHockey,
  tennis,
  cricket,
  motorsport;

  static Sport fromJson(String s) => switch (s) {
        'Football' => Sport.football,
        'Basketball' => Sport.basketball,
        'AmericanFootball' => Sport.americanFootball,
        'Baseball' => Sport.baseball,
        'IceHockey' => Sport.iceHockey,
        'Tennis' => Sport.tennis,
        'Cricket' => Sport.cricket,
        'Motorsport' => Sport.motorsport,
        _ => Sport.football,
      };

  String get wire => switch (this) {
        Sport.football => 'Football',
        Sport.basketball => 'Basketball',
        Sport.americanFootball => 'AmericanFootball',
        Sport.baseball => 'Baseball',
        Sport.iceHockey => 'IceHockey',
        Sport.tennis => 'Tennis',
        Sport.cricket => 'Cricket',
        Sport.motorsport => 'Motorsport',
      };

  /// Sports rendered as 2-team cards on the widget in v1 (see CONTRACT.md).
  bool get widgetSupported => switch (this) {
        Sport.tennis || Sport.motorsport => false,
        _ => true,
      };
}

enum MatchStatus {
  upcoming,
  live,
  finished,
  postponed,
  unknown;

  static MatchStatus fromJson(String s) => switch (s) {
        'Upcoming' => MatchStatus.upcoming,
        'Live' => MatchStatus.live,
        'Finished' => MatchStatus.finished,
        'Postponed' => MatchStatus.postponed,
        _ => MatchStatus.unknown,
      };
}

class Team {
  final String id;
  final String name;
  final String shortName;
  final String? crestUrl;

  const Team({required this.id, required this.name, required this.shortName, this.crestUrl});

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: j['shortName'] as String,
        crestUrl: j['crestUrl'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'shortName': shortName, 'crestUrl': crestUrl};
}

class Score {
  final int? home;
  final int? away;
  final String? displayScore;

  const Score({this.home, this.away, this.displayScore});

  factory Score.fromJson(Map<String, dynamic> j) => Score(
        home: j['home'] as int?,
        away: j['away'] as int?,
        displayScore: j['displayScore'] as String?,
      );

  Map<String, dynamic> toJson() => {'home': home, 'away': away, 'displayScore': displayScore};
}

class SportMatch {
  final String id;
  final Sport sport;
  final String leagueId;
  final String leagueName;
  final MatchStatus status;
  final DateTime startTimeUtc;
  final Team home;
  final Team away;
  final Score score;
  final String clockLabel;
  final bool isLive;
  final Map<String, String>? extras;
  final DateTime lastUpdatedUtc;

  const SportMatch({
    required this.id,
    required this.sport,
    required this.leagueId,
    required this.leagueName,
    required this.status,
    required this.startTimeUtc,
    required this.home,
    required this.away,
    required this.score,
    required this.clockLabel,
    required this.isLive,
    required this.lastUpdatedUtc,
    this.extras,
  });

  factory SportMatch.fromJson(Map<String, dynamic> j) => SportMatch(
        id: j['id'] as String,
        sport: Sport.fromJson(j['sport'] as String),
        leagueId: j['leagueId'] as String,
        leagueName: j['leagueName'] as String,
        status: MatchStatus.fromJson(j['status'] as String),
        startTimeUtc: DateTime.parse(j['startTimeUtc'] as String).toUtc(),
        home: Team.fromJson(j['home'] as Map<String, dynamic>),
        away: Team.fromJson(j['away'] as Map<String, dynamic>),
        score: Score.fromJson(j['score'] as Map<String, dynamic>),
        clockLabel: j['clockLabel'] as String,
        isLive: (j['isLive'] as bool?) ?? false,
        extras: (j['extras'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
        lastUpdatedUtc: DateTime.parse(j['lastUpdatedUtc'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sport': sport.wire,
        'leagueId': leagueId,
        'leagueName': leagueName,
        'status': switch (status) {
          MatchStatus.upcoming => 'Upcoming',
          MatchStatus.live => 'Live',
          MatchStatus.finished => 'Finished',
          MatchStatus.postponed => 'Postponed',
          MatchStatus.unknown => 'Unknown',
        },
        'startTimeUtc': startTimeUtc.toIso8601String(),
        'home': home.toJson(),
        'away': away.toJson(),
        'score': score.toJson(),
        'clockLabel': clockLabel,
        'isLive': isLive,
        'extras': extras,
        'lastUpdatedUtc': lastUpdatedUtc.toIso8601String(),
      };

  /// Score as "2 – 1", "vs" for upcoming, or the sport's displayScore override.
  String scoreText() =>
      score.displayScore ??
      (score.home != null && score.away != null ? '${score.home} – ${score.away}' : 'vs');

  /// What the widget/app prints under the score. For upcoming, the client formats
  /// local kickoff from startTimeUtc (backend sends clockLabel="" for those).
  String displayStatus() {
    if (status == MatchStatus.upcoming && clockLabel.isEmpty) {
      final local = startTimeUtc.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return clockLabel;
  }
}
