import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_shell.dart';
import 'screens/match_details_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';

/// Routes. The widget's match-card tap launches the app with `app://match/{id}`,
/// which the platform delivers here as `/match/:id` (see Step 5 manifest wiring).
GoRouter buildRouter(AppState state) => GoRouter(
      initialLocation: state.isOnboarded() ? '/home' : '/onboarding',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
        GoRoute(
          path: '/match/:id',
          builder: (_, s) => MatchDetailsScreen(matchId: s.pathParameters['id']!),
        ),
      ],
      errorBuilder: (_, s) => Scaffold(
        body: Center(child: Text('Route not found: ${s.uri}')),
      ),
    );
