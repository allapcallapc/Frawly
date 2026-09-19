import '../models/container_status.dart';
import '../models/freezer_container.dart';

/// Counts of containers grouped by status x prefix, with row/column
/// totals - the Summary screen's table, computed client-side from an
/// already-fetched container list (see CLAUDE.md's "avoid RPCs" section).
class ContainerSummary {
  ContainerSummary({
    required this.prefixes,
    required this.counts,
    required this.prefixTotals,
    required this.statusTotals,
    required this.grandTotal,
  });

  /// Sorted list of every prefix in use.
  final List<String> prefixes;

  /// counts[prefix][status] - always present (0 if none), so the UI never
  /// has to null-check a cell.
  final Map<String, Map<ContainerStatus, int>> counts;

  /// Column totals: one container count per prefix.
  final Map<String, int> prefixTotals;

  /// Row totals: one container count per status.
  final Map<ContainerStatus, int> statusTotals;

  final int grandTotal;

  factory ContainerSummary.from(List<FreezerContainer> containers) {
    final prefixes = containers.map((c) => c.prefix).toSet().toList()..sort();
    final counts = <String, Map<ContainerStatus, int>>{
      for (final prefix in prefixes)
        prefix: {for (final status in ContainerStatus.values) status: 0},
    };
    final statusTotals = {for (final status in ContainerStatus.values) status: 0};
    final prefixTotals = {for (final prefix in prefixes) prefix: 0};

    for (final container in containers) {
      counts[container.prefix]![container.status] =
          counts[container.prefix]![container.status]! + 1;
      statusTotals[container.status] = statusTotals[container.status]! + 1;
      prefixTotals[container.prefix] = prefixTotals[container.prefix]! + 1;
    }

    return ContainerSummary(
      prefixes: prefixes,
      counts: counts,
      prefixTotals: prefixTotals,
      statusTotals: statusTotals,
      grandTotal: containers.length,
    );
  }
}
