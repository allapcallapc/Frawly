import 'package:flutter/foundation.dart';

import '../models/container_status.dart';
import '../models/freezer_container.dart';
import '../models/ingredient.dart';
import '../services/container_service.dart';
import '../utils/container_summary.dart';

/// App-wide container state. Holds one cached copy of the full registry
/// (fetched via [ContainerService.getRegistry], which already returns
/// every container's date/status/ingredients) and derives every screen's
/// view from it client-side - the home list's status/search filtering,
/// the New filling/Empty containers selectors, the Summary table, and the
/// Manage containers list all read from the same [containers] list rather
/// than each issuing their own request, keeping server round-trips to one
/// fetch per write instead of one per screen/filter change.
class ContainersProvider with ChangeNotifier {
  ContainersProvider({ContainerService? service})
      : _service = service ?? ContainerService();

  final ContainerService _service;

  List<FreezerContainer> _containers = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  Object? _error;

  List<FreezerContainer> get containers => List.unmodifiable(_containers);
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  Object? get error => _error;
  bool get hasAnyContainers => _containers.isNotEmpty;

  List<String> get prefixesInUse =>
      _containers.map((c) => c.prefix).toSet().toList()..sort();

  ContainerSummary get summary => ContainerSummary.from(_containers);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _containers = await _service.getRegistry();
      _hasLoadedOnce = true;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  FreezerContainer? byId(String id) {
    for (final container in _containers) {
      if (container.id == id) return container;
    }
    return null;
  }

  /// The home list's view: [status]/[search]-filtered, sorted by date
  /// ascending with vacant/null dates first (falling back to id for ties).
  List<FreezerContainer> filtered({ContainerStatus? status, String search = ''}) {
    final needle = search.trim().toLowerCase();
    final list = _containers.where((c) {
      if (status != null && c.status != status) return false;
      if (needle.isNotEmpty && !c.id.toLowerCase().contains(needle)) {
        return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      if (a.date == null && b.date == null) return a.id.compareTo(b.id);
      if (a.date == null) return -1;
      if (b.date == null) return 1;
      final byDate = a.date!.compareTo(b.date!);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return list;
  }

  Future<void> addId(String id) async {
    await _service.addId(id);
    await load();
  }

  /// Returns the ids that were actually added (existing ones in the range
  /// are skipped, not an error).
  Future<List<String>> addRange({
    required String prefix,
    required int from,
    required int to,
  }) async {
    final added = await _service.addRange(prefix: prefix, from: from, to: to);
    await load();
    return added;
  }

  Future<void> removeId(String id) async {
    await _service.removeId(id);
    await load();
  }

  Future<void> createFilling({
    required DateTime? date,
    required ContainerStatus status,
    required List<Ingredient> ingredients,
    required List<String> targetIds,
  }) async {
    await _service.createFilling(
      date: date,
      status: status,
      ingredients: ingredients,
      targetIds: targetIds,
    );
    await load();
  }

  Future<void> emptyContainers(List<String> ids) async {
    await _service.emptyContainers(ids);
    await load();
  }

  Future<FreezerContainer> updateContainer(
    String id, {
    required DateTime? date,
    required ContainerStatus status,
    required List<Ingredient> ingredients,
  }) async {
    final updated = await _service.updateContainer(
      id,
      date: date,
      status: status,
      ingredients: ingredients,
    );
    await load();
    return updated;
  }

  Future<Map<String, dynamic>> exportAll() => _service.exportAll();

  Future<void> importAll(Map<String, dynamic> document) async {
    await _service.importAll(document);
    await load();
  }
}
