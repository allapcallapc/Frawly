import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../providers/containers_provider.dart';
import '../services/backend_connection.dart';
import '../services/update_service.dart';
import '../utils/date_utils.dart';
import '../widgets/update_dialog.dart';

/// Registry management: add a single id, add a bulk range, remove an id,
/// and export/import the full dataset as a JSON file.
class ManageContainersScreen extends StatefulWidget {
  const ManageContainersScreen({super.key});

  @override
  State<ManageContainersScreen> createState() =>
      _ManageContainersScreenState();
}

class _ManageContainersScreenState extends State<ManageContainersScreen> {
  final _addIdController = TextEditingController();
  final _rangePrefixController = TextEditingController();
  final _rangeFromController = TextEditingController();
  final _rangeToController = TextEditingController();
  bool _busy = false;

  final _updateService = UpdateService();
  String _appVersion = '';
  bool _checkingForUpdate = false;
  String? _updateStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = packageInfo.version);
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checkingForUpdate = true;
      _updateStatusMessage = 'Checking for updates…';
    });

    final update = await _updateService.checkForUpdate();

    if (!mounted) return;
    setState(() {
      _checkingForUpdate = false;
      _updateStatusMessage = update == null ? "You're up to date." : null;
    });

    if (update != null) {
      await showUpdateAvailableDialog(context, _updateService, update);
    }
  }

  @override
  void dispose() {
    _addIdController.dispose();
    _rangePrefixController.dispose();
    _rangeFromController.dispose();
    _rangeToController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addSingle() async {
    final id = _addIdController.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<ContainersProvider>().addId(id);
      _addIdController.clear();
      _showSnack('Added $id.');
    } catch (e) {
      _showSnack('Could not add: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addRange() async {
    final prefix = _rangePrefixController.text.trim();
    final from = int.tryParse(_rangeFromController.text.trim());
    final to = int.tryParse(_rangeToController.text.trim());
    if (prefix.isEmpty || from == null || to == null) {
      _showSnack('Enter a prefix and numeric from/to.');
      return;
    }
    setState(() => _busy = true);
    try {
      final added = await context
          .read<ContainersProvider>()
          .addRange(prefix: prefix, from: from, to: to);
      _rangePrefixController.clear();
      _rangeFromController.clear();
      _rangeToController.clear();
      final skipped = (to - from + 1) - added.length;
      _showSnack(
        'Added ${added.length} id(s)'
        '${skipped > 0 ? ', $skipped already existed' : ''}.',
      );
    } catch (e) {
      _showSnack('Could not add range: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove container?'),
        content: Text('$id and all of its data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ContainersProvider>().removeId(id);
      _showSnack('Removed $id.');
    } catch (e) {
      _showSnack('Could not remove: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final document = await context.read<ContainersProvider>().exportAll();
      final bytes = Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
      );
      await FilePicker.saveFile(
        dialogTitle: 'Export Freezer Log data',
        fileName: 'freezer-log-export-${formatDateKey(DateTime.now())}.json',
        bytes: bytes,
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      _showSnack('Exported.');
    } catch (e) {
      _showSnack('Could not export: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Import Freezer Log data',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return;
    final Uint8List fileBytes;
    try {
      fileBytes = await files.single.readAsBytes();
    } catch (e) {
      _showSnack('Could not read the selected file: $e');
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import data?'),
        content: const Text(
          'This replaces ALL current containers and data with the '
          'contents of this file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Replace all data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final document = jsonDecode(utf8.decode(fileBytes)) as Map<String, dynamic>;
      await context.read<ContainersProvider>().importAll(document);
      _showSnack('Import complete.');
    } catch (e) {
      _showSnack('Could not import: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect backend?'),
        content: const Text(
          "You'll need to enter the URL and passphrase again to reconnect.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<BackendConnection>().disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage containers')),
      body: Consumer<ContainersProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Add a container', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addIdController,
                      decoration: const InputDecoration(
                        labelText: 'Container id (e.g. P-3)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addSingle(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _addSingle,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Add a range', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rangePrefixController,
                      decoration: const InputDecoration(
                        labelText: 'Prefix',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _rangeFromController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'From',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _rangeToController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy ? null : _addRange,
                  child: const Text('Add range'),
                ),
              ),
              const Divider(height: 32),
              Text(
                'Registered containers (${provider.containers.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (provider.error != null && !provider.hasLoadedOnce)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Could not load containers.\n${provider.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                )
              else if (!provider.hasAnyContainers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No containers yet.'),
                )
              else
                ...provider.containers.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.id),
                    subtitle: Text('${formatDisplayDate(c.date)} · ${c.status.label}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove',
                      onPressed: _busy ? null : () => _remove(c.id),
                    ),
                  ),
                ),
              const Divider(height: 32),
              Text('Backup', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Export'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Import'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text('Backend', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Consumer<BackendConnection>(
                builder: (context, connection, _) => Row(
                  children: [
                    Expanded(
                      child: Text(
                        connection.url ?? 'Not connected',
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : _disconnect,
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
              if (_appVersion.isNotEmpty || UpdateService.isSupported) ...[
                const Divider(height: 32),
                Text('About', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_appVersion.isNotEmpty)
                  Center(
                    child: Text(
                      'Version $_appVersion',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (UpdateService.isSupported) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: _checkingForUpdate
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _checkForUpdates,
                            child: const Text('Check for updates'),
                          ),
                  ),
                  if (_updateStatusMessage != null)
                    Center(
                      child: Text(
                        _updateStatusMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
