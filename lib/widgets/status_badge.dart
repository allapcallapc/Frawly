import 'package:flutter/material.dart';

import '../models/container_status.dart';

/// The single source of truth for status colors, so every screen (home
/// list, badges, summary table cells, checkbox selectors) uses the same
/// ones.
Color statusColor(ContainerStatus status) => switch (status) {
      ContainerStatus.vacant => Colors.grey.shade500,
      ContainerStatus.frozen => Colors.blue.shade600,
      ContainerStatus.construction => Colors.orange.shade700,
    };

/// The icon paired with each status everywhere a [StatusBadge] is shown.
IconData statusIcon(ContainerStatus status) => switch (status) {
      ContainerStatus.vacant => Icons.inventory_2_outlined,
      ContainerStatus.frozen => Icons.ac_unit,
      ContainerStatus.construction => Icons.build_outlined,
    };

/// A small pill showing a container's status (icon + label), in its status
/// color - used everywhere a status needs to be shown.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.compact = false});

  final ContainerStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: compact ? 13 : 15, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
