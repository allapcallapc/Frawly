import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/container_status.dart';
import 'package:frawly/models/freezer_container.dart';
import 'package:frawly/models/ingredient.dart';
import 'package:frawly/widgets/container_list_tile.dart';
import 'package:frawly/widgets/empty_state.dart';
import 'package:frawly/widgets/status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StatusBadge shows the status label', (tester) async {
    await tester.pumpWidget(_wrap(const StatusBadge(ContainerStatus.frozen)));
    expect(find.text('Frozen'), findsOneWidget);
  });

  testWidgets('EmptyState shows its message', (tester) async {
    await tester.pumpWidget(
      _wrap(const EmptyState(message: 'No containers yet.')),
    );
    expect(find.text('No containers yet.'), findsOneWidget);
  });

  testWidgets('ContainerListTile shows id, status, and ingredient summary',
      (tester) async {
    final container = FreezerContainer(
      id: 'P-3',
      date: DateTime(2026, 1, 5),
      status: ContainerStatus.frozen,
      ingredients: const [Ingredient(name: 'Chili', quantity: '500g')],
    );

    await tester.pumpWidget(_wrap(ContainerListTile(container: container)));

    expect(find.text('P-3'), findsOneWidget);
    expect(find.text('Frozen'), findsOneWidget);
    expect(find.textContaining('Chili'), findsOneWidget);
  });

  testWidgets('ContainerListTile calls onTap when tapped', (tester) async {
    final container = FreezerContainer(
      id: 'P-1',
      date: null,
      status: ContainerStatus.vacant,
      ingredients: const [],
    );
    var tapped = false;

    await tester.pumpWidget(
      _wrap(
        ContainerListTile(container: container, onTap: () => tapped = true),
      ),
    );
    await tester.tap(find.byType(ContainerListTile));

    expect(tapped, isTrue);
  });
}
