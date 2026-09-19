/// Mirrors the `status` check constraint on the `containers` table
/// (see backend/migrations/0001_initial_schema.sql) - keep the two in
/// sync.
enum ContainerStatus {
  vacant('vacant', 'Vacant'),
  frozen('frozen', 'Frozen'),
  construction('construction', 'Under construction');

  const ContainerStatus(this.value, this.label);

  /// The value stored in the database.
  final String value;

  /// Human-readable label for the UI.
  final String label;

  static ContainerStatus fromValue(String value) => ContainerStatus.values
      .firstWhere((status) => status.value == value,
          orElse: () =>
              throw ArgumentError('Unknown container status: $value'));
}
