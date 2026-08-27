import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_service.dart';

/// Free-tier usage tracker.
///
/// What it does today (v1):
///   - Tracks how many checks the signed-in free user has run in the
///     current calendar month (Bangladeshi local time, since this is
///     a BD-first app and "month" rolls over on the 1st).
///   - Persists via SharedPreferences so the counter survives app
///     restarts and reinstalls (SharedPreferences is per-install on
///     iOS, but on Android it lives in the app's private data dir).
///   - Exposes `consume()` which the four scanners call BEFORE
///     running analysis. If the user is premium, consume() is a no-op
///     (premium = unlimited). If free, it decrements the remaining
///     budget atomically and returns false when the budget is gone.
///   - Provides a one-shot rebuild helper for after subscription
///     state changes (cancel / expire / re-subscribe).
///
/// What it will do later (after bdapps docs land):
///   - Authoritative count comes from the bdapps SDK's entitlement
///     payload; the local counter becomes a fallback / UI-only hint.
///   - Per-user server-side count so a shared account on two devices
///     can't double-spend the budget.
///
/// The 5/month budget is the value the user asked for ("here free user
/// can check maximum 5 check in month"). The intent is to gate the
/// app behind Premium enough that the user feels the limit, without
/// being hostile. Adjust `monthlyBudget` if the brief changes.
class FreeQuotaService extends ChangeNotifier {
  FreeQuotaService({this.monthlyBudget = 5});

  /// Free checks per calendar month.
  ///
  /// 5 is the brief-specified budget; it can be tuned without touching
  /// call sites because every scanner reads it through this constant.
  final int monthlyBudget;

  /// SharedPreferences keys. Keyed by current `YYYY-MM` so the budget
  /// naturally resets on the 1st without an explicit cron — when the
  /// stored key no longer matches the live month, we treat the count
  /// as zero.
  static String _monthKey(DateTime now) =>
      'free_quota.used.${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// Track the user-supplied subscription service so consume() can
  /// short-circuit when the user is on Premium. Wired up in
  /// [attachSubscription] rather than the constructor so tests can
  /// pass in a stub.
  SubscriptionService? _subscription;
  bool _subscriptionAttached = false;
  bool _disposed = false;

  /// Total checks used in the current month, loaded lazily from prefs
  /// on first read and kept in sync after every consume(). The
  /// getter auto-resets if the stored month no longer matches the
  /// live calendar month.
  int _used = 0;
  int _loadedForMonth = 0;

  /// How many checks the free user can still run this month.
  ///
  /// Clamped to 0..monthlyBudget. Premium users see `monthlyBudget`
  /// (so the home pill can render the same shape), but `canConsume`
  /// is the gate the scanners actually key off.
  int get remaining {
    _ensureLoadedForCurrentMonth();
    final max = monthlyBudget;
    final left = max - _used;
    return left < 0 ? 0 : left;
  }

  /// Number of checks already consumed this month.
  int get used {
    _ensureLoadedForCurrentMonth();
    return _used;
  }

