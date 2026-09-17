// Integration suite for ContainerService's real Supabase-calling behavior -
// in particular the atomicity/rejection guarantees a unit test against a
// fake client can't actually prove (a bulk update either fully applying or
// not, addRange really skipping existing ids server-side via
// ON CONFLICT DO NOTHING, and the import_containers RPC really replacing
// every row). Runs against a local Supabase stack only (`supabase start`),
// never a hosted project - see CLAUDE.md's "Backend hosting" section.
// Tagged 'integration' and excluded from the default `flutter test` run
// (see dart_test.yaml and .github/workflows/test.yml) since it needs
// Docker.

@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frawly/models/container_status.dart';
import 'package:frawly/models/ingredient.dart';
import 'package:frawly/services/container_service.dart';
import 'package:frawly/services/container_service_exceptions.dart';

void main() {
  late SupabaseClient admin;
  late ContainerService service;

  setUpAll(() async {
    final url = Platform.environment['SUPABASE_TEST_URL'];
    final serviceRoleKey =
        Platform.environment['SUPABASE_TEST_SERVICE_ROLE_KEY'];

    if (url == null || serviceRoleKey == null) {
      throw StateError(
        'SUPABASE_TEST_URL and SUPABASE_TEST_SERVICE_ROLE_KEY must be set '
        'to run this suite - see .github/workflows/test.yml\'s '
        'integration-test job, which starts a local Supabase stack and '
        'sets both automatically.',
      );
    }

    admin = SupabaseClient(url, serviceRoleKey);
    service = ContainerService(client: admin);
  });

  tearDown(() async {
    // Wipe every row between tests so they don't interfere with each
    // other's id space.
    await admin.from('containers').delete().neq('id', '__never_matches__');
  });

  group('addId / removeId', () {
    test('addId then removeId round-trips through the registry', () async {
      await service.addId('P-1');
      final container = await service.getById('P-1');
      expect(container, isNotNull);
      expect(container!.status, ContainerStatus.vacant);

      await service.removeId('P-1');
      expect(await service.getById('P-1'), isNull);
    });

    test('addId rejects a duplicate id', () async {
      await service.addId('P-1');
      expect(
        () => service.addId('P-1'),
        throwsA(isA<ContainerIdAlreadyExistsException>()),
      );
    });
  });

  group('addRange', () {
    test('skips existing ids instead of failing the whole range', () async {
      await service.addId('P-2');
      final added = await service.addRange(prefix: 'P', from: 1, to: 3);
      expect(added.toSet(), {'P-1', 'P-3'}); // P-2 already existed, skipped

      final registry = await service.getRegistry();
      expect(registry.map((c) => c.id).toSet(), {'P-1', 'P-2', 'P-3'});
    });
  });

  group('createFilling', () {
    test('atomically overwrites every target container', () async {
      await service.addId('P-1');
      await service.addId('P-2');

      await service.createFilling(
        date: DateTime(2026, 2, 1),
        status: ContainerStatus.frozen,
        ingredients: const [Ingredient(name: 'Soup', quantity: '1L')],
        targetIds: ['P-1', 'P-2'],
      );

      final p1 = await service.getById('P-1');
      final p2 = await service.getById('P-2');
      expect(p1!.status, ContainerStatus.frozen);
      expect(p1.ingredients.single.name, 'Soup');
      expect(p2!.status, ContainerStatus.frozen);
    });

    test('rejects the whole write if any target id is unregistered',
        () async {
      await service.addId('P-1');

      expect(
        () => service.createFilling(
          date: DateTime(2026, 2, 1),
          status: ContainerStatus.frozen,
          ingredients: const [],
          targetIds: ['P-1', 'P-99'],
        ),
        throwsA(isA<ContainersNotFoundException>()),
      );

      // Nothing partially applied to the id that *does* exist.
      final p1 = await service.getById('P-1');
      expect(p1!.status, ContainerStatus.vacant);
    });

    test('drops ingredient rows with an empty name', () async {
      await service.addId('P-1');
      await service.createFilling(
        date: DateTime(2026, 2, 1),
        status: ContainerStatus.frozen,
        ingredients: const [
          Ingredient(name: 'Soup', quantity: '1L'),
          Ingredient(name: '', quantity: 'discarded'),
        ],
        targetIds: ['P-1'],
      );

      final p1 = await service.getById('P-1');
      expect(p1!.ingredients, hasLength(1));
      expect(p1.ingredients.single.name, 'Soup');
    });
  });

  group('emptyContainers', () {
    test('resets every target to vacant/null date/no ingredients', () async {
      await service.addId('P-1');
      await service.createFilling(
        date: DateTime(2026, 2, 1),
        status: ContainerStatus.frozen,
        ingredients: const [Ingredient(name: 'Soup', quantity: '1L')],
        targetIds: ['P-1'],
      );

      await service.emptyContainers(['P-1']);

      final p1 = await service.getById('P-1');
      expect(p1!.status, ContainerStatus.vacant);
      expect(p1.date, isNull);
      expect(p1.ingredients, isEmpty);
    });
  });

  group('importAll', () {
    test('atomically replaces every row', () async {
      await service.addId('X-1');
      await service.addId('X-2');

      await service.importAll({
        'containers': [
          {
            'id': 'Y-1',
            'date': '2026-03-01',
            'status': 'frozen',
            'ingredients': [
              {'name': 'Curry', 'quantity': '2 portions'},
            ],
          },
        ],
      });

      final registry = await service.getRegistry();
      expect(registry.map((c) => c.id).toList(), ['Y-1']);
      expect(registry.single.status, ContainerStatus.frozen);
    });
  });
}
