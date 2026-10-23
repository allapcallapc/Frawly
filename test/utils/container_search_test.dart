import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/utils/container_search.dart';

void main() {
  group('containerSearchForms', () {
    test('adds a hyphenated form for a bare letters-then-digits term', () {
      expect(containerSearchForms('G5'), ['g5', 'g-5']);
      expect(containerSearchForms(' p12 '), ['p12', 'p-12']);
    });

    test('keeps hyphenated and partial terms as literal, lowercased text', () {
      expect(containerSearchForms('G-5'), ['g-5']);
      expect(containerSearchForms('G2-5'), ['g2-5']);
      expect(containerSearchForms('G-'), ['g-']);
      expect(containerSearchForms('G'), ['g']);
      expect(containerSearchForms('5'), ['5']);
      expect(containerSearchForms('  '), isEmpty);
    });

    test('treats whitespace and dash variants as the separator', () {
      expect(containerSearchForms('G 5'), ['g-5']);
      expect(containerSearchForms('G–5'), ['g-5']);
      expect(containerSearchForms('G — 5'), ['g-5']);
      expect(containerSearchForms('G−5'), ['g-5']);
    });
  });
}
