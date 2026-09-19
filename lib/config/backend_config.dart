/// The backend URL baked in at build time via
/// --dart-define-from-file=env/local.json (or staging.json/prod.json) -
/// see env/README.md. This is only ever used to pre-fill the connect
/// screen's URL field; it is never auto-connected, and the passphrase is
/// never baked into a build (see lib/services/backend_connection.dart) -
/// the user always enters it themselves, once, and it's stored locally on
/// their device from then on.
class BackendConfig {
  static const String defaultUrl = String.fromEnvironment('BACKEND_URL');
}
