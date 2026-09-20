import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../providers/containers_provider.dart';
import '../theme/app_colors.dart';
import '../utils/home_filter_request.dart';
import '../widgets/app_header.dart';
import '../widgets/container_list_tile.dart';
import '../widgets/empty_state.dart';
import 'container_detail_screen.dart';

/// Status filter tabs + search box + the sorted container list. The one
/// screen every other screen (Summary's cell tap, Container detail's back
/// button) ultimately routes back to.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.filterRequests,
    this.onOpenSummary,
    this.onOpenManage,
    this.onNewFilling,
    this.onEmptyContainers,
  });

  /// External requests to apply a filter here (see [HomeFilterRequest]) -
  /// consumed and reset to null once applied.
  final ValueNotifier<HomeFilterRequest?> filterRequests;

  /// Header shortcuts and quick-action buttons - all optional so this
  /// screen still works standalone (e.g. in tests) without a shell wiring
  /// them up.
  final VoidCallback? onOpenSummary;
  final VoidCallback? onOpenManage;
  final VoidCallback? onNewFilling;
  final VoidCallback? onEmptyContainers;

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
      backgroundColor: AppColors.background,
      body: Consumer<ContainersProvider>(
        builder: (context, provider, _) {
          final filtered = provider.filtered(
            status: _status,
            search: _searchController.text,
          );

          final totalCount = provider.containers.length;
          return Column(
            children: [
              AppHeader(
                title:
                    '$totalCount container${totalCount == 1 ? '' : 's'} tracked',
                actions: [
                  if (widget.onOpenSummary != null)
                    AppHeaderIconButton(
                      icon: Icons.grid_view_rounded,
                      tooltip: 'Summary',
                      onPressed: widget.onOpenSummary!,
                    ),
                  if (widget.onOpenManage != null)
                    AppHeaderIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Manage containers',
                      onPressed: widget.onOpenManage!,
                    ),
                ],
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: _buildBody(provider, filtered),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.onNewFilling != null)
                            _PillButton(
                              icon: Icons.add,
                              label: 'New filling',
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: widget.onNewFilling!,
                            ),
                          if (widget.onEmptyContainers != null) ...[
                            const SizedBox(height: 10),
                            _PillButton(
                              icon: Icons.inventory_2_outlined,
                              label: 'Empty containers',
                              color: Colors.grey.shade700,
                              onPressed: widget.onEmptyContainers!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    ContainersProvider provider,
    List<FreezerContainer> filtered,
  ) {
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

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _StatusSegmentedControl(
              status: _status,
              onChanged: (status) => setState(() => _status = status),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by container ID...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_searchController.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: !provider.hasAnyContainers
                ? const EmptyState(
                    message:
                        'No containers yet.\nAdd some from Manage containers.',
                  )
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        message: 'No containers match this search/filter.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: filtered.length,
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
  }
}

class _StatusSegmentedControl extends StatelessWidget {
  const _StatusSegmentedControl({required this.status, required this.onChanged});

  final ContainerStatus? status;
  final ValueChanged<ContainerStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segment(context, label: 'All', selected: status == null, onTap: () => onChanged(null)),
          for (final s in ContainerStatus.values)
            _segment(
              context,
              label: s.label,
              selected: status == s,
              onTap: () => onChanged(s),
            ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
