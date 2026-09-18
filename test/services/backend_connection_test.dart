import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/services/backend_connection.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  test('starts disconnected and loading before loadStored() completes', () {
    final connection = BackendConnection();
    expect(connection.isLoading, isTrue);
    expect(connection.isConnected, isFalse);
  });

  test('loadStored() with nothing saved leaves it disconnected', () async {
    final connection = BackendConnection();
    await connection.loadStored();
    expect(connection.isLoading, isFalse);
    expect(connection.isConnected, isFalse);
    expect(connection.url, isNull);
  });

  test('connect() saves and exposes the normalized url + auth header', () async {
    final connection = BackendConnection();
    await connection.loadStored();

    await connection.connect(
      url: 'https://frawly-api.example.workers.dev/',
      passphrase: 'let-me-in',
    );

    expect(connection.isConnected, isTrue);
    expect(connection.url, 'https://frawly-api.example.workers.dev');
    expect(connection.authHeaders['Authorization'], 'Bearer let-me-in');
  });

  test('a saved connection is restored by a later loadStored()', () async {
    final first = BackendConnection();
    await first.loadStored();
    await first.connect(url: 'https://example.com', passphrase: 'secret');

    final second = BackendConnection();
    await second.loadStored();

    expect(second.isConnected, isTrue);
    expect(second.url, 'https://example.com');
  });

  test('disconnect() clears the saved connection', () async {
    final connection = BackendConnection();
    await connection.loadStored();
    await connection.connect(url: 'https://example.com', passphrase: 'secret');

    await connection.disconnect();

    expect(connection.isConnected, isFalse);
    expect(connection.url, isNull);

    final reloaded = BackendConnection();
    await reloaded.loadStored();
    expect(reloaded.isConnected, isFalse);
  });

  group('testConnection', () {
    test('true when /health responds 200', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://example.com/health');
        expect(request.headers['Authorization'], 'Bearer secret');
        return http.Response('ok', 200);
      });
      final connection = BackendConnection(httpClient: client);

      final ok = await connection.testConnection(
        url: 'https://example.com',
        passphrase: 'secret',
      );

      expect(ok, isTrue);
    });

    test('false when the backend responds with an error status', () async {
      final client = MockClient((request) async => http.Response('nope', 401));
      final connection = BackendConnection(httpClient: client);

      final ok = await connection.testConnection(
        url: 'https://example.com',
        passphrase: 'wrong',
      );

      expect(ok, isFalse);
    });

    test('false when the request throws (unreachable host)', () async {
      final client = MockClient((request) async => throw Exception('boom'));
      final connection = BackendConnection(httpClient: client);

      final ok = await connection.testConnection(
        url: 'https://unreachable.example.com',
        passphrase: 'secret',
      );

      expect(ok, isFalse);
    });

    test('does not save anything', () async {
      final client = MockClient((request) async => http.Response('ok', 200));
      final connection = BackendConnection(httpClient: client);
      await connection.loadStored();

      await connection.testConnection(url: 'https://example.com', passphrase: 'secret');

      expect(connection.isConnected, isFalse);
    });
  });
}
