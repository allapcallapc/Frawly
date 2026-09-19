import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/screens/connect_screen.dart';
import 'package:frawly/services/backend_connection.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  Future<BackendConnection> pumpConnectScreen(
    WidgetTester tester, {
    required http.Client httpClient,
  }) async {
    final connection = BackendConnection(httpClient: httpClient);
    await connection.loadStored();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: connection,
        child: const MaterialApp(home: ConnectScreen()),
      ),
    );
    return connection;
  }

  testWidgets('shows an error and does not connect when the backend is unreachable',
      (tester) async {
    final connection = await pumpConnectScreen(
      tester,
      httpClient: MockClient((request) async => http.Response('', 401)),
    );

    await tester.enterText(find.byType(TextField).first, 'https://example.com');
    await tester.enterText(find.byType(TextField).last, 'wrong-passphrase');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(connection.isConnected, isFalse);
    expect(find.textContaining('Could not reach'), findsOneWidget);
  });

  testWidgets('connects and saves the connection on success', (tester) async {
    final connection = await pumpConnectScreen(
      tester,
      httpClient: MockClient((request) async => http.Response('ok', 200)),
    );

    await tester.enterText(find.byType(TextField).first, 'https://example.com');
    await tester.enterText(find.byType(TextField).last, 'letmein');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(connection.isConnected, isTrue);
    expect(connection.url, 'https://example.com');
  });

  testWidgets('rejects submitting with an empty field', (tester) async {
    final connection = await pumpConnectScreen(
      tester,
      httpClient: MockClient((request) async => fail('should not be called')),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(connection.isConnected, isFalse);
    expect(find.textContaining('Enter both'), findsOneWidget);
  });
}