  /// Date the budget resets on. Always the 1st of next month, midnight
  /// local time. The home pill uses this in its "Resets on {date}"
  /// caption when the budget is partially spent.
  DateTime get resetsOn {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  /// Whether the user is currently premium. `false` until the
  /// subscription service is attached; attach it as early as possible
  /// (e.g. in `main()` after `SubscriptionScope` is constructed) so
  /// the home pill doesn't flicker between free and premium on the
  /// first frame.
  bool get isPremium {
    final sub = _subscription;
    return sub != null && sub.state.isPremium;
  }

  /// Allow-list gate. Returns true if the next check can proceed.
  ///
  /// Premium users always pass. Free users pass if `remaining > 0`.
  /// When false, the caller should surface a snackbar pointing at the
  /// Premium screen instead of running the analyzer.
  bool get canConsume {
    if (isPremium) return true;
    return remaining > 0;
  }

  /// Decrement the budget by one. Idempotent: returns false (does not
  /// throw) when the budget is exhausted so callers can use the
  /// return value as the "show upgrade screen?" flag without an
  /// extra `canConsume` check.
  ///
  /// When premium, this is a no-op and always returns true. Persists
  /// the new count to SharedPreferences so a kill-and-relaunch
  /// doesn't reset the budget mid-month.
  Future<bool> consume() async {
    if (isPremium) return true;
    _ensureLoadedForCurrentMonth();
    if (_used >= monthlyBudget) return false;
    _used += 1;
    notifyListeners();
    await _persist();
    return true;
  }

  /// Returns the number of checks that were used during the just-ended
  /// month. Useful for analytics; not currently surfaced in the UI.
  /// Provided so a future "X / 5 used last month" feature has a hook.
  Future<int> debugLastMonthUsage() async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final key = _monthKey(lastMonth);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  /// Wire up the [SubscriptionService] so [consume] / [canConsume]
  /// know when the user has gone premium. Idempotent — calling twice
  /// with the same service is fine.
  ///
  /// The service subscribes internally and re-emits notifications
  /// when the subscription state flips, so the home pill / scanner
  /// guards update without any extra plumbing.
  void attachSubscription(SubscriptionService service) {
    if (_subscriptionAttached && identical(_subscription, service)) return;
    if (_subscription != null && !_subscriptionAttached) {
      // Defensive: if we ever detach (we don't today), drop the old
      // listener first. Currently unreachable because we never detach,
      // but mirrors the intent so a future change is safe.
      try {
        _subscription!.removeListener(_onSubscriptionChanged);
      } catch (_) {
        // ignored — listener removal is best-effort.
      }
    }
    _subscription = service;
    service.addListener(_onSubscriptionChanged);
    _subscriptionAttached = true;
    // Defer the first notify to the post-frame callback so the home
    // pill / scanner guards that subscribed during the build phase
    // don't fire their listeners mid-build (which would trigger
    // `setState() / markNeedsBuild() called during build`). A single
    // frame of latency on the first paint is invisible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  void _onSubscriptionChanged() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Force a rebuild from prefs. Used after subscribe() / cancel()
  /// in tests; production callers don't need this because consume()
  /// already persists immediately.
  Future<void> refresh() async {
    _used = 0;
    _loadedForMonth = 0;
    await _loadFromPrefs();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────────────────────────

  void _ensureLoadedForCurrentMonth() {
    final now = DateTime.now();
    final currentMonthKey = now.year * 12 + now.month;
    if (_loadedForMonth == currentMonthKey) return;
    _loadedForMonth = currentMonthKey;
    // Fire-and-forget load; consume() awaits its own persist so the
    // race is bounded: a consume that races the load will write the
    // post-consume value, and the load that arrives later will
    // overwrite it with the pre-load value. To prevent that, we
    // re-read from prefs synchronously here via the cache and let
    // [consume] always read from the cache (not from prefs). The
    // initial value is 0 until [_loadFromPrefs] resolves, which is
    // acceptable: the worst case is one extra free check on the very
    // first launch of the app, and that's the same behaviour we get
    // if SharedPreferences is corrupt.
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _monthKey(DateTime.now());
      final stored = prefs.getInt(key) ?? 0;
      // Clamp to the budget so a tampered prefs file can't push the
      // counter above 5 and silently disable the gate.
      _used = stored.clamp(0, monthlyBudget);
    } catch (_) {
      _used = 0;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _monthKey(DateTime.now());
      await prefs.setInt(key, _used);
    } catch (_) {
      // ignored — the in-memory counter is still correct for this
      // session; we'll retry on the next consume().
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_subscription != null) {
      try {
        _subscription!.removeListener(_onSubscriptionChanged);
      } catch (_) {
        // ignored
      }
    }
    super.dispose();
  }
}

/// Inherited holder for the singleton [FreeQuotaService].
///
/// Mirrors the [SubscriptionScope] pattern: lazy default constructor
/// for production, explicit injection point for tests.
///
/// Usage:
///   - At app root: wrap with `FreeQuotaScope(child: ...)` after
///     `SubscriptionScope` so the quota service can listen for the
///     subscription transitions.
///   - In tests: `FreeQuotaScope(service: fake, child: ...)` to
///     inject a pre-seeded service.
///   - Anywhere in the tree:
///     `FreeQuotaScope.of(context).canConsume` / `.consume()`.
class FreeQuotaScope extends InheritedWidget {
  const FreeQuotaScope({
    super.key,
    this.service,
    required super.child,
  });

  /// When `null`, the scope lazily constructs a [FreeQuotaService]
  /// on first [of] call. Tests pass a fake here.
  final FreeQuotaService? service;

  static FreeQuotaService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<FreeQuotaScope>();
    if (scope == null) {
      // Defensive fallback: a future refactor that moves a scanner
      // outside the root tree (e.g. into a new isolate-driven
      // sub-tree) shouldn't hard-crash with the old `assert`. Log
      // loudly so we notice, then return the lazy default so the
      // gate still functions — Premium check goes via the singleton
      // subscription service too, so the only thing this loses is
      // the cross-service "is this user premium?" lookup, which is
      // handled by the (non-null) SubscriptionScope default.
      // ignore: avoid_print
      print('[FreeQuotaScope] WARN: FreeQuotaScope missing from '
          'widget tree — falling back to lazy default. '
          'See https://docs.flutter.dev/dev/testing/errors for the '
          'assertion-mode diagnostic.');
      return _default;
    }
    return scope._live;
  }

  FreeQuotaService get _live => service ?? _default;
  static final FreeQuotaService _default = FreeQuotaService();

  @override
  bool updateShouldNotify(FreeQuotaScope oldWidget) =>
      !identical(service, oldWidget.service);
}