import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/containers_provider.dart';
import 'screens/connect_screen.dart';
import 'screens/main_shell.dart';
import 'services/backend_connection.dart';

void main() {
  runApp(const FreezerLogApp());
}

class FreezerLogApp extends StatelessWidget {
  const FreezerLogApp({super.key});

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
        home: const _Root(),
      ),
    );
  }
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
