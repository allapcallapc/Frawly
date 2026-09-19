import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/containers_provider.dart';
import '../widgets/container_checkbox_selector.dart';
import '../widgets/empty_state.dart';

/// Select containers, then reset all of them to vacant/no date/no
/// ingredients in one action.
class EmptyContainersScreen extends StatefulWidget {
  const EmptyContainersScreen({super.key});

  @override
  State<EmptyContainersScreen> createState() => _EmptyContainersScreenState();
}

class _EmptyContainersScreenState extends State<EmptyContainersScreen> {
  Set<String> _selectedIds = {};
  bool _submitting = false;

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one container.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context
          .read<ContainersProvider>()
          .emptyContainers(_selectedIds.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Emptied ${_selectedIds.length} container(s).')),
      );
      setState(() => _selectedIds = {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empty containers')),
      body: Consumer<ContainersProvider>(
        builder: (context, provider, _) {
          if (!provider.hasAnyContainers) {
            return const EmptyState(
              message:
                  'No containers registered yet.\nAdd some in Manage containers.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Selected containers will be reset to vacant, with no date '
                'and no ingredients.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ContainerCheckboxSelector(
                containers: provider.containers,
                selectedIds: _selectedIds,
                onChanged: (s) => setState(() => _selectedIds = s),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Empty selected containers'),
              ),
            ],
          );
        },
      ),
    );
  }
}
