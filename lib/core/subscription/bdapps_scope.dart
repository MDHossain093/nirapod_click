import 'package:flutter/widgets.dart';

import '../../services/bdapps_subscription_service.dart';

/// Inherited holder for the per-session [BdappsSubscriptionService].
///
/// **Why per-session, not process-wide:**
/// the orchestrator holds the in-flight `referenceNo` + mobile between
/// Send and Verify, and the masked subscriberId after Verify. Those
/// are per-session values that should reset on sign-out → sign-in. A
/// `BdappsSubscriptionScope` wraps each `MaterialApp` instance, so a
/// rebuilt `NirapodClickApp` (e.g. after sign-out) gets a fresh service
/// with a clean state.
///
/// **Relationship to `SubscriptionScope`:**
/// after the v1 consolidation BDApps is the only subscription system.
/// `SubscriptionScope` (in `subscription_scope.dart`) is a thin
/// facade that resolves to this same `BdappsSubscriptionService`
/// instance — screens use `SubscriptionScope.isPremiumOf(context)` /
/// `.startFlow(context)` without seeing the BDApps prefix.
///
/// Usage:
///   - At app root: wrap with `BdappsSubscriptionScope(child: ...)`
///     above `MaterialApp` so descendants can resolve the service via
///     `BdappsSubscriptionScope.of(context)`.
///   - In tests: pass `service: stub` to inject a fake.
class BdappsSubscriptionScope extends InheritedWidget {
  const BdappsSubscriptionScope({
    super.key,
    this.service,
    required super.child,
  });

  /// When `null`, the scope lazily constructs a default service on
  /// first [of] call. Tests pass a fake here.
  final BdappsSubscriptionService? service;

  static BdappsSubscriptionService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BdappsSubscriptionScope>();
    if (scope == null) {
      // Defensive fallback: future refactors that move a screen
      // outside the root tree shouldn't crash with an assertion.
      // We surface a clear warning and return a lazy default so the
      // gate still works (with no persisted state).
      // ignore: avoid_print
      print('[BdappsSubscriptionScope] WARN: scope missing from widget '
          'tree — falling back to lazy default.');
      return _default;
    }
    return scope._live;
  }

  BdappsSubscriptionService get _live => service ?? _default;
  static final BdappsSubscriptionService _default =
      BdappsSubscriptionService();

  @override
  bool updateShouldNotify(BdappsSubscriptionScope oldWidget) =>
      !identical(service, oldWidget.service);
}
