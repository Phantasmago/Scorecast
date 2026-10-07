import 'dart:convert';
import 'package:http/http.dart' as http;
import '../contracts/models.dart';

/// Talks to the C# backend (Step 2). The app calls this on launch and on
/// pull-to-refresh; between calls it rides FCM. The widget never calls this.
class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({required this.baseUrl, http.Client? client}) : _http = client ?? http.Client();

  /// GET /api/matches with optional filters.
  Future<List<SportMatch>> getMatches({MatchStatus? status, Sport? sport, String? leagueId}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status.name;
    if (sport != null) params['sport'] = sport.wire;
    if (leagueId != null) params['league'] = leagueId;

    final uri = Uri.parse('$baseUrl/api/matches').replace(queryParameters: params.isEmpty ? null : params);
    final resp = await _http.get(uri).timeout(const Duration(seconds: 12));

    if (resp.statusCode != 200) {
      throw ApiException('GET /api/matches failed: ${resp.statusCode}');
    }
    final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
    return data.map((e) => SportMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SportMatch> getMatch(String id) async {
    final resp = await _http
        .get(Uri.parse('$baseUrl/api/matches/$id'))
        .timeout(const Duration(seconds: 12));
    if (resp.statusCode == 404) throw ApiException('Match $id not found');
    if (resp.statusCode != 200) throw ApiException('GET match failed: ${resp.statusCode}');
    return SportMatch.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
