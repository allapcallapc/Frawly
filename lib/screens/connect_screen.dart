import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/backend_config.dart';
import '../services/backend_connection.dart';

/// Shown whenever the app has no saved backend connection - first launch,
/// or after disconnecting (see the "Backend" section of Manage
/// containers). Verifies the URL + passphrase actually reach a Frawly
/// backend before saving them.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final _urlController = TextEditingController(
    text: BackendConfig.defaultUrl,
  );
  final _passphraseController = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final passphrase = _passphraseController.text;
    if (url.isEmpty || passphrase.isEmpty) {
      setState(() => _error = 'Enter both the backend URL and passphrase.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    final connection = context.read<BackendConnection>();
    final ok = await connection.testConnection(url: url, passphrase: passphrase);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _connecting = false;
        _error = 'Could not reach a Frawly backend at that URL with that '
            'passphrase.';
      });
      return;
    }

    await connection.connect(url: url, passphrase: passphrase);
    if (mounted) setState(() => _connecting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.kitchen,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect to your Freezer Log backend',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // AutofillGroup + autofillHints is what makes Flutter web
                  // expose these as recognizable url/password fields to the
                  // browser's own autofill and to password-manager
                  // extensions (Bitwarden, 1Password, etc.) that hook into
                  // it - without both, Flutter's canvas-rendered fields are
                  // otherwise invisible to them.
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          autofillHints: const [AutofillHints.url],
                          decoration: const InputDecoration(
                            labelText: 'Backend URL',
                            hintText: 'https://frawly-api.example.workers.dev',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passphraseController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Passphrase',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _connect(),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _connecting ? null : _connect,
                    child: _connecting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
