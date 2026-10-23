import 'dart:convert';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/providers/containers_provider.dart';
import 'package:frawly/services/backend_connection.dart';
import 'package:frawly/services/container_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  Future<ContainersProvider> loadedProvider(List<String> ids) async {
    final httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode([
          for (final id in ids)
            {'id': id, 'date': null, 'status': 'vacant', 'ingredients': []},
        ]),
        200,
      );
    });
    final connection = BackendConnection(httpClient: httpClient);
    await connection.loadStored();
    await connection.connect(url: 'https://frawly-api.example.com', passphrase: 'letmein');
    final provider = ContainersProvider(
      connection: connection,
      service: ContainerService(connection: connection, httpClient: httpClient),
    );
    await provider.load();
    return provider;
  }

  test('filtered() search normalizes separators without merging distinct ids',
      () async {
    final provider = await loadedProvider(['G-5', 'G-25', 'G2-5', 'P-5']);
    List<String> search(String term) =>
        provider.filtered(search: term).map((c) => c.id).toList()..sort();

    expect(search('G5'), ['G-5']);
    expect(search('g25'), ['G-25']);
    expect(search('G 5'), ['G-5']);
    expect(search('G–5'), ['G-5']);
    expect(search('G2-5'), ['G2-5']);
    expect(search('G-'), ['G-25', 'G-5']);
    expect(search(''), ['G-25', 'G-5', 'G2-5', 'P-5']);
  });
}
