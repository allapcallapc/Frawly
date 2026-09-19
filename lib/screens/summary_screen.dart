import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../providers/containers_provider.dart';
import '../utils/home_filter_request.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

/// Status x prefix counts, with row/column totals. Tapping a non-zero cell
/// jumps to Home pre-filtered to that status and prefix.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.onJumpToHome});

  final ValueChanged<HomeFilterRequest> onJumpToHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: Consumer<ContainersProvider>(
        builder: (context, provider, _) {
          if (!provider.hasAnyContainers) {
            return const EmptyState(message: 'No containers yet.');
          }
          final summary = provider.summary;
          final headerColor = Theme.of(context).colorScheme.surfaceContainerHighest;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: headerColor),
                    children: [
                      _HeaderCell(''),
                      for (final prefix in summary.prefixes) _HeaderCell(prefix),
                      const _HeaderCell('Total'),
                    ],
                  ),
                  for (final status in ContainerStatus.values)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: StatusBadge(status, compact: true),
                        ),
                        for (final prefix in summary.prefixes)
                          _CountCell(
                            count: summary.counts[prefix]![status]!,
                            onTap: () => onJumpToHome(
                              HomeFilterRequest(status: status, search: '$prefix-'),
                            ),
                          ),
                        _CountCell(
                          count: summary.statusTotals[status]!,
                          bold: true,
                          onTap: () => onJumpToHome(HomeFilterRequest(status: status)),
                        ),
                      ],
                    ),
                  TableRow(
                    decoration: BoxDecoration(color: headerColor),
                    children: [
                      const _HeaderCell('Total'),
                      for (final prefix in summary.prefixes)
                        _CountCell(
                          count: summary.prefixTotals[prefix]!,
                          bold: true,
                          onTap: () => onJumpToHome(HomeFilterRequest(search: '$prefix-')),
                        ),
                      _CountCell(count: summary.grandTotal, bold: true),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _CountCell extends StatelessWidget {
  const _CountCell({required this.count, this.onTap, this.bold = false});

  final int count;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final tappable = count > 0 && onTap != null;
    return InkWell(
      onTap: tappable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Center(
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: tappable ? Theme.of(context).colorScheme.primary : null,
              decoration: tappable ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}
