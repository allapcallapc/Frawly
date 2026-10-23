import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/utils/container_search.dart';

void main() {
  group('normalizeContainerSearch', () {
    test('inserts the hyphen into a bare letters-then-digits term', () {
      expect(normalizeContainerSearch('G5'), 'g-5');
      expect(normalizeContainerSearch(' p12 '), 'p-12');
    });

    test('leaves hyphenated and partial terms as literal, lowercased text', () {
      expect(normalizeContainerSearch('G-5'), 'g-5');
      expect(normalizeContainerSearch('G2-5'), 'g2-5');
      expect(normalizeContainerSearch('G-'), 'g-');
      expect(normalizeContainerSearch('G'), 'g');
      expect(normalizeContainerSearch('5'), '5');
      expect(normalizeContainerSearch(''), '');
    });

    test('treats whitespace and dash variants as the separator', () {
      expect(normalizeContainerSearch('G 5'), 'g-5');
      expect(normalizeContainerSearch('G–5'), 'g-5');
      expect(normalizeContainerSearch('G — 5'), 'g-5');
      expect(normalizeContainerSearch('G−5'), 'g-5');
    });
  });
}
