import 'package:flutter/material.dart';

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../utils/date_utils.dart';
import 'status_badge.dart';

/// The scrollable checkbox list used by New filling and Empty containers to
/// pick target containers, with an optional prefix filter shown only when
/// more than one prefix is in use. With [hideVacantByDefault], vacant
/// containers are hidden until the "Show vacant" chip is toggled on.
///
/// By default the list is capped at a fixed height so it can sit inside a
/// scrolling form; set [expand] to have it fill the remaining height of a
/// bounded parent instead (e.g. inside an [Expanded]).
class ContainerCheckboxSelector extends StatefulWidget {
  const ContainerCheckboxSelector({
    super.key,
    required this.containers,
    required this.selectedIds,
    required this.onChanged,
    this.expand = false,
    this.hideVacantByDefault = false,
  });

  final List<FreezerContainer> containers;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool expand;
  final bool hideVacantByDefault;

  @override
  State<ContainerCheckboxSelector> createState() =>
      _ContainerCheckboxSelectorState();
}

class _ContainerCheckboxSelectorState extends State<ContainerCheckboxSelector> {
  String? _prefixFilter;
  bool _showVacant = false;

  @override
  Widget build(BuildContext context) {
    final prefixes = widget.containers.map((c) => c.prefix).toSet().toList()
      ..sort();
    final hideVacant = widget.hideVacantByDefault && !_showVacant;
    final prefixMatches = widget.containers
        .where((c) => _prefixFilter == null || c.prefix == _prefixFilter)
        .toList();
    final visible = hideVacant
        ? prefixMatches
            .where((c) => c.status != ContainerStatus.vacant)
            .toList()
        : prefixMatches;
    final showPrefixChips = prefixes.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (showPrefixChips || widget.hideVacantByDefault)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (showPrefixChips) ...[
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _prefixFilter == null,
                    onSelected: (_) => setState(() => _prefixFilter = null),
                  ),
                  for (final prefix in prefixes)
                    ChoiceChip(
                      label: Text(prefix),
                      selected: _prefixFilter == prefix,
                      onSelected: (_) =>
                          setState(() => _prefixFilter = prefix),
                    ),
                ],
                if (widget.hideVacantByDefault)
                  FilterChip(
                    label: const Text('Show vacant'),
                    selected: _showVacant,
                    onSelected: (v) => setState(() => _showVacant = v),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.selectedIds.length} selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () => widget.onChanged({
                            ...widget.selectedIds,
                            ...visible.map((c) => c.id),
                          }),
                  child: const Text('Select all'),
                ),
                TextButton(
                  onPressed: () => widget.onChanged(
                    widget.selectedIds
                        .where((id) => !visible.any((c) => c.id == id))
                        .toSet(),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
        _sized(
          visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    prefixMatches.isNotEmpty
                        ? 'All containers are already empty. '
                            'Tap Show vacant to see them.'
                        : 'No containers to show.',
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final container = visible[index];
                    final selected = widget.selectedIds.contains(container.id);
                    return CheckboxListTile(
                      value: selected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(container.id),
                      subtitle: Row(
                        children: [
                          Text(formatDisplayDate(container.date)),
                          const SizedBox(width: 8),
                          StatusBadge(container.status, compact: true),
                        ],
                      ),
                      onChanged: (checked) {
                        final next = Set<String>.from(widget.selectedIds);
                        if (checked ?? false) {
                          next.add(container.id);
                        } else {
                          next.remove(container.id);
                        }
                        widget.onChanged(next);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _sized(Widget list) => widget.expand
      ? Expanded(child: list)
      : ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: list,
        );
}
