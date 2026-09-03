import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/subscription/bdapps_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_helpers.dart';
import '../../services/bdapps_service.dart';
import '../../services/bdapps_subscription_service.dart';
import 'bdapps_gradient_cta.dart';
import 'bdapps_mobile_screen.dart';

/// Access-control widget for the BDApps carrier-billed subscription.
///
/// Wraps a [child] (typically a scanner flow, but currently exposed as
/// just the entry point). On mount it:
///
///   1. Reads the **cached** subscribed flag from the orchestrator's
///      store. If true, renders [child] immediately — no network call.
///   2. Otherwise calls [BdappsSubscriptionService.recheckStatus]
///      (the authoritative `checkStatus` round-trip) once. Three
///      branches:
///        * `subscribed` → render [child], persist the cached flag.
///        * `notSubscribed` → render [BdappsMobileScreen] full-screen
///          (no back — the entry-point callers gate user navigation).
///        * `unknown` → render a retry card with a Try-again button
///          and a manual fallback that opens [BdappsMobileScreen].
///
/// **Important:** the gate's status check never grants or denies
/// access based on the cached flag alone — it always re-resolves with
/// the network when the cached flag is false. This is what protects
/// against a stranded-user dead-loop (masked-id drift, operator-side
/// unsubscribe, etc.).
///
/// **Not wired into any scanner route in this PR.** Per the
/// implementation plan, gating specific scanners is a separate product
/// decision. For now the gate is reachable from the Profile screen's
/// "Mobile carrier subscription" menu item so QA can exercise the
/// full flow per the BDApps workflow doc.
class BdappsGate extends StatefulWidget {
  const BdappsGate({
    super.key,
    required this.child,
    this.verifyingTimeout = const Duration(seconds: 3),
    this.forceFreeFallback = false,
  });

  /// The protected subtree. Rendered only when the gate resolves to
  /// `subscribed`. For the v1 entry-point use case this is unused
  /// (the gate routes to the Mobile screen instead) — we still pass
  /// it for forward-compatibility with future product integrations.
  final Widget child;

  /// How long the "Verifying…" branch may render before we time out
  /// and fall through to the not-subscribed path. Defaults to 3s; can
  /// be shortened in tests via [forceFreeFallback].
  final Duration verifyingTimeout;

  /// When true (test-only), the gate skips the network probe
  /// entirely and falls through to the not-subscribed branch after
  /// one frame. Mirrors the previous "no gate wired" behaviour for
  /// tests that haven't set up a fake service.
  final bool forceFreeFallback;

  @override
  State<BdappsGate> createState() => _BdappsGateState();
}

class _BdappsGateState extends State<BdappsGate> {
  /// Tri-state of the gate's current render decision. Distinct from
  /// [BdappsSubscriptionService.state] (which is the OTP-flow state
  /// machine).
  _GatePhase _phase = _GatePhase.checking;
  String? _phaseError;

