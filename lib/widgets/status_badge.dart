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

/// A small pill showing a container's status, in its status color -
/// used everywhere a status needs to be shown.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.compact = false});

  final ContainerStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 11 : 13,
        ),
      ),
    );
  }
}
