import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../check/check_screen.dart';
import '../home/home_page.dart';
import '../learn/learn_screen.dart';
import '../profile/profile_screen.dart';

/// Top-level shell shown after a successful login.
///
/// Owns the bottom [NavigationBar] and switches between the four
/// major sections of the app:
///
///   0. [HomePage]      - dashboard (greeting + Check Now CTA + recent scans)
///   1. [CheckScreen]   - hub that fans out to Message / URL / Screenshot /
///                        Phone checkers
///   2. [LearnScreen]   - Safety Learning Center (local-only lessons)
///   3. [ProfileScreen] - account info + settings + logout
///
/// Why [IndexedStack] and not a plain `pages[_index]` swap:
///   - Each tab keeps its scroll position when the user switches away and
///     back (a swapped widget would be rebuilt from scratch and lose its
///     state on every tab change).
///   - The trade-off is memory: all four children stay mounted. With four
///     lightweight screens this is fine; if a tab ever becomes heavy we
///     should switch to `AutomaticKeepAliveClientMixin` + visibility.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // const list so each tab is built once. Any future non-const tab needs to
  // be added with a `ValueKey` to keep IndexedStack happy.
  static const List<Widget> _screens = [
    HomePage(),
    CheckScreen(),
    LearnScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withValues(
          alpha: 0.10,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Check',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
