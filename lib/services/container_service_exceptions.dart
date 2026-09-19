/// Thrown by [ContainerService.addId] when the id is already registered.
class ContainerIdAlreadyExistsException implements Exception {
  ContainerIdAlreadyExistsException(this.id);
  final String id;

  @override
  String toString() => 'Container id "$id" already exists.';
}

/// Thrown by [ContainerService.createFilling] when one or more target ids
/// aren't in the registry - the whole write is rejected rather than
/// partially applying to the ids that do exist.
class ContainersNotFoundException implements Exception {
  ContainersNotFoundException(this.ids);
  final Set<String> ids;

  @override
  String toString() =>
      'Container id(s) not in the registry: ${ids.join(', ')}';
}

/// Thrown by [ContainerService.addRange] for an invalid/oversized range.
class InvalidRangeException implements Exception {
  InvalidRangeException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// Thrown by [ContainerService.importAll] when the document's shape is
/// invalid - nothing is written when this is thrown.
class InvalidImportDataException implements Exception {
  InvalidImportDataException(this.reason);
  final String reason;

  @override
  String toString() => 'Invalid import file: $reason';
}
