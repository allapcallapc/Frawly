import 'dart:convert';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/container_status.dart';
import 'package:frawly/models/ingredient.dart';
import 'package:frawly/services/backend_connection.dart';
import 'package:frawly/services/container_service.dart';
import 'package:frawly/services/container_service_exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_secure_storage_platform.dart';

void main() {
  late BackendConnection connection;

  setUp(() async {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
    connection = BackendConnection();
    await connection.loadStored();
    await connection.connect(url: 'https://frawly-api.example.com', passphrase: 'letmein');
  });

  ContainerService serviceFor(http.Client client) =>
      ContainerService(connection: connection, httpClient: client);

  Map<String, dynamic> rowJson({
    String id = 'P-1',
    String? date,
    ContainerStatus status = ContainerStatus.vacant,
    List<Ingredient> ingredients = const [],
  }) =>
      {
        'id': id,
        'date': date,
        'status': status.value,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      };

  group('list', () {
    test('sends status/search as query params and parses the rows', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/containers');
        expect(request.url.queryParameters['status'], 'frozen');
        expect(request.url.queryParameters['search'], 'chili');
        expect(request.headers['Authorization'], 'Bearer letmein');
        return http.Response(
          jsonEncode([rowJson(id: 'P-1', status: ContainerStatus.frozen)]),
          200,
        );
      });

      final result =
          await serviceFor(client).list(status: ContainerStatus.frozen, search: 'chili');

      expect(result, hasLength(1));
      expect(result.single.id, 'P-1');
      expect(result.single.status, ContainerStatus.frozen);
    });

    test('omits empty/blank search rather than sending an empty param', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters.containsKey('search'), isFalse);
        return http.Response(jsonEncode(<dynamic>[]), 200);
      });

      await serviceFor(client).list(search: '   ');
    });

    test('throws with the backend error message on a non-200', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'db down'}), 500),
      );

      await expectLater(
        serviceFor(client).list(),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'db down')),
      );
    });
  });

  group('getById', () {
    test('returns null on 404', () async {
      final client = MockClient((request) async => http.Response('', 404));
      expect(await serviceFor(client).getById('P-404'), isNull);
    });

    test('parses the container on 200', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode(rowJson(id: 'P-2')), 200),
      );
      final container = await serviceFor(client).getById('P-2');
      expect(container!.id, 'P-2');
    });
  });

  group('addId', () {
    test('POSTs the id and succeeds on 201', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/containers');
        expect(jsonDecode(request.body), {'id': 'P-9'});
        return http.Response('', 201);
      });
      await serviceFor(client).addId('P-9');
    });

    test('throws ContainerIdAlreadyExistsException on 409', () async {
      final client = MockClient((request) async => http.Response('', 409));
      await expectLater(
        serviceFor(client).addId('P-9'),
        throwsA(isA<ContainerIdAlreadyExistsException>()),
      );
    });
  });

  group('addRange', () {
    test('returns the added ids from the response body', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/containers/range');
        expect(jsonDecode(request.body), {'prefix': 'P', 'from': 1, 'to': 3});
        return http.Response(
          jsonEncode({
            'added': ['P-1', 'P-3']
          }),
          200,
        );
      });
      final added = await serviceFor(client).addRange(prefix: 'P', from: 1, to: 3);
      expect(added, ['P-1', 'P-3']);
    });

    test('throws InvalidRangeException on 400', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'range too large'}), 400),
      );
      await expectLater(
        serviceFor(client).addRange(prefix: 'P', from: 1, to: 9999),
        throwsA(isA<InvalidRangeException>()),
      );
    });
  });

  group('removeId', () {
    test('DELETEs and succeeds on 204', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/containers/P-1');
        return http.Response('', 204);
      });
      await serviceFor(client).removeId('P-1');
    });
  });

  group('createFilling', () {
    test('rejects an empty target list without making a request', () async {
      final client = MockClient((request) async => fail('should not be called'));
      expect(
        () => serviceFor(client).createFilling(
          date: null,
          status: ContainerStatus.frozen,
          ingredients: const [],
          targetIds: const [],
        ),
        throwsArgumentError,
      );
    });

    test('POSTs date/status/ingredients/targetIds', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/fillings');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['date'], '2026-01-15');
        expect(body['status'], 'frozen');
        expect(body['targetIds'], ['P-1', 'P-2']);
        return http.Response('', 200);
      });
      await serviceFor(client).createFilling(
        date: DateTime(2026, 1, 15),
        status: ContainerStatus.frozen,
        ingredients: const [Ingredient(name: 'Chili', quantity: '1L')],
        targetIds: const ['P-1', 'P-2'],
      );
    });

    test('throws ContainersNotFoundException with the missing ids on 404', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'missing': ['P-9']
          }),
          404,
        ),
      );
      await expectLater(
        serviceFor(client).createFilling(
          date: null,
          status: ContainerStatus.frozen,
          ingredients: const [],
          targetIds: const ['P-9'],
        ),
        throwsA(
          isA<ContainersNotFoundException>().having((e) => e.ids, 'ids', {'P-9'}),
        ),
      );
    });
  });

  group('emptyContainers', () {
    test('no-ops without a request when ids is empty', () async {
      final client = MockClient((request) async => fail('should not be called'));
      await serviceFor(client).emptyContainers(const []);
    });

    test('POSTs the ids', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/containers/empty');
        expect(jsonDecode(request.body), {
          'ids': ['P-1', 'P-2']
        });
        return http.Response('', 200);
      });
      await serviceFor(client).emptyContainers(const ['P-1', 'P-2']);
    });
  });

  group('updateContainer', () {
    test('PATCHes and returns the updated container', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/containers/P-1');
        return http.Response(jsonEncode(rowJson(id: 'P-1', status: ContainerStatus.frozen)), 200);
      });
      final updated = await serviceFor(client).updateContainer(
        'P-1',
        date: null,
        status: ContainerStatus.frozen,
        ingredients: const [],
      );
      expect(updated.status, ContainerStatus.frozen);
    });
  });

  group('exportAll / importAll', () {
    test('exportAll returns the decoded document', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'containers': []}), 200),
      );
      final document = await serviceFor(client).exportAll();
      expect(document, {'containers': []});
    });

    test('importAll POSTs the document as-is', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/import');
        expect(jsonDecode(request.body), {
          'containers': [
            {'id': 'P-1'}
          ]
        });
        return http.Response('', 200);
      });
      await serviceFor(client).importAll({
        'containers': [
          {'id': 'P-1'}
        ]
      });
    });

    test('importAll throws InvalidImportDataException on 400', () async {
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'error': 'bad shape'}), 400),
      );
      await expectLater(
        serviceFor(client).importAll({}),
        throwsA(isA<InvalidImportDataException>()),
      );
    });
  });
}
