import 'package:flutter/material.dart';
import 'live_scores_screen.dart';
import 'widget_studio_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _pages = const [LiveScoresScreen(), WidgetStudioScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_soccer), label: 'Scores'),
          NavigationDestination(icon: Icon(Icons.widgets_outlined), label: 'Widget'),
        ],
      ),
    );
  }
}
