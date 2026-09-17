import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/containers_provider.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SupabaseConfig has no built-in default (see its doc comment) - catch a
  // missing --dart-define here with a clear message instead of letting it
  // silently try to connect to an empty URL.
  if (SupabaseConfig.url.isEmpty || SupabaseConfig.anonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // supabase_flutter's `publishableKey` param accepts either a modern
    // sb_publishable_... key or a legacy anon JWT (like the local dev
    // stack's fixed demo key) interchangeably.
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const FreezerLogApp());
}

class FreezerLogApp extends StatelessWidget {
  const FreezerLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContainersProvider(),
      child: MaterialApp(
        title: 'Freezer Log',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0079C2)),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0079C2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}

/// Shown instead of the real app when env/*.json wasn't passed via
/// --dart-define-from-file, or points at a project that doesn't exist yet
/// (see CLAUDE.md's "Backend hosting" section) - a silent blank/crashed
/// app would be much harder to diagnose than this.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freezer Log',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 48),
                SizedBox(height: 16),
                Text(
                  'Missing Supabase config.\n\n'
                  'Run with --dart-define-from-file=env/local.json (or '
                  'staging.json/prod.json once those have a real project -\n'
                  'see CLAUDE.md\'s "Backend hosting" section).',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
