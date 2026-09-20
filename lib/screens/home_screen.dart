import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../providers/containers_provider.dart';
import '../utils/home_filter_request.dart';
import '../widgets/container_list_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'container_detail_screen.dart';

/// Status filter tabs + search box + the sorted container list. The one
/// screen every other screen (Summary's cell tap, Container detail's back
/// button) ultimately routes back to.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.filterRequests});

  /// External requests to apply a filter here (see [HomeFilterRequest]) -
  /// consumed and reset to null once applied.
  final ValueNotifier<HomeFilterRequest?> filterRequests;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ContainerStatus? _status;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.filterRequests.addListener(_applyPendingFilterRequest);
  }

  @override
  void dispose() {
    widget.filterRequests.removeListener(_applyPendingFilterRequest);
    _searchController.dispose();
    super.dispose();
  }

  void _applyPendingFilterRequest() {
    final request = widget.filterRequests.value;
    if (request == null) return;
    setState(() {
      _status = request.status;
      _searchController.text = request.search;
    });
    widget.filterRequests.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Frawly')),
      body: Consumer<ContainersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && !provider.hasLoadedOnce) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && !provider.hasLoadedOnce) {
            return EmptyState(
              icon: Icons.error_outline,
              message: 'Could not load containers.\n${provider.error}',
              action: FilledButton(
                onPressed: provider.load,
                child: const Text('Retry'),
              ),
            );
          }

          final filtered = provider.filtered(
            status: _status,
            search: _searchController.text,
          );

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by container id',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(_searchController.clear),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusFilterChip(
                          label: 'All',
                          selected: _status == null,
                          onTap: () => setState(() => _status = null),
                        ),
                        for (final status in ContainerStatus.values)
                          _StatusFilterChip(
                            label: status.label,
                            color: statusColor(status),
                            selected: _status == status,
                            onTap: () => setState(() => _status = status),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: !provider.hasAnyContainers
                      ? const EmptyState(
                          message:
                              'No containers yet.\nAdd some from Manage containers.',
                        )
                      : filtered.isEmpty
                          ? const EmptyState(
                              icon: Icons.search_off,
                              message:
                                  'No containers match this search/filter.',
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final container = filtered[index];
                                return ContainerListTile(
                                  container: container,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ContainerDetailScreen(
                                        id: container.id,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color?.withValues(alpha: 0.2),
        labelStyle: selected && color != null
            ? TextStyle(color: color, fontWeight: FontWeight.w600)
            : null,
      ),
    );
  }
}
