import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/containers_provider.dart';
import '../services/update_service.dart';
import '../utils/home_filter_request.dart';
import '../widgets/update_dialog.dart';
import 'empty_containers_screen.dart';
import 'home_screen.dart';
import 'manage_containers_screen.dart';
import 'new_filling_screen.dart';
import 'summary_screen.dart';

/// The app's shell: Home is the one screen that's always on screen: New
/// filling, Empty containers, Manage containers, and Summary are all
/// pushed on top of it (from Home's own header/floating buttons) rather
/// than being tabs of their own, and pop back to it. Container detail is
/// pushed the same way, from Home's list.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _homeFilterRequests = ValueNotifier<HomeFilterRequest?>(null);

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame - calling load() directly here
    // races BackendConnection's own notifyListeners() from loadStored()
    // (which is what gets _Root to build MainShell in the first place):
    // load()'s first notifyListeners() (the isLoading=true one) can fire
    // before this widget's own Consumer<ContainersProvider> descendants
    // exist to subscribe to it, and on a fresh page load that's enough to
    // drop the *second* (successful) notifyListeners() too - the registry
    // fetch succeeds but nothing on screen ever rebuilds to show it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ContainersProvider>().load();
    });
    // Runs once per app launch so a sideloaded install (the app is
    // distributed as a GitHub Release APK, not through the Play Store)
    // still gets notified of new releases - see UpdateService.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForAppUpdate());
  }

  Future<void> _checkForAppUpdate() async {
    if (!UpdateService.isSupported) return;
    final updateService = UpdateService();
    final update = await updateService.checkForUpdate();
    if (update == null || !mounted) return;
    await showUpdateAvailableDialog(context, updateService, update);
  }

  @override
  void dispose() {
    _homeFilterRequests.dispose();
    super.dispose();
  }

  /// Pops any pushed screen(s) back down to Home, then applies the filter -
  /// used by Summary's cell tap.
  void _jumpToHome(HomeFilterRequest request) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _homeFilterRequests.value = request;
  }

  void _openNewFilling() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NewFillingScreen()));
  }

  void _openEmptyContainers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmptyContainersScreen()),
    );
  }

  void _openManage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageContainersScreen()),
    );
  }

  void _openSummary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          onJumpToHome: _jumpToHome,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      filterRequests: _homeFilterRequests,
      onOpenSummary: _openSummary,
      onOpenManage: _openManage,
      onNewFilling: _openNewFilling,
      onEmptyContainers: _openEmptyContainers,
    );
  }
}
