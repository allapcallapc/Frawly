import 'package:flutter_test/flutter_test.dart';
import 'package:frawly/models/container_status.dart';

void main() {
  group('ContainerStatus', () {
    test('fromValue maps every database value back to its enum', () {
      expect(ContainerStatus.fromValue('vacant'), ContainerStatus.vacant);
      expect(ContainerStatus.fromValue('frozen'), ContainerStatus.frozen);
      expect(
        ContainerStatus.fromValue('construction'),
        ContainerStatus.construction,
      );
    });

    test('fromValue throws for an unknown value', () {
      expect(() => ContainerStatus.fromValue('bogus'), throwsArgumentError);
    });

    test('value round-trips through fromValue', () {
      for (final status in ContainerStatus.values) {
        expect(ContainerStatus.fromValue(status.value), status);
      }
    });
  });
}
