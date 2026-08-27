import 'package:shared_preferences/shared_preferences.dart';

/// Single-boolean SharedPreferences wrapper for the Profile → Settings →
/// Notifications toggle.
///
/// What it does today (v1):
///   - Holds a single bool (`enabled`) under `settings.notifications_enabled`.
///   - Persists across app restarts via SharedPreferences.
///   - Default value is `true` (alerts are on for new users) so we don't
///     silently mute the alert bell without the user touching anything.
///
/// What it does NOT do (yet):
///   - It is purely a status flag. No scanner / alert code reads it yet.
///     When alert delivery is wired to the user's preference later, this
///     service is the single source of truth — switch the readers and
///     the toggle starts gating for free.
///
/// Why a singleton rather than InheritedWidget:
///   - The toggle has no descendant widgets that need to update in lockstep
///     (we don't have any "respect notifications-off" code paths yet).
///   - The Profile sheet needs synchronous access during a sheet rebuild,
///     and the boot path needs `await load()` before first frame so the
///     SwitchListTile doesn't flicker between persisted and default.
///   - If/when we need descendant widgets to react, lift this into a
///     ChangeNotifier and re-export through an InheritedWidget — same
///     shape as `FreeQuotaService`.
class NotificationsPrefsService {
  NotificationsPrefsService._();

  /// Lazy singleton. Constructed on first access; callers should call
  /// [load] once at app boot before the first frame so [enabled] reads
  /// the persisted value synchronously.
  static final NotificationsPrefsService instance =
      NotificationsPrefsService._();

  /// SharedPreferences key. Namespaced under `settings.*` so a future
  /// expansion (e.g. `settings.theme_mode`, `settings.silent_hours`)
  /// doesn't have to renumber existing keys.
  static const String _kEnabled = 'settings.notifications_enabled';

  /// In-memory copy of the persisted flag. `true` until [load] reads the
  /// real value (or confirms the default).
  bool _enabled = true;

  /// Whether the user wants safety alerts to fire. Synchronous getter;
  /// the boot path's [load] call guarantees the value is hot by the time
  /// any widget reads it.
  bool get enabled => _enabled;

  /// Read the persisted value from SharedPreferences. Called once at
  /// app boot. Missing key → `true` (the default).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? true;
    } catch (_) {
      // Corrupt prefs / platform error → fall back to the default so the
      // toggle still renders and the user can change it from there.
      _enabled = true;
    }
  }

  /// Persist the new state. Updates the in-memory flag synchronously so
  /// the calling widget (a sheet's `StatefulBuilder`) sees the new
  /// value on the next frame without a round-trip through prefs.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, value);
    } catch (_) {
      // The in-memory flag is already updated; the next setEnabled()
      // call will retry the write. We intentionally don't throw — the
      // sheet must not crash on a transient prefs failure.
    }
  }
}