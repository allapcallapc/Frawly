import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../models/ingredient.dart';
import '../utils/date_utils.dart';
import 'container_service_exceptions.dart';

/// Everything that talks to Supabase. Every write here is a single
/// PostgREST request (PostgREST wraps one request in one transaction), so
/// bulk operations are atomic without needing an RPC - see CLAUDE.md's
/// "avoid RPCs" section. The one exception is [importAll], which really
/// does need a transaction spanning "delete everything, then insert this"
/// and calls the `import_containers` database function for it.
class ContainerService {
  ContainerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int maxRangeSize = 500;
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9]+-[0-9]+$');

  PostgrestQueryBuilder get _table => _client.from('containers');

  /// Lists containers, optionally filtered by [status] and/or a text
  /// [search] on id, sorted by date ascending (vacant/null dates first).
  Future<List<FreezerContainer>> list({
    ContainerStatus? status,
    String? search,
  }) async {
    var query = _table.select();
    if (status != null) {
      query = query.eq('status', status.value);
    }
    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      query = query.ilike('id', '%$trimmedSearch%');
    }
    final rows = await query
        .order('date', ascending: true, nullsFirst: true)
        .order('id', ascending: true);
    return rows.map(FreezerContainer.fromRow).toList();
  }

  /// A single container, or null if [id] isn't registered.
  Future<FreezerContainer?> getById(String id) async {
    final row = await _table.select().eq('id', id).maybeSingle();
    return row == null ? null : FreezerContainer.fromRow(row);
  }

  /// The full registry - every registered container, with its current
  /// date/status/ingredients. Sorted by prefix then by the numeric part of
  /// the id (so "P-2" sorts before "P-10", unlike a plain text sort) - this
  /// is what the New filling/Empty containers checkbox selectors and the
  /// Manage containers screen list against.
  Future<List<FreezerContainer>> getRegistry() async {
    final rows = await _table.select().order('id', ascending: true);
    final containers = rows.map(FreezerContainer.fromRow).toList();
    containers.sort((a, b) {
      final prefixCompare = a.prefix.compareTo(b.prefix);
      if (prefixCompare != 0) return prefixCompare;
      return _numericSuffix(a.id).compareTo(_numericSuffix(b.id));
    });
    return containers;
  }

  static int _numericSuffix(String id) {
    final match = RegExp(r'-(\d+)$').firstMatch(id);
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  /// Adds a single id to the registry. Throws
  /// [ContainerIdAlreadyExistsException] if it's already registered.
  Future<void> addId(String id) async {
    try {
      await _table.insert({'id': id});
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw ContainerIdAlreadyExistsException(id);
      }
      rethrow;
    }
  }

  /// Adds every "`<prefix>-<n>`" for n in [from]..[to] (inclusive) that isn't
  /// already registered - existing ids are skipped, not rejected. Returns
  /// the ids that were actually added. Throws [InvalidRangeException] if
  /// the range is empty, backwards, or larger than [maxRangeSize].
  Future<List<String>> addRange({
    required String prefix,
    required int from,
    required int to,
  }) async {
    if (prefix.trim().isEmpty) {
      throw InvalidRangeException('Prefix must not be empty.');
    }
    if (to < from) {
      throw InvalidRangeException('Range end must not be before its start.');
    }
    final count = to - from + 1;
    if (count > maxRangeSize) {
      throw InvalidRangeException(
        'Range is too large ($count ids) - the limit is $maxRangeSize.',
      );
    }
    final ids = [for (var n = from; n <= to; n++) '$prefix-$n'];
    final inserted = await _table
        .upsert(
          [for (final id in ids) {'id': id}],
          onConflict: 'id',
          ignoreDuplicates: true,
        )
        .select('id');
    return inserted.map((row) => row['id'] as String).toList();
  }

  /// Removes [id] from the registry, deleting its stored data with it.
  Future<void> removeId(String id) async {
    await _table.delete().eq('id', id);
  }

  /// Overwrites every target container's date/status/ingredients in one
  /// atomic write. Throws [ContainersNotFoundException] - without writing
  /// anything - if any [targetIds] entry isn't registered.
  Future<void> createFilling({
    required DateTime? date,
    required ContainerStatus status,
    required List<Ingredient> ingredients,
    required List<String> targetIds,
  }) async {
    if (targetIds.isEmpty) {
      throw ArgumentError('createFilling needs at least one target id.');
    }
    final existingRows =
        await _table.select('id').inFilter('id', targetIds);
    final existingIds = existingRows.map((r) => r['id'] as String).toSet();
    final missing = targetIds.toSet().difference(existingIds);
    if (missing.isNotEmpty) {
      throw ContainersNotFoundException(missing);
    }
    await _table.update({
      'date': date == null ? null : formatDateKey(date),
      'status': status.value,
      'ingredients': _sanitizeIngredients(ingredients)
          .map((i) => i.toJson())
          .toList(),
    }).inFilter('id', targetIds);
  }

  /// Resets every one of [ids] to vacant/null date/no ingredients, in one
  /// atomic write.
  Future<void> emptyContainers(List<String> ids) async {
    if (ids.isEmpty) return;
    await _table.update({
      'date': null,
      'status': ContainerStatus.vacant.value,
      'ingredients': const [],
    }).inFilter('id', ids);
  }

  /// Updates a single container's date/status/ingredients (not part of a
  /// bulk filling).
  Future<FreezerContainer> updateContainer(
    String id, {
    required DateTime? date,
    required ContainerStatus status,
    required List<Ingredient> ingredients,
  }) async {
    final row = await _table.update({
      'date': date == null ? null : formatDateKey(date),
      'status': status.value,
      'ingredients': _sanitizeIngredients(ingredients)
          .map((i) => i.toJson())
          .toList(),
    }).eq('id', id).select().single();
    return FreezerContainer.fromRow(row);
  }

  /// The full registry + all container data as one JSON-serializable
  /// document, for [importAll]/file export.
  Future<Map<String, dynamic>> exportAll() async {
    final containers = await getRegistry();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'containers': [
        for (final c in containers)
          {
            'id': c.id,
            'date': c.date == null ? null : formatDateKey(c.date!),
            'status': c.status.value,
            'ingredients': c.ingredients.map((i) => i.toJson()).toList(),
          },
      ],
    };
  }

  /// Replaces all current data with [document] (the shape [exportAll()]
  /// produces), atomically - either every row is replaced or none are.
  /// Validates the document's shape first; throws
  /// [InvalidImportDataException] (without writing anything) if it's
  /// invalid.
  Future<void> importAll(Map<String, dynamic> document) async {
    final rawContainers = document['containers'];
    if (rawContainers is! List) {
      throw InvalidImportDataException('Missing or invalid "containers" list.');
    }
    final validated = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (var i = 0; i < rawContainers.length; i++) {
      final entry = rawContainers[i];
      if (entry is! Map) {
        throw InvalidImportDataException('containers[$i] is not an object.');
      }
      final id = entry['id'];
      if (id is! String || !_idPattern.hasMatch(id)) {
        throw InvalidImportDataException(
          'containers[$i].id must look like "Prefix-Number".',
        );
      }
      if (!seenIds.add(id)) {
        throw InvalidImportDataException('Duplicate id "$id" in import file.');
      }
      final rawDate = entry['date'];
      if (rawDate != null && rawDate is! String) {
        throw InvalidImportDataException('containers[$i].date must be a string or null.');
      }
      if (rawDate is String) {
        try {
          DateTime.parse(rawDate);
        } on FormatException {
          throw InvalidImportDataException('containers[$i].date is not a valid date.');
        }
      }
      final rawStatus = entry['status'];
      if (rawStatus is! String) {
        throw InvalidImportDataException('containers[$i].status is missing.');
      }
      try {
        ContainerStatus.fromValue(rawStatus);
      } on ArgumentError {
        throw InvalidImportDataException(
          'containers[$i].status "$rawStatus" is not one of vacant/frozen/construction.',
        );
      }
      final rawIngredients = entry['ingredients'];
      if (rawIngredients != null && rawIngredients is! List) {
        throw InvalidImportDataException('containers[$i].ingredients must be a list.');
      }
      final ingredients = <Map<String, dynamic>>[];
      if (rawIngredients is List) {
        for (final rawIngredient in rawIngredients) {
          if (rawIngredient is! Map) {
            throw InvalidImportDataException(
              'containers[$i].ingredients entries must be objects.',
            );
          }
          final name = rawIngredient['name'];
          if (name is String && name.trim().isNotEmpty) {
            ingredients.add({
              'name': name,
              'quantity': rawIngredient['quantity'] as String? ?? '',
            });
          }
          // Empty-name ingredient rows are dropped silently, same as any
          // other write - see CLAUDE.md/the backend spec.
        }
      }
      validated.add({
        'id': id,
        'date': rawDate,
        'status': rawStatus,
        'ingredients': ingredients,
      });
    }
    await _client.rpc('import_containers', params: {'payload': validated});
  }

  static List<Ingredient> _sanitizeIngredients(List<Ingredient> ingredients) =>
      ingredients.where((i) => i.hasName).toList();
}
