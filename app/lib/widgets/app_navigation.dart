import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.branchIndex,
  });
}

class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _selectedVisualIndex = 0;

  static const List<_TabSpec> _tabs = [
    _TabSpec(
      label: 'Mapa',
      icon: Icons.map_outlined,
      selectedIcon: Icons.map_rounded,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'Grupos',
      icon: Icons.group_outlined,
      selectedIcon: Icons.group_rounded,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'Alertas',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'Perfil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      branchIndex: 3,
    ),
  ];

  void _onTabTap(int visualIndex) {
    final tab = _tabs[visualIndex];
    if (tab.branchIndex == null) return;
    setState(() => _selectedVisualIndex = visualIndex);
    widget.navigationShell.goBranch(
      tab.branchIndex!,
      initialLocation: tab.branchIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  void didUpdateWidget(AppNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentBranch = widget.navigationShell.currentIndex;
    final matchingTab = _tabs.indexWhere((t) => t.branchIndex == currentBranch);
    if (matchingTab != -1 && matchingTab != _selectedVisualIndex) {
      setState(() => _selectedVisualIndex = matchingTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NavigationBar(
      selectedIndex: _selectedVisualIndex,
      onDestinationSelected: _onTabTap,
      backgroundColor: theme.colorScheme.surface,
      indicatorColor: AppTheme.primaryContainer,
      elevation: 2,
      shadowColor: Colors.black12,
      destinations: List.generate(_tabs.length, (i) {
        final tab = _tabs[i];
        final isStub = tab.branchIndex == null;
        return NavigationDestination(
          icon: Opacity(opacity: isStub ? 0.4 : 1.0, child: Icon(tab.icon)),
          selectedIcon: Icon(tab.selectedIcon),
          label: tab.label,
        );
      }),
    );
  }
}
