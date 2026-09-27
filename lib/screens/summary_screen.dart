import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../providers/containers_provider.dart';
import '../theme/app_colors.dart';
import '../utils/container_summary.dart';
import '../utils/home_filter_request.dart';
import '../widgets/app_header.dart';
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
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          AppHeader(title: 'Summary', onBack: onBack),
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
                        child: LayoutBuilder(
                          // Fill the card's width when the columns fit, and
                          // only scroll sideways when there are too many
                          // prefixes to fit on screen.
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: _SummaryTable(
                                summary: summary,
                                onJumpToHome: onJumpToHome,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Tap a number to see those containers',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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

  /// Every count column is the same width, so pills line up in a grid
  /// whether they hold "1" or "32".
  static const _countColumnWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    final countColumns = summary.prefixes.length + 1;
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        // The status column soaks up any spare width.
        0: const IntrinsicColumnWidth(flex: 1),
        for (var i = 1; i <= countColumns; i++)
          i: const FixedColumnWidth(_countColumnWidth),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          children: [
            const _HeaderCell('Status', alignLeft: true),
            for (final prefix in summary.prefixes) _HeaderCell(prefix),
            const _HeaderCell('Total'),
          ],
        ),
        for (final status in ContainerStatus.values)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(status),
                ),
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
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.navy,
                ),
              ),
            ),
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
  const _HeaderCell(this.label, {this.alignLeft = false});

  final String label;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(alignLeft ? 16 : 4, 14, 4, 10),
      child: Text(
        label.toUpperCase(),
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// One count in the table. Per-prefix counts get a fixed-size pill tinted
/// in their status color; totals ([bold]) are plain bold numbers.
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
    final tinted = tint != null && count > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Material(
          color: tinted ? tint!.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: tappable ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 40,
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    fontSize: 16,
                    color: count == 0
                        ? Colors.grey.shade400
                        : tinted
                            ? Color.lerp(tint, Colors.black, 0.35)
                            : AppColors.navy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
