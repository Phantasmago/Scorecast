import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../contracts/models.dart';
import '../state/app_state.dart';
import '../data/widget_bridge.dart';

/// In-app widget customizer. Every toggle writes through WidgetBridge to the same
/// prefs the Glance widget reads, then re-renders it — so the preview and the real
/// home-screen widget stay in lock-step.
class WidgetStudioScreen extends StatelessWidget {
  const WidgetStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final preview = state.matches.isNotEmpty ? state.matches.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Widget Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PreviewCard(match: preview, accentHex: state.accentColor),
          const SizedBox(height: 24),

          const _SectionLabel('Theme'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('Light')),
              ButtonSegment(value: 'dark', label: Text('Dark')),
              ButtonSegment(value: 'system', label: Text('System')),
            ],
            selected: {state.theme},
            onSelectionChanged: (s) => context.read<AppState>().setTheme(s.first),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('Content mode'),
          SegmentedButton<ContentMode>(
            segments: const [
              ButtonSegment(value: ContentMode.auto, label: Text('Auto / Smart')),
              ButtonSegment(value: ContentMode.pinned, label: Text('Pinned team')),
            ],
            selected: {state.contentMode},
            onSelectionChanged: (s) => context.read<AppState>().setContentMode(
                  s.first,
                  teamId: state.favoriteTeamIds.isNotEmpty ? state.favoriteTeamIds.first : null,
                ),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('Refresh vs battery'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'realtime', label: Text('Real-time')),
              ButtonSegment(value: 'balanced', label: Text('Balanced')),
              ButtonSegment(value: 'battery', label: Text('Battery')),
            ],
            selected: {state.refreshMode},
            onSelectionChanged: (s) => context.read<AppState>().setRefreshMode(s.first),
          ),
          const SizedBox(height: 28),

          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Push current data to widget now'),
            onPressed: () => WidgetBridge.saveMatches(state.matches.take(10).toList()),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final SportMatch? match;
  final String accentHex;
  const _PreviewCard({required this.match, required this.accentHex});

  @override
  Widget build(BuildContext context) {
    final accent = Color(int.parse(accentHex.replaceFirst('#', '0xFF')));
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 2),
      ),
      alignment: Alignment.center,
      child: match == null
          ? const Text('No match data yet — pull to refresh on Scores')
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${match!.home.shortName}  ${match!.score.home ?? ''} – ${match!.score.away ?? ''}  ${match!.away.shortName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(match!.displayStatus(), style: TextStyle(color: accent)),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
