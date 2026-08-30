import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../services/share_intent_service.dart';
import '../check/check_screen.dart';
import '../home/home_page.dart';
import '../learn/learn_screen.dart';
import '../message_checker/message_checker_screen.dart';
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
///
/// **Share-intent routing**: Acts as the consumer of
/// [ShareIntentService]. When the user shares text from another Android
/// app into NirapodClick (cold start via ACTION_SEND, or warm start
/// while the app is already running), the service queues the text and
/// notifies listeners. We listen for those notifications and push the
/// existing [MessageCheckerScreen] with the shared text pre-filled via
/// its `initialValue` constructor parameter — the analyzer pipeline
/// itself is untouched.
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
  void initState() {
    super.initState();
    // Listen for share-intent events. The service calls
    // `notifyListeners()` whenever a new share lands (cold-start share
    // already in the queue at app boot, or a warm-start share arriving
    // while the user is on another tab). Each notification kicks a
    // post-frame callback that drains the queue exactly once and
    // pushes the existing MessageCheckerScreen with the shared text
    // pre-filled.
    ShareIntentService.instance.addListener(_handlePendingShare);

    // Cold-start share that arrived BEFORE this widget mounted:
    // `ShareIntentService.start()` awaited in `main.dart` so the
    // share is already in the queue, but `notifyListeners` was called
    // before our listener was attached. Drain it manually so the
    // share doesn't sit unhandled until the next warm-start share.
    if (ShareIntentService.instance.peekPendingText() != null) {
      _handlePendingShare();
    }
  }

  @override
  void dispose() {
    ShareIntentService.instance.removeListener(_handlePendingShare);
    super.dispose();
  }

  /// Called from [ShareIntentService.notifyListeners] whenever a
  /// share is queued. We must NOT call `Navigator.push` directly from
  /// the listener — that fires during a build / layout phase and
  /// trips the Flutter "Navigator is currently locked" assertion. The
  /// safe pattern is to defer the push to the next frame via
  /// [WidgetsBinding.addPostFrameCallback].
  ///
  /// Even if the post-frame callback is scheduled multiple times in
  /// quick succession (e.g. two shares arrive back-to-back), each
  /// callback only consumes whatever the queue currently holds, and
  /// the queue's "most-recent-wins" semantics ensures we don't push
  /// the same text twice.
  void _handlePendingShare() {
    final messenger = WidgetsBinding.instance;
    messenger.addPostFrameCallback((_) {
      if (!mounted) return;
      final text = ShareIntentService.instance.takePendingText();
      if (text == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MessageCheckerScreen(initialValue: text),
        ),
      );
    });
  }

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
