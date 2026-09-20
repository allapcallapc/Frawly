import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/containers_provider.dart';
import 'screens/connect_screen.dart';
import 'screens/main_shell.dart';
import 'services/backend_connection.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const FrawlyApp());
}

class FrawlyApp extends StatelessWidget {
  const FrawlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BackendConnection()..loadStored()),
        // The BackendConnection instance below is the same one across
        // connect/disconnect/reconnect - it mutates its own url/passphrase
        // in place and notifies - so ContainerService (which holds a
        // reference to it, not a copy) always sees the current connection
        // without ContainersProvider itself needing to be rebuilt.
        ChangeNotifierProxyProvider<BackendConnection, ContainersProvider>(
          create: (context) =>
              ContainersProvider(connection: context.read<BackendConnection>()),
          update: (context, connection, previous) =>
              previous ?? ContainersProvider(connection: connection),
        ),
      ],
      child: MaterialApp(
        title: 'Frawly',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF314A8A),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

/// The redesigned light theme: a dark navy app/header bar, a light
/// gray-blue page background, and rounded, softly-shadowed cards/inputs
/// throughout - see the Home and Summary screens for where this shows up
/// most.
ThemeData _buildLightTheme() {
  // Seeded from the logo's dominant navy-blue container lid.
  final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF314A8A));
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

/// Gates between [ConnectScreen] and [MainShell] on [BackendConnection]'s
/// state - shown a loading spinner only for the brief secure-storage read
/// on first launch, then switches to whichever screen fits. Disconnecting
/// (see the "Backend" section of Manage containers) rebuilds this back to
/// [ConnectScreen]; reconnecting rebuilds it forward again, so there's no
/// separate app restart needed either way.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<BackendConnection>();
    if (connection.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return connection.isConnected ? const MainShell() : const ConnectScreen();
  }
}
