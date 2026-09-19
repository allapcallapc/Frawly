import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/container_status.dart';
import 'package:frawly/models/freezer_container.dart';

void main() {
  group('FreezerContainer.fromRow', () {
    test('parses a row shaped like a real jsonDecode()d PostgREST response',
        () {
      // Mirrors exactly what the backend hands back: the whole
      // response body goes through dart:convert's jsonDecode, so nested
      // "objects" are genuinely Map<String, dynamic> - not a hand-built
      // Dart literal map, which could hide a type-check mistake in
      // fromRow's ingredient parsing.
      final row = jsonDecode('''
        {
          "id": "P-3",
          "date": "2026-01-05",
          "status": "frozen",
          "ingredients": [
            {"name": "Chili", "quantity": "500g"},
            {"name": "Rice", "quantity": "2 portions"}
          ]
        }
      ''') as Map<String, dynamic>;

      final container = FreezerContainer.fromRow(row);

      expect(container.id, 'P-3');
      expect(container.prefix, 'P');
      expect(container.date, DateTime(2026, 1, 5));
      expect(container.status, ContainerStatus.frozen);
      expect(container.ingredients, hasLength(2));
      expect(container.ingredients.first.name, 'Chili');
      expect(container.ingredients.first.quantity, '500g');
    });

    test('parses a null date and empty ingredients (vacant container)', () {
      final row = jsonDecode('''
        {"id": "G-1", "date": null, "status": "vacant", "ingredients": []}
      ''') as Map<String, dynamic>;

      final container = FreezerContainer.fromRow(row);

      expect(container.date, isNull);
      expect(container.status, ContainerStatus.vacant);
      expect(container.ingredients, isEmpty);
      expect(container.ingredientSummary, 'No ingredients');
    });

    test('prefix is the part of id before the first "-"', () {
      final row = jsonDecode(
        '{"id": "AB-12", "date": null, "status": "vacant", "ingredients": []}',
      ) as Map<String, dynamic>;
      expect(FreezerContainer.fromRow(row).prefix, 'AB');
    });
  });
}
