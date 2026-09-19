import 'package:flutter/material.dart';

import '../models/freezer_container.dart';
import '../utils/date_utils.dart';
import 'status_badge.dart';

/// One row of the home list (or any other place a container needs to be
/// summarized): id, date, status badge, and a one-line ingredient summary.
class ContainerListTile extends StatelessWidget {
  const ContainerListTile({
    super.key,
    required this.container,
    this.onTap,
    this.trailing,
  });

  final FreezerContainer container;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: statusColor(container.status).withValues(alpha: 0.15),
        foregroundColor: statusColor(container.status),
        child: Text(
          container.prefix,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      title: Row(
        children: [
          Text(container.id, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          StatusBadge(container.status, compact: true),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatDisplayDate(container.date)),
          Text(
            container.ingredientSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      isThreeLine: true,
      trailing: trailing,
    );
  }
}
