import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/sections.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await _preloadFonts();
  runApp(const ProviderScope(child: PortfolioApp()));
}

/// Fetch the Google Fonts before the first frame. Text measured with the
/// fallback font and re-measured later is what made cards and chips overflow
/// or clip. Capped so a slow or offline network never blocks the site.
Future<void> _preloadFonts() async {
  buildTheme(Brightness.light);
  for (final w in [FontWeight.w300, FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    GoogleFonts.jetBrainsMono(fontWeight: w);
  }
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Render with fallback fonts; layout still adapts once they arrive.
  }
}

final _router = GoRouter(
  routes: [
    for (final s in Section.values)
      GoRoute(
        path: s.path,
        // Same page key for every section: the Navigator updates the existing
        // HomeScreen (keeping scroll + state) and it scrolls to the new target.
        pageBuilder: (context, state) => NoTransitionPage(
          key: const ValueKey('home'),
          child: HomeScreen(section: s),
        ),
      ),
  ],
  errorPageBuilder: (context, state) => const NoTransitionPage(
    key: ValueKey('home'),
    child: HomeScreen(section: Section.overview),
  ),
);

class PortfolioApp extends ConsumerWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Prof. Dr. Srijan Lal Shrestha | Professor of Statistics, Tribhuvan University',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
