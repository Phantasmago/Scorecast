import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pick your teams')),
      body: ListView(
        children: [
          for (final league in sampleCatalog) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(league.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final team in league.teams)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilterChip(
                      label: Text(team.name),
                      selected: state.favoriteTeamIds.contains(team.id),
                      onSelected: (_) => context.read<AppState>().toggleTeam(team.id, league.id),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: state.favoriteTeamIds.isEmpty
                  ? null
                  : () async {
                      await context.read<AppState>().refreshMatches();
                      if (context.mounted) context.go('/home');
                    },
              child: const Text('Continue — then long-press your home screen to add the widget'),
            ),
          ),
        ],
      ),
    );
  }
}