  @override
  void initState() {
    super.initState();
    // Defer to the first frame so descendants that depend on the
    // scope have a chance to register listeners. Also keeps the
    // initial render flicker-free on warm starts where the cached
    // flag is already true (we resolve synchronously below).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolve();
    });
  }

  Future<void> _resolve() async {
    if (widget.forceFreeFallback) {
      if (mounted) setState(() => _phase = _GatePhase.notSubscribed);
      return;
    }
    final service = BdappsSubscriptionScope.of(context);
    // Fast path: if we already know (cached) we're subscribed, skip
    // the network call. This is the warm-start path — re-resolving
    // every entry would burn a `checkStatus` round-trip on every
    // Profile-screen tap.
    if (service.store.getCachedSubscribed()) {
      setState(() => _phase = _GatePhase.passed);
      return;
    }
    setState(() => _phase = _GatePhase.checking);

    // If the service is still in the "unknown" state (cold start
    // with no cached decision), give the network a bounded window
    // to respond. After the timeout, fall through to the mobile
    // entry so the user is never blocked on a hung probe.
    final completer = _Completer<BdappsStatus>();
    final probe = service.recheckStatus().then((s) {
      if (!completer.isCompleted) completer.complete(s);
    }).catchError((Object e, StackTrace s) {
      if (!completer.isCompleted) {
        completer.complete(BdappsStatus.unknown);
      }
    });
    final timedOut = Future<void>.delayed(widget.verifyingTimeout, () {
      if (!completer.isCompleted) {
        completer.complete(BdappsStatus.unknown);
      }
    });
    // Suppress unawaited lint — the future is consumed via the
    // completer race above.
    unawaited(Future.wait([probe, timedOut]));
    final status = await completer.future;
    if (!mounted) return;
    switch (status) {
      case BdappsStatus.subscribed:
        setState(() => _phase = _GatePhase.passed);
      case BdappsStatus.notSubscribed:
        setState(() => _phase = _GatePhase.notSubscribed);
      case BdappsStatus.unknown:
        setState(() {
          _phase = _GatePhase.unknown;
          _phaseError =
              service.lastError; // may be null; UI handles gracefully
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _GatePhase.checking:
        // Reading `service.isPending` here (reactive — runs in build,
        // not initState) lets us distinguish "first probe in
        // progress" from "we've never checked and need a hint".
        final service = BdappsSubscriptionScope.of(context);
        final t = AppLocaleScope.of(context).tr;
        if (service.isPending) {
          return _CheckingScaffold(
            label: t('subscription.gate.verifying'),
            sublabel: t('subscription.gate.verifyingSubtitle'),
          );
        }
        return _CheckingScaffold(
          label: t('subscription.gateChecking'),
          sublabel: null,
        );
      case _GatePhase.passed:
        return widget.child;
      case _GatePhase.notSubscribed:
        // Full-screen entry. No back: callers gate the navigation so
        // the user must complete (or cancel) the BDApps flow before
        // they can return. The Mobile screen's own back-arrow can
        // still navigate within the flow.
        return const BdappsMobileScreen();
      case _GatePhase.unknown:
        return _RetryScaffold(
          errorDetail: _phaseError,
          onTryAgain: _resolve,
          onManualSubscribe: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BdappsMobileScreen(),
              ),
            );
          },
        );
    }
  }
}

enum _GatePhase { checking, passed, notSubscribed, unknown }

/// Tiny one-shot completer used by the gate to race a network probe
/// against a bounded timeout without sprinkling `Completer` boilerplate.
class _Completer<T> {
  final _c = Completer<T>();
  bool get isCompleted => _c.isCompleted;
  void complete(T value) => _c.complete(value);
  Future<T> get future => _c.future;
}

/// Loading state shown while the gate's first status probe runs.
/// Kept ultra-minimal — the worst case (network down) falls through
/// to [_RetryScaffold] after one round-trip, so we don't want a
/// splashy progress indicator that masks the actual problem.
class _CheckingScaffold extends StatelessWidget {
  const _CheckingScaffold({required this.label, this.sublabel});

  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('subscription.menuTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (sublabel != null) ...[
              const SizedBox(height: 6),
              Text(
                sublabel!,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Retry card shown when `recheckStatus` returns `unknown` — e.g.
/// airplane mode, TLS failure, or a PHP outage. Mirrors the
/// error-state shape used by the rest of the app (centered icon +
/// heading + body + two actions).
class _RetryScaffold extends StatelessWidget {
  const _RetryScaffold({
    required this.errorDetail,
    required this.onTryAgain,
    required this.onManualSubscribe,
  });

  final String? errorDetail;
  final VoidCallback onTryAgain;
  final VoidCallback onManualSubscribe;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('subscription.menuTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.riskMedium.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 32,
                  color: AppTheme.riskMedium,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t('subscription.gateRetryTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('subscription.gateRetryBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              if (errorDetail != null && errorDetail!.isNotEmpty) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: errorDetail!),
              ],
              const Spacer(),
              BdappsGradientCta(
                label: t('subscription.gateTryAgain'),
                onPressed: onTryAgain,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onManualSubscribe,
                child: Text(t('subscription.gateManual')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}