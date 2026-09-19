import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/providers/containers_provider.dart';
import 'package:frawly/screens/manage_containers_screen.dart';
import 'package:frawly/services/backend_connection.dart';
import 'package:frawly/services/container_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required http.Client httpClient,
  }) async {
    final connection = BackendConnection(httpClient: httpClient);
    await connection.loadStored();
    await connection.connect(url: 'https://frawly-api.example.com', passphrase: 'letmein');
    final provider = ContainersProvider(
      connection: connection,
      service: ContainerService(connection: connection, httpClient: httpClient),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: connection),
          ChangeNotifierProvider.value(value: provider),
        ],
        child: const MaterialApp(home: ManageContainersScreen()),
      ),
    );
    await provider.load();
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows an error instead of "No containers yet" when the registry fails to load',
      (tester) async {
    await pumpScreen(
      tester,
      httpClient: MockClient((request) async => http.Response('server error', 500)),
    );

    expect(find.textContaining('Could not load containers'), findsOneWidget);
    expect(find.text('No containers yet.'), findsNothing);
  });

  testWidgets('lists the registry on a successful load', (tester) async {
    await pumpScreen(
      tester,
      httpClient: MockClient((request) async {
        if (request.url.path == '/containers/registry') {
          return http.Response(
            '[{"id":"P-1","date":null,"status":"vacant","ingredients":[]}]',
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    expect(find.text('Registered containers (1)'), findsOneWidget);
    expect(find.text('P-1'), findsOneWidget);
    expect(find.textContaining('Could not load containers'), findsNothing);
  });
}
