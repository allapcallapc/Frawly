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

/// The app's bottom-nav shell: Home, New filling, Empty containers, Manage
/// containers, Summary. Container detail is reached by pushing on top of
/// Home, not a tab of its own.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeFilterRequests = ValueNotifier<HomeFilterRequest?>(null);
  late final List<Widget> _screens = [
    HomeScreen(
      filterRequests: _homeFilterRequests,
      onOpenSummary: () => setState(() => _index = 4),
      onOpenManage: () => setState(() => _index = 3),
      onNewFilling: () => setState(() => _index = 1),
      onEmptyContainers: () => setState(() => _index = 2),
    ),
    const NewFillingScreen(),
    const EmptyContainersScreen(),
    const ManageContainersScreen(),
    SummaryScreen(
      onJumpToHome: _jumpToHome,
      onBack: () => setState(() => _index = 0),
    ),
  ];

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

  void _jumpToHome(HomeFilterRequest request) {
    _homeFilterRequests.value = request;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Fill',
          ),
          NavigationDestination(
            icon: Icon(Icons.remove_circle_outline),
            selectedIcon: Icon(Icons.remove_circle),
            label: 'Empty',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Manage',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            selectedIcon: Icon(Icons.summarize),
            label: 'Summary',
          ),
        ],
      ),
    );
  }
}
