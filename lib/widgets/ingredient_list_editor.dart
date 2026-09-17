import 'package:flutter/material.dart';

import '../models/ingredient.dart';

/// Editable add/remove list of ingredient (name, quantity) rows, shared by
/// New filling and Container detail's edit form.
///
/// Reads [ingredients] only once, at construction, to seed its internal
/// text controllers - a parent that wants to reset the form to different
/// data (e.g. "duplicate into a new filling") should give this widget a
/// new `key` rather than expect it to pick up prop changes in place.
class IngredientListEditor extends StatefulWidget {
  const IngredientListEditor({
    super.key,
    required this.ingredients,
    required this.onChanged,
  });

  final List<Ingredient> ingredients;
  final ValueChanged<List<Ingredient>> onChanged;

  @override
  State<IngredientListEditor> createState() => _IngredientListEditorState();
}

class _IngredientListEditorState extends State<IngredientListEditor> {
  late final List<_IngredientRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.ingredients.isEmpty
        ? [_IngredientRow.empty()]
        : widget.ingredients.map(_IngredientRow.from).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emitChange() {
    widget.onChanged([
      for (final row in _rows)
        Ingredient(
          name: row.nameController.text,
          quantity: row.quantityController.text,
        ),
    ]);
  }

  void _addRow() {
    setState(() => _rows.add(_IngredientRow.empty()));
    _emitChange();
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rows[i].nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ingredient',
                      isDense: true,
                    ),
                    onChanged: (_) => _emitChange(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rows[i].quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      isDense: true,
                    ),
                    onChanged: (_) => _emitChange(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove ingredient',
                  onPressed: () => _removeRow(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add),
          label: const Text('Add ingredient'),
        ),
      ],
    );
  }
}

class _IngredientRow {
  _IngredientRow(this.nameController, this.quantityController);

  final TextEditingController nameController;
  final TextEditingController quantityController;

  factory _IngredientRow.empty() =>
      _IngredientRow(TextEditingController(), TextEditingController());

  factory _IngredientRow.from(Ingredient ingredient) => _IngredientRow(
        TextEditingController(text: ingredient.name),
        TextEditingController(text: ingredient.quantity),
      );

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}
