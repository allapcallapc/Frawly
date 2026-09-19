import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../models/ingredient.dart';
import '../utils/date_utils.dart';
import 'backend_connection.dart';
import 'container_service_exceptions.dart';

/// Everything that talks to the Frawly backend (a Cloudflare Worker - see
/// backend/README.md). The app never talks to a database directly; every
/// operation here is a single HTTP request, and every bulk write
/// (createFilling/emptyContainers/importAll) is atomic on the backend side
/// (a single SQL statement, or a D1 batch() transaction for import) - see
/// backend/src/index.ts for the implementation this mirrors.
class ContainerService {
  // The field is private but the named constructor param intentionally
  // isn't, so callers write `ContainerService(connection: ...)` rather
  // than the unspellable `ContainerService(_connection: ...)` an
  // initializing formal would require.
  ContainerService({required BackendConnection connection, http.Client? httpClient})
      // ignore: prefer_initializing_formals
      : _connection = connection,
        _httpClient = httpClient ?? http.Client();

  final BackendConnection _connection;
  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${_connection.url}$path').replace(queryParameters: query);

  Map<String, String> get _headers => _connection.authHeaders;

  String _errorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) return body['error'] as String;
    } catch (_) {
      // Not JSON - fall through to the generic message.
    }
    return fallback;
  }

  /// Lists containers, optionally filtered by [status] and/or a text
  /// [search] on id, sorted by date ascending (vacant/null dates first).
  Future<List<FreezerContainer>> list({
    ContainerStatus? status,
    String? search,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.value;
    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) query['search'] = trimmedSearch;

    final response =
        await _httpClient.get(_uri('/containers', query), headers: _headers);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not load containers.'));
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => FreezerContainer.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// A single container, or null if [id] isn't registered.
  Future<FreezerContainer?> getById(String id) async {
    final response =
        await _httpClient.get(_uri('/containers/$id'), headers: _headers);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not load $id.'));
    }
    return FreezerContainer.fromRow(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// The full registry - every registered container, with its current
  /// date/status/ingredients, sorted by prefix then the numeric part of
  /// the id. This is what the New filling/Empty containers checkbox
  /// selectors and the Manage containers screen list against.
  Future<List<FreezerContainer>> getRegistry() async {
    final response =
        await _httpClient.get(_uri('/containers/registry'), headers: _headers);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not load the registry.'));
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => FreezerContainer.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Adds a single id to the registry. Throws
  /// [ContainerIdAlreadyExistsException] if it's already registered.
  Future<void> addId(String id) async {
    final response = await _httpClient.post(
      _uri('/containers'),
      headers: _headers,
      body: jsonEncode({'id': id}),
    );
    if (response.statusCode == 409) {
      throw ContainerIdAlreadyExistsException(id);
    }
    if (response.statusCode != 201) {
      throw StateError(_errorMessage(response, 'Could not add $id.'));
    }
  }

  /// Adds every "`<prefix>-<n>`" for n in [from]..[to] (inclusive) that
  /// isn't already registered - existing ids are skipped, not rejected.
  /// Returns the ids that were actually added. Throws
  /// [InvalidRangeException] if the range is invalid or too large.
  Future<List<String>> addRange({
    required String prefix,
    required int from,
    required int to,
  }) async {
    final response = await _httpClient.post(
      _uri('/containers/range'),
      headers: _headers,
      body: jsonEncode({'prefix': prefix, 'from': from, 'to': to}),
    );
    if (response.statusCode == 400) {
      throw InvalidRangeException(_errorMessage(response, 'Invalid range.'));
    }
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not add the range.'));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['added'] as List<dynamic>).cast<String>();
  }

  /// Removes [id] from the registry, deleting its stored data with it.
  Future<void> removeId(String id) async {
    final response =
        await _httpClient.delete(_uri('/containers/$id'), headers: _headers);
    if (response.statusCode != 204) {
      throw StateError(_errorMessage(response, 'Could not remove $id.'));
    }
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
    final response = await _httpClient.post(
      _uri('/fillings'),
      headers: _headers,
      body: jsonEncode({
        'date': date == null ? null : formatDateKey(date),
        'status': status.value,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'targetIds': targetIds,
      }),
    );
    if (response.statusCode == 404) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final missing = (body['missing'] as List<dynamic>).cast<String>();
      throw ContainersNotFoundException(missing.toSet());
    }
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not save the filling.'));
    }
  }

  /// Resets every one of [ids] to vacant/null date/no ingredients, in one
  /// atomic write.
  Future<void> emptyContainers(List<String> ids) async {
    if (ids.isEmpty) return;
    final response = await _httpClient.post(
      _uri('/containers/empty'),
      headers: _headers,
      body: jsonEncode({'ids': ids}),
    );
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not empty containers.'));
    }
  }

  /// Updates a single container's date/status/ingredients (not part of a
  /// bulk filling).
  Future<FreezerContainer> updateContainer(
    String id, {
    required DateTime? date,
    required ContainerStatus status,
    required List<Ingredient> ingredients,
  }) async {
    final response = await _httpClient.patch(
      _uri('/containers/$id'),
      headers: _headers,
      body: jsonEncode({
        'date': date == null ? null : formatDateKey(date),
        'status': status.value,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not save $id.'));
    }
    return FreezerContainer.fromRow(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// The full registry + all container data as one JSON-serializable
  /// document, for [importAll]/file export.
  Future<Map<String, dynamic>> exportAll() async {
    final response = await _httpClient.get(_uri('/export'), headers: _headers);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not export data.'));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Replaces all current data with [document] (the shape [exportAll()]
  /// produces), atomically - either every row is replaced or none are.
  /// Validates the document's shape first; throws
  /// [InvalidImportDataException] (without writing anything) if it's
  /// invalid.
  Future<void> importAll(Map<String, dynamic> document) async {
    final response = await _httpClient.post(
      _uri('/import'),
      headers: _headers,
      body: jsonEncode(document),
    );
    if (response.statusCode == 400) {
      throw InvalidImportDataException(
        _errorMessage(response, 'Invalid import file.'),
      );
    }
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(response, 'Could not import data.'));
    }
  }
}
