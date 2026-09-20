import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../providers/containers_provider.dart';
import '../theme/app_colors.dart';
import '../utils/container_summary.dart';
import '../utils/home_filter_request.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

/// Status x prefix counts, with row/column totals. Tapping a non-zero cell
/// jumps to Home pre-filtered to that status and prefix.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.onJumpToHome, this.onBack});

  final ValueChanged<HomeFilterRequest> onJumpToHome;

  /// Shown as a back chevron in the header when set - lets a shell route
  /// this back to Home, matching the rest of the app's navigation.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _SummaryHeader(onBack: onBack),
          Expanded(
            child: Consumer<ContainersProvider>(
              builder: (context, provider, _) {
                if (!provider.hasAnyContainers) {
                  return const EmptyState(message: 'No containers yet.');
                }
                final summary = provider.summary;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _SummaryTable(
                            summary: summary,
                            onJumpToHome: onJumpToHome,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap a number to see those containers on the home list.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: onBack,
              )
            else
              const SizedBox(width: 12),
            const Text(
              'Summary',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.summary, required this.onJumpToHome});

  final ContainerSummary summary;
  final ValueChanged<HomeFilterRequest> onJumpToHome;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        TableRow(
          children: [
            const _HeaderCell('Status'),
            for (final prefix in summary.prefixes) _HeaderCell(prefix),
            const _HeaderCell('Total'),
          ],
        ),
        for (final status in ContainerStatus.values)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: StatusBadge(status, compact: true),
              ),
              for (final prefix in summary.prefixes)
                _CountCell(
                  count: summary.counts[prefix]![status]!,
                  tint: statusColor(status),
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
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          children: [
            const _HeaderCell('Total', bold: true),
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
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.bold = false});

  final String label;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        label,
        style: bold
            ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
            : TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
      ),
    );
  }
}

class _CountCell extends StatelessWidget {
  const _CountCell({
    required this.count,
    this.tint,
    this.onTap,
    this.bold = false,
  });

  final int count;
  final Color? tint;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final tappable = count > 0 && onTap != null;
    return InkWell(
      onTap: tappable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tint != null && count > 0
                  ? tint!.withValues(alpha: 0.12)
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: bold ? 16 : 15,
                color: count == 0 ? Colors.grey.shade400 : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
