import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
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
    // Read translations inside build so a locale toggle rebuilds the
    // bar (AppLocaleScope is an InheritedWidget — the inherited lookup
    // here registers a dependency and triggers rebuild on change).
    final t = AppLocaleScope.of(context).tr;
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
          alpha: AppTheme.tintSubtle,
        ),
        // Note: `destinations` is no longer `const` because the labels
        // come from the locale lookup, which is a runtime value.
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: t('nav.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.shield_outlined),
            selectedIcon: const Icon(Icons.shield_rounded),
            label: t('nav.check'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: t('nav.learn'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: t('nav.profile'),
          ),
        ],
      ),
    );
  }
}
