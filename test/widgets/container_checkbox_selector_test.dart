import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/container_status.dart';
import 'package:frawly/models/freezer_container.dart';
import 'package:frawly/widgets/container_checkbox_selector.dart';

FreezerContainer _container(String id, ContainerStatus status) =>
    FreezerContainer(id: id, date: null, status: status, ingredients: const []);

void main() {
  testWidgets('tapping a checkbox adds its id via onChanged', (tester) async {
    Set<String>? latest;
    final containers = [
      _container('P-1', ContainerStatus.vacant),
      _container('P-2', ContainerStatus.frozen),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContainerCheckboxSelector(
            containers: containers,
            selectedIds: const {},
            onChanged: (s) => latest = s,
          ),
        ),
      ),
    );

    await tester.tap(find.text('P-1'));
    await tester.pump();

    expect(latest, {'P-1'});
  });

  testWidgets('prefix filter chips only show when more than one prefix exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContainerCheckboxSelector(
            containers: [_container('P-1', ContainerStatus.vacant)],
            selectedIds: const {},
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('prefix filter narrows the visible containers', (tester) async {
    final containers = [
      _container('P-1', ContainerStatus.vacant),
      _container('G-1', ContainerStatus.frozen),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContainerCheckboxSelector(
            containers: containers,
            selectedIds: const {},
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('G-1'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'P'));
    await tester.pump();

    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('G-1'), findsNothing);
  });

  testWidgets('Select all selects every currently visible container',
      (tester) async {
    Set<String>? latest;
    final containers = [
      _container('P-1', ContainerStatus.vacant),
      _container('P-2', ContainerStatus.frozen),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContainerCheckboxSelector(
            containers: containers,
            selectedIds: const {},
            onChanged: (s) => latest = s,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Select all'));
    await tester.pump();

    expect(latest, {'P-1', 'P-2'});
  });
}
