import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/providers/containers_provider.dart';
import 'package:frawly/screens/main_shell.dart';
import 'package:frawly/services/backend_connection.dart';
import 'package:frawly/services/container_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../support/fake_secure_storage_platform.dart';

/// Regression test for a real bug: on a fresh app start with an
/// already-saved connection (i.e. every browser reload once connected -
/// see the "containers disappear on reload" report), MainShell used to
/// call ContainersProvider.load() directly from initState(). Its first
/// notifyListeners() (isLoading=true) could fire before this screen's own
/// `Consumer<ContainersProvider>` existed to subscribe to it, which was
/// enough - racing against BackendConnection's own notifyListeners() from
/// loadStored() - for the *second*, successful notifyListeners() to also
/// never reach a rebuild: the registry fetch succeeded, but nothing on
/// screen ever showed it. Reproduced against the real backend locally
/// (Playwright + wrangler dev) before being fixed by deferring the load()
/// call to a post-frame callback (main_shell.dart).
void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets(
      'shows the registry after MainShell mounts from an already-saved connection',
      (tester) async {
    // Simulate "already connected, page reloaded": a connection saved by a
    // previous session, found by loadStored() on this fresh start.
    final seed = BackendConnection();
    await seed.connect(url: 'https://frawly-api.example.com', passphrase: 'letmein');

    final httpClient = MockClient((request) async {
      if (request.url.path == '/containers/registry') {
        return http.Response(
          '[{"id":"P-1","date":null,"status":"vacant","ingredients":[]}]',
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final connection = BackendConnection(httpClient: httpClient);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: connection..loadStored()),
          ChangeNotifierProxyProvider<BackendConnection, ContainersProvider>(
            create: (context) => ContainersProvider(
              connection: context.read<BackendConnection>(),
              service: ContainerService(connection: connection, httpClient: httpClient),
            ),
            update: (context, connection, previous) => previous!,
          ),
        ],
        child: MaterialApp(
          home: Consumer<BackendConnection>(
            builder: (context, connection, _) {
              if (connection.isLoading) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return connection.isConnected ? const MainShell() : const Scaffold();
            },
          ),
        ),
      ),
    );

    // loadStored() resolving is what first mounts MainShell - let that,
    // and the post-frame-deferred load() it triggers, fully settle.
    await tester.pumpAndSettle();

    expect(find.text('P-1'), findsOneWidget);
  });
}
