import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/ingredient.dart';
import 'package:frawly/widgets/ingredient_list_editor.dart';

void main() {
  testWidgets('seeds one empty row when given no ingredients', (tester) async {
    List<Ingredient>? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientListEditor(
            ingredients: const [],
            onChanged: (v) => latest = v,
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2)); // name + quantity
    expect(latest, isNull); // onChanged not called until an edit happens
  });

  testWidgets('editing the name field reports it via onChanged',
      (tester) async {
    List<Ingredient>? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientListEditor(
            ingredients: const [],
            onChanged: (v) => latest = v,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Chili');
    await tester.pump();

    expect(latest, hasLength(1));
    expect(latest!.first.name, 'Chili');
  });

  testWidgets('Add ingredient adds another row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientListEditor(
            ingredients: const [Ingredient(name: 'Rice', quantity: '1kg')],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.text('Add ingredient'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('removing a row drops it from onChanged', (tester) async {
    List<Ingredient>? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IngredientListEditor(
            ingredients: const [
              Ingredient(name: 'Rice', quantity: '1kg'),
              Ingredient(name: 'Beans', quantity: '2 cans'),
            ],
            onChanged: (v) => latest = v,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
    await tester.pump();

    expect(latest, hasLength(1));
    expect(latest!.single.name, 'Beans');
  });
}
