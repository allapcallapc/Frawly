import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../models/ingredient.dart';
import '../providers/containers_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/ingredient_list_editor.dart';
import '../widgets/status_badge.dart';
import 'new_filling_screen.dart';

/// View/edit a single container's date/status/ingredients, duplicate its
/// current (saved) contents into a new filling, or empty just this one.
class ContainerDetailScreen extends StatefulWidget {
  const ContainerDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<ContainerDetailScreen> createState() => _ContainerDetailScreenState();
}

class _ContainerDetailScreenState extends State<ContainerDetailScreen> {
  DateTime? _date;
  ContainerStatus _status = ContainerStatus.vacant;
  List<Ingredient> _ingredients = const [];
  bool _initialized = false;
  bool _saving = false;
  int _formGeneration = 0;

  void _seedFrom(FreezerContainer container) {
    if (_initialized) return;
    _date = container.date;
    _status = container.status;
    _ingredients = container.ingredients;
    _initialized = true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? localToday(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ContainersProvider>().updateContainer(
            widget.id,
            date: _date,
            status: _status,
            ingredients: _ingredients,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _emptyThisOne() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty this container?'),
        content: Text(
          '${widget.id} will be reset to vacant, with no date and no '
          'ingredients.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<ContainersProvider>().emptyContainers([widget.id]);
      if (!mounted) return;
      setState(() {
        _date = null;
        _status = ContainerStatus.vacant;
        _ingredients = const [];
        _formGeneration++;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Emptied.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not empty: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _duplicateIntoNewFilling(FreezerContainer container) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NewFillingScreen(initial: container)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContainersProvider>(
      builder: (context, provider, _) {
        final container = provider.byId(widget.id);
        if (container == null) {
          return Scaffold(
            body: Column(
              children: [
                AppHeader(
                  title: widget.id,
                  onBack: () => Navigator.of(context).pop(),
                ),
                const Expanded(
                  child: EmptyState(
                    icon: Icons.error_outline,
                    message: 'This container no longer exists.',
                  ),
                ),
              ],
            ),
          );
        }
        _seedFrom(container);

        return Scaffold(
          body: Column(
            children: [
              AppHeader(
                title: widget.id,
                onBack: () => Navigator.of(context).pop(),
                actions: [
                  AppHeaderIconButton(
                    icon: Icons.copy_all_outlined,
                    tooltip: 'Duplicate into new filling',
                    onPressed: () => _duplicateIntoNewFilling(container),
                  ),
                  AppHeaderIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: 'Empty this container',
                    onPressed: _saving ? null : _emptyThisOne,
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Text(
                          container.prefix,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(width: 12),
                        StatusBadge(_status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(formatDisplayDate(_date)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ContainerStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final status in ContainerStatus.values)
                                DropdownMenuItem(
                                  value: status,
                                  child: Text(status.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _status = value ?? _status),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    IngredientListEditor(
                      key: ValueKey('${widget.id}-$_formGeneration'),
                      ingredients: _ingredients,
                      onChanged: (v) => _ingredients = v,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
