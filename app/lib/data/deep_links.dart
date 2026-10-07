import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

/// Catches the `app://match/{id}` link the widget fires on tap and routes to it.
///
/// Custom-scheme URIs put the first segment in `host`, so `app://match/42` parses
/// as host="match", pathSegments=["42"]. We normalize that into a go_router path
/// instead of trying to match the raw URI.
class DeepLinks {
  final GoRouter router;
  final _appLinks = AppLinks();

  DeepLinks(this.router);

  Future<void> init() async {
    // Cold start: app launched by the widget tap.
    final initial = await _appLinks.getInitialLink();
    if (initial != null) _handle(initial);

    // Warm: app already running.
    _appLinks.uriLinkStream.listen(_handle);
  }

  void _handle(Uri uri) {
    switch (uri.host) {
      case 'match':
        if (uri.pathSegments.isNotEmpty) router.go('/match/${uri.pathSegments.first}');
        break;
      case 'tab':
        router.go('/home');
        break;
    }
  }
}
