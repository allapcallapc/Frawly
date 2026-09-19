import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/ingredient.dart';

void main() {
  group('Ingredient', () {
    test('round-trips through JSON', () {
      const ingredient = Ingredient(name: 'Chili', quantity: '500g');
      final json = ingredient.toJson();
      final restored = Ingredient.fromJson(json);
      expect(restored, ingredient);
    });

    test('fromJson defaults missing fields to empty strings', () {
      final ingredient = Ingredient.fromJson(const {});
      expect(ingredient.name, '');
      expect(ingredient.quantity, '');
    });

    test('hasName is false for blank/whitespace-only names', () {
      expect(const Ingredient(name: '', quantity: '1kg').hasName, isFalse);
      expect(const Ingredient(name: '   ', quantity: '1kg').hasName, isFalse);
      expect(const Ingredient(name: 'Rice', quantity: '').hasName, isTrue);
    });

    test('copyWith overrides only the given fields', () {
      const original = Ingredient(name: 'Rice', quantity: '1kg');
      final updated = original.copyWith(quantity: '2kg');
      expect(updated.name, 'Rice');
      expect(updated.quantity, '2kg');
    });
  });
}
