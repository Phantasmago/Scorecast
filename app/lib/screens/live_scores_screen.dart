import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../contracts/models.dart';
import '../state/app_state.dart';
import '../widgets/match_card.dart';

class LiveScoresScreen extends StatefulWidget {
  const LiveScoresScreen({super.key});
  @override
  State<LiveScoresScreen> createState() => _LiveScoresScreenState();
}

class _LiveScoresScreenState extends State<LiveScoresScreen> {
  MatchStatus? _filter; // null = All

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final matches = _filter == null
        ? state.matches
        : state.matches.where((m) => m.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scores'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _chip('All', null),
                _chip('Live', MatchStatus.live),
                _chip('Upcoming', MatchStatus.upcoming),
                _chip('Finished', MatchStatus.finished),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refreshMatches(),
        child: state.loading && matches.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && matches.isEmpty
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(state.error!))])
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (_, i) => MatchCard(
                      match: matches[i],
                      onTap: () => context.go('/match/${matches[i].id}'),
                    ),
                  ),
      ),
    );
  }

  Widget _chip(String label, MatchStatus? status) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == status,
          onSelected: (_) => setState(() => _filter = status),
        ),
      );
}
