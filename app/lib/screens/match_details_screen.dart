import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../contracts/models.dart';
import '../state/app_state.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;
  const MatchDetailsScreen({super.key, required this.matchId});
  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  SportMatch? _match;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await context.read<AppState>().api.getMatch(widget.matchId);
      if (mounted) setState(() => _match = m);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;
    return Scaffold(
      appBar: AppBar(title: Text(m?.leagueName ?? 'Match')),
      body: _error != null
          ? Center(child: Text(_error!))
          : m == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(m.home.name, style: const TextStyle(fontSize: 20))),
                          Text(
                            m.score.displayScore ??
                                ((m.score.home != null && m.score.away != null)
                                    ? '${m.score.home} – ${m.score.away}'
                                    : 'vs'),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                              child: Text(m.away.name,
                                  textAlign: TextAlign.right, style: const TextStyle(fontSize: 20))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(m.displayStatus(),
                            style: TextStyle(color: m.isLive ? Colors.red : Theme.of(context).hintColor)),
                      ),
                      const Divider(height: 32),
                      Text('Status: ${m.status.name}'),
                      Text('Kickoff (UTC): ${m.startTimeUtc}'),
                      if (m.extras != null)
                        for (final e in m.extras!.entries) Text('${e.key}: ${e.value}'),
                      const Spacer(),
                      Text('Updated ${m.lastUpdatedUtc.toLocal()}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
    );
  }
}
