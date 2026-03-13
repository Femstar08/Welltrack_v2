import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell scaffold that renders the persistent bottom navigation bar across all
/// primary tab destinations.  Each branch keeps its own navigation stack so
/// users can push sub-routes (e.g. workout plan detail) without losing the nav
/// bar and return to the same position within a branch when switching tabs.
class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The navigationShell renders the currently active branch's subtree.
      // Each branch's own Scaffold (with its AppBar) sits inside this body,
      // so nested Scaffolds are intentional and fully supported by Flutter.
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          // goBranch with initialLocation: true when re-tapping the current tab
          // pops back to the branch root (standard tab-bar UX).
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note_outlined),
            activeIcon: Icon(Icons.edit_note),
            label: 'Log',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
