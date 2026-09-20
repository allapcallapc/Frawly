import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../models/ingredient.dart';
import '../providers/containers_provider.dart';
import '../utils/date_utils.dart';
import '../widgets/app_header.dart';
import '../widgets/container_checkbox_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/ingredient_list_editor.dart';

/// Pick a date/status/ingredients, then apply them to every selected
/// container at once. When [initial] is given (the "duplicate into a new
/// filling" action from Container detail), the form is pre-filled with
/// that container's data but nothing is pre-selected as a target.
class NewFillingScreen extends StatefulWidget {
  const NewFillingScreen({super.key, this.initial});

  final FreezerContainer? initial;

  @override
  State<NewFillingScreen> createState() => _NewFillingScreenState();
}

class _NewFillingScreenState extends State<NewFillingScreen> {
  late DateTime _date;
  late ContainerStatus _status;
  late List<Ingredient> _ingredients;
  Set<String> _selectedIds = {};
  bool _submitting = false;
  int _formGeneration = 0;

  @override
  void initState() {
    super.initState();
    _date = widget.initial?.date ?? localToday();
    _status = widget.initial?.status ?? ContainerStatus.frozen;
    _ingredients = widget.initial?.ingredients ?? const [];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one container.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<ContainersProvider>().createFilling(
            date: _date,
            status: _status,
            ingredients: _ingredients,
            targetIds: _selectedIds.toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filled ${_selectedIds.length} container(s).')),
      );
      setState(() {
        _selectedIds = {};
        _ingredients = const [];
        _formGeneration++;
      });
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
      body: Column(
        children: [
          AppHeader(
            title: 'New filling',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Consumer<ContainersProvider>(
              builder: (context, provider, _) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                      key: ValueKey('${widget.initial?.id}-$_formGeneration'),
                      ingredients: _ingredients,
                      onChanged: (v) => _ingredients = v,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Apply to containers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (!provider.hasAnyContainers)
                      const EmptyState(
                        message: 'No containers registered yet.\nAdd some in Manage containers.',
                      )
                    else
                      ContainerCheckboxSelector(
                        containers: provider.containers,
                        selectedIds: _selectedIds,
                        onChanged: (s) => setState(() => _selectedIds = s),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save filling'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
