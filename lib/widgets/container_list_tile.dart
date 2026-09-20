import 'package:flutter/material.dart';

import '../models/freezer_container.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'status_badge.dart';

/// One row of the home list (or any other place a container needs to be
/// summarized): a dark id chip, date/status, and a one-line ingredient
/// summary, all on a white rounded card.
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdChip(container.id),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          formatDisplayDate(container.date),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusBadge(container.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      container.ingredientSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _IdChip extends StatelessWidget {
  const _IdChip(this.id);

  final String id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        id,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
