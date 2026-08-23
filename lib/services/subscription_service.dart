import 'package:flutter/widgets.dart';

import '../models/subscription.dart';

/// Frontend-only subscription state holder.
///
/// What this does today (v1):
///   - Holds a [SubscriptionState] in memory.
///   - [subscribe] simulates the bdapps payment round-trip with a
///     short delay so the UI can exercise the
///     free → subscribing → active transition.
///   - [cancel] flips the user back to free for the current day
///     and marks the subscription expired.
///
/// What this will do later (after bdapps docs land):
///   - Open the bdapps subscription page via platform channel /
///     deep link and listen for the result callback.
///   - Verify the subscription with our backend before flipping
///     [SubscriptionStatus.subscribing] → [SubscriptionStatus.active].
///   - Persist the verified subscription server-side so it survives
///     reinstalls.
///
/// No payment credentials live in this file. No HTTP. No shared
/// preferences yet — we want the wiring to be obvious before we
/// start persisting.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService() : _state = SubscriptionState.fresh();

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
