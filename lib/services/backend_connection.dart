import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Holds the connected backend's URL + passphrase (see the root
/// CLAUDE.md's "Auth model") - stored locally on this device only, never
/// baked into a build. [ContainerService] reads [url]/[authHeaders] from
/// this to make requests; screens watch [isConnected] to decide between
/// showing the connect screen and the rest of the app.
class BackendConnection with ChangeNotifier {
  BackendConnection({FlutterSecureStorage? storage, http.Client? httpClient})
      : _storage = storage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client();

  static const _urlKey = 'backend_url';
  static const _passphraseKey = 'backend_passphrase';

  final FlutterSecureStorage _storage;
  final http.Client _httpClient;

  String? _url;
  String? _passphrase;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  bool get isConnected => _url != null && _passphrase != null;
  String? get url => _url;

  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer $_passphrase',
        'Content-Type': 'application/json',
      };

  /// Reads any previously-saved connection from secure storage. Call once
  /// at app startup before deciding which screen to show.
  Future<void> loadStored() async {
    _url = await _storage.read(key: _urlKey);
    _passphrase = await _storage.read(key: _passphraseKey);
    _isLoading = false;
    notifyListeners();
  }

  /// Checks that [url]/[passphrase] actually reach a Frawly backend,
  /// without saving anything - used by the connect screen to validate
  /// before committing to a new connection.
  Future<bool> testConnection({
    required String url,
    required String passphrase,
  }) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('${_normalize(url)}/health'),
            headers: {'Authorization': 'Bearer $passphrase'},
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect({
    required String url,
    required String passphrase,
  }) async {
    final normalized = _normalize(url);
    await _storage.write(key: _urlKey, value: normalized);
    await _storage.write(key: _passphraseKey, value: passphrase);
    _url = normalized;
    _passphrase = passphrase;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _passphraseKey);
    _url = null;
    _passphrase = null;
    notifyListeners();
  }

  static String _normalize(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
