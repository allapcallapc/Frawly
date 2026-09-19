import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/container_status.dart';
import 'package:frawly/models/freezer_container.dart';
import 'package:frawly/utils/container_summary.dart';

FreezerContainer _container(String id, ContainerStatus status) =>
    FreezerContainer(id: id, date: null, status: status, ingredients: const []);

void main() {
  group('ContainerSummary.from', () {
    test('counts containers by status x prefix with row/column totals', () {
      final summary = ContainerSummary.from([
        _container('P-1', ContainerStatus.frozen),
        _container('P-2', ContainerStatus.frozen),
        _container('P-3', ContainerStatus.vacant),
        _container('G-1', ContainerStatus.construction),
      ]);

      expect(summary.prefixes, ['G', 'P']);
      expect(summary.counts['P']![ContainerStatus.frozen], 2);
      expect(summary.counts['P']![ContainerStatus.vacant], 1);
      expect(summary.counts['P']![ContainerStatus.construction], 0);
      expect(summary.counts['G']![ContainerStatus.construction], 1);

      expect(summary.prefixTotals['P'], 3);
      expect(summary.prefixTotals['G'], 1);
      expect(summary.statusTotals[ContainerStatus.frozen], 2);
      expect(summary.statusTotals[ContainerStatus.vacant], 1);
      expect(summary.statusTotals[ContainerStatus.construction], 1);
      expect(summary.grandTotal, 4);
    });

    test('an empty container list produces an empty, zeroed summary', () {
      final summary = ContainerSummary.from(const []);
      expect(summary.prefixes, isEmpty);
      expect(summary.grandTotal, 0);
      expect(
        summary.statusTotals.values.every((count) => count == 0),
        isTrue,
      );
    });
  });
}
