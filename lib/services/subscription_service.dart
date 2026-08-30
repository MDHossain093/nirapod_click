import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_type.dart';
import '../models/subscription.dart';

/// SharedPreferences key under which the *consumed* (used) message /
/// screenshot counts are persisted for free-tier users. Premium users
/// never write here because their limits are `null` and the service
/// short-circuits the decrement path.
///
/// We store `used`, not `remaining`, so the persisted value is
/// independent of any future change to `PlanLimits.freeDefault()`
/// (e.g. if we bump the free screenshot allowance from 3 to 5
/// tomorrow, existing users get the *new* budget minus their
/// already-tracked usage — not the leftover of the old budget).
const String _kUsedMessagesKey = 'subscription.used.messages';
const String _kUsedScreenshotsKey = 'subscription.used.screenshots';

/// Frontend-only subscription state holder.
///
/// What this does today (v1):
///   - Holds a [SubscriptionState] in memory.
///   - [subscribe] simulates the bdapps payment round-trip with a
///     short delay so the UI can exercise the
///     free → subscribing → active transition.
///   - [cancel] flips the user back to free for the current day
///     and marks the subscription expired.
///   - [recordScan] / [refundScan] mutate the per-kind counters on
///     `state.limits` so the Profile card can show real
///     "X message scans left" / "Y screenshot scans left" instead
///     of the static v1 defaults.
///
/// What this will do later (after bdapps docs land):
///   - Open the bdapps subscription page via platform channel /
///     deep link and listen for the result callback.
///   - Verify the subscription with our backend before flipping
///     [SubscriptionStatus.subscribing] → [SubscriptionStatus.active].
///   - Persist the verified subscription server-side so it survives
///     reinstalls.
///
/// No payment credentials live in this file. No HTTP. Shared
/// preferences are used for the per-kind counter so the "X scans
/// left" value survives app kill-and-relaunch.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService() : _state = SubscriptionState.fresh();

  /// Process-scoped singleton. Mirrors `AlertService.instance` so
  /// non-UI code (e.g. `CheckerRepository.deleteMany`) can reach the
  /// service without a BuildContext — `recordScan` / `refundScan`
  /// are called from scanner code (which does have a context via
  /// `SubscriptionScope.of`) and from data-layer code (which doesn't),
  /// so we keep a single instance the data layer can grab.
  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService();

  SubscriptionState _state;
  SubscriptionState get state => _state;

  /// Tracks an in-flight subscribe/cancel so the UI can disable the
  /// button to prevent double-fires.
  bool _busy = false;
  bool get isBusy => _busy;

  // ----------------------------------------------------------- subscribe

  /// Kick off the (simulated) bdapps purchase flow.
  ///
  /// State machine:
  ///   free / expired → subscribing
  ///   subscribing   → active (on success) OR back to previous + lastError
  ///   active        → no-op (button is hidden in this state)
  Future<void> subscribe() async {
    if (_busy) return;
    if (_state.status == SubscriptionStatus.active) return;

    _setBusy(true);
    _transition(_state.copyWith(
      status: SubscriptionStatus.subscribing,
      clearLastError: true,
    ));

    try {
      // Simulated bdapps round-trip. Real implementation will:
      //   1. Launch bdapps via platform channel with our app id.
      //   2. Await the result callback on the platform channel.
      //   3. Verify with our backend (signed receipt).
      //   4. On success, the service stores the server-side proof
      //      and flips the local state.
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final nextRenewal = DateTime.now().add(const Duration(days: 1));
      _transition(_state.copyWith(
        status: SubscriptionStatus.active,
        limits: PlanLimits.unlimited(),
        nextRenewalAt: nextRenewal,
        clearLastError: true,
      ));
    } catch (e) {
      _transition(_state.copyWith(
        status: SubscriptionStatus.free,
        lastError: e.toString(),
      ));
    } finally {
      _setBusy(false);
    }
  }

  /// Cancel the active subscription.
  ///
  /// For v1 this is a local-only transition — the real cancel call
  /// will go through bdapps once that flow exists.
  Future<void> cancel() async {
    if (_busy) return;
    if (_state.status != SubscriptionStatus.active) return;

    _setBusy(true);
    try {
      // Simulated bdapps cancel round-trip.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      _transition(_state.copyWith(
        status: SubscriptionStatus.expired,
        limits: PlanLimits.freeDefault(),
        clearNextRenewal: true,
        clearLastError: true,
      ));
      // On cancel, replay the persisted counters so the freshly-free
      // user resumes with the same used-count they had before they
      // upgraded. Otherwise a user who upgrades with 2 messages used,
      // then cancels, would suddenly see "4 of 4 left" again.
      await _rehydrateFromPrefs();
    } finally {
      _setBusy(false);
    }
  }

  /// Clear a previous error so the UI can stop showing the
  /// "Try Again" banner. Called after the user taps Try Again.
  void clearError() {
    if (_state.lastError == null) return;
    _transition(_state.copyWith(clearLastError: true));
  }

  /// Test-only hook to swap the service's state to an arbitrary
  /// [SubscriptionState] and fire a [ChangeNotifier] notification so
  /// listeners (e.g. `AnimatedBuilder` in [SubscriptionStatusCard])
  /// rebuild. Bypasses the busy gate and persistence — production
  /// callers should go through [subscribe] / [cancel] / [recordScan].
  /// Not annotated `@visibleForTesting` because the subscription
  /// service already lives at the lib/services layer; the explicit
  /// "ForTest" suffix keeps the intent obvious in the call site.
  void emitForTest(SubscriptionState next) {
    _state = next;
    notifyListeners();
  }

  // ----------------------------------------------------------- counters

  /// Apply a saved scan: decrement the matching per-kind counter on
  /// the free tier (premium is a no-op because limits are `null`).
  ///
  /// URL and phone scans are intentionally ignored: those rely on
  /// local engines with no per-call cost, so the free plan treats
  /// them as unlimited and there is no counter to decrement.
  ///
  /// Returns true if the counter actually moved (or was already 0 /
  /// unlimited and didn't need to move); false if the scan was
  /// refused because the relevant counter was at 0.
  ///
  /// Callers should `await` this BEFORE running the analyzer, the
  /// same way they `await quota.consume()` today — except this
  /// service is per-kind, so a screenshot scan won't deplete the
  /// message budget.
  Future<bool> recordScan(ScanType type) async {
    if (_state.isPremium) return true;
    switch (type) {
      case ScanType.message:
        return _decrement(_kUsedMessagesKey, _state.limits.messageScansRemaining,
            (n) => _state.copyWith(
                limits: _state.limits
                    .copyWithCounters(messageScansRemaining: n)));
      case ScanType.screenshot:
        return _decrement(_kUsedScreenshotsKey,
            _state.limits.screenshotScansRemaining,
            (n) => _state.copyWith(
                limits: _state.limits
                    .copyWithCounters(screenshotScansRemaining: n)));
      case ScanType.url:
      case ScanType.phone:
      case ScanType.qr:
        // Local-engine scans — no quota on free tier. QR is also
        // free because the scan itself is just a routing step; the
        // *destination* check (URL / phone / message) is what
        // decrements its own counter on its own screen.
        return true;
    }
  }

  /// Reverse a scan that was deleted (single, multi, or
  /// `clearAll`). Adds one back to the matching counter, capped at
  /// the default budget so a malformed persisted value can't push
  /// the counter above the published plan.
  ///
  /// Best-effort: a SharedPreferences failure is logged but never
  /// thrown, so a delete from the History page can't fail because
  /// the quota persistence had a hiccup.
  Future<void> refundScan(ScanType type) async {
    if (_state.isPremium) return;
    switch (type) {
      case ScanType.message:
        await _increment(
          _kUsedMessagesKey,
          _state.limits.messageScansRemaining,
          PlanLimits.freeDefault().messageScansRemaining!,
          (n) => _state.copyWith(
              limits: _state.limits.copyWithCounters(messageScansRemaining: n)),
        );
        break;
      case ScanType.screenshot:
        await _increment(
          _kUsedScreenshotsKey,
          _state.limits.screenshotScansRemaining,
          PlanLimits.freeDefault().screenshotScansRemaining!,
          (n) => _state.copyWith(
              limits: _state.limits
                  .copyWithCounters(screenshotScansRemaining: n)),
        );
        break;
      case ScanType.url:
      case ScanType.phone:
      case ScanType.qr:
        // No counter to refund.
        break;
    }
  }

  /// True when the free-tier counter for [type] is at zero (i.e.
  /// the next scan of this kind should be refused). Always `false`
  /// for URL / phone (unlimited) and for premium users.
  bool isExhaustedFor(ScanType type) {
    if (_state.isPremium) return false;
    switch (type) {
      case ScanType.message:
        return (_state.limits.messageScansRemaining ?? 0) == 0;
      case ScanType.screenshot:
        return (_state.limits.screenshotScansRemaining ?? 0) == 0;
      case ScanType.url:
      case ScanType.phone:
      case ScanType.qr:
        return false;
    }
  }

  /// Pull the persisted used-counts out of SharedPreferences and
  /// apply them to the live `state.limits`. Called once on app boot
  /// from `main.dart` so the Profile card renders the correct
  /// "X scans left" on first frame instead of flashing the static
  /// defaults.
  ///
  /// Safe to call before any other state has been touched; if the
  /// user is premium we skip the rehydration so we don't overwrite
  /// their `null` (unlimited) limits with a stale free-tier value.
  Future<void> rehydrate() async {
    if (_state.isPremium) return;
    await _rehydrateFromPrefs();
  }

  Future<void> _rehydrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final usedMessages =
        prefs.getInt(_kUsedMessagesKey) ?? 0;
    final usedScreenshots =
        prefs.getInt(_kUsedScreenshotsKey) ?? 0;
    final defaults = PlanLimits.freeDefault();
    final remainingMessages =
        (defaults.messageScansRemaining! - usedMessages).clamp(0, defaults.messageScansRemaining!);
    final remainingScreenshots = (defaults.screenshotScansRemaining! -
            usedScreenshots)
        .clamp(0, defaults.screenshotScansRemaining!);
    _transition(_state.copyWith(
      limits: _state.limits.copyWithCounters(
        messageScansRemaining: remainingMessages,
        screenshotScansRemaining: remainingScreenshots,
      ),
    ));
  }

  /// Try to take one off [remaining]. Returns false when already
  /// zero (so the caller can refuse the scan). Updates prefs and
  /// notifies listeners on success.
  Future<bool> _decrement(
    String prefsKey,
    int? remaining,
    SubscriptionState Function(int remainingAfter) buildNext,
  ) async {
    if (remaining == null) return true; // unlimited
    if (remaining <= 0) return false; // exhausted
    final nextRemaining = remaining - 1;
    final defaults = PlanLimits.freeDefault();
    final usedBefore = (defaults.messageScansRemaining! - remaining);
    final nextState = buildNext(nextRemaining);
    _transition(nextState);
    // Persist the *used* count (prefs key is for used, not remaining).
    final usedKey = prefsKey;
    final newUsed = usedBefore + 1;
    await _persistInt(usedKey, newUsed);
    return true;
  }

  /// Add one back to [remaining], capped at [cap]. Used when a scan
  /// is deleted (single / multi / clearAll).
  Future<void> _increment(
    String prefsKey,
    int? remaining,
    int cap,
    SubscriptionState Function(int remainingAfter) buildNext,
  ) async {
    if (remaining == null) return; // unlimited tier
    final nextRemaining = (remaining + 1).clamp(0, cap);
    final defaults = PlanLimits.freeDefault();
    // Mirror of `_decrement`'s math: used = budget - remaining.
    final usedKey = prefsKey;
    final usedBefore = (defaults.messageScansRemaining! - remaining);
    final newUsed = (usedBefore - 1).clamp(0, defaults.messageScansRemaining!);
    _transition(buildNext(nextRemaining));
    await _persistInt(usedKey, newUsed);
  }

  Future<void> _persistInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {
      // Best-effort persistence — a failed write shouldn't break the
      // user's scan flow. Worst case the counter resets to the static
      // default on next launch, which is the same behavior we had
      // before this feature landed.
    }
  }

  // ----------------------------------------------------------- helpers

  void _transition(SubscriptionState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }
}

/// Inherited holder for the singleton [SubscriptionService].
///
/// We avoid pulling in the `provider` package so the app stays
/// dependency-light; this mirrors the [AppLocaleScope] pattern.
///
/// Usage:
///   - At app root, wrap with `SubscriptionScope(child: ...)`
///     (the scope auto-creates a default service).
///   - In tests, construct `SubscriptionScope(service: fake, child: ...)`
///     to inject a controlled service.
///   - Anywhere in the tree: `SubscriptionScope.of(context).state`
///     to read, `.subscribe()` to act.
class SubscriptionScope extends InheritedWidget {
  const SubscriptionScope({
    super.key,
    this.service,
    required super.child,
  });

  /// When `null`, the scope lazily constructs a [SubscriptionService]
  /// on first [of] call. Tests pass a fake here.
  final SubscriptionService? service;

  static SubscriptionService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SubscriptionScope>();
    assert(scope != null, 'SubscriptionScope is missing from the widget tree');
    return scope!._live;
  }

  SubscriptionService get _live => service ?? _default;
  static final SubscriptionService _default = SubscriptionService();

  @override
  bool updateShouldNotify(SubscriptionScope oldWidget) =>
      !identical(service, oldWidget.service);
}
