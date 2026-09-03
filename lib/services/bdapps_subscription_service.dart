import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'bdapps_service.dart';
import 'bdapps_subscription_store.dart';

/// Orchestrator for the BDApps carrier-billed subscription flow.
///
/// **Why per-session, not process-wide:**
/// the orchestrator holds the in-flight `referenceNo` + mobile
/// between Send-OTP and Verify-OTP screens, which is per-session,
/// not per-process. Each `BdappsSubscriptionScope` gets a fresh
/// instance so a sign-out → sign-in cycle doesn't leak the previous
/// user's mobile into the new session. A `BdappsSubscriptionService
/// .instance` getter is exposed for code paths that need the service
/// without a `BuildContext` (e.g. `FreeQuotaService.attachBdapps`);
/// that pointer resolves to the most recently constructed instance.
///
/// **State machine** (mirrors `BDAPPS_WORKFLOW.md` §3.1–3.3):
///
///   ┌──────┐ sendOtp (S1000) ────────► ┌─────────┐ verify (S1000) ─► ┌────────────┐
///   │ idle │                          │ otpSent │                   │ subscribed │
///   └──────┘ ◄─── sendOtp (E1351) ─── └─────────┘                   └────────────┘
///      ▲                                                            │
///      │                  sendOtp / verify failed                    │ unsubscribe
///      └────────────────────────────────────────────────────────────┘
///
/// The gate's status probe (`recheckStatus`) does not transition
/// `state` — it returns a separate [BdappsStatus] tri-state so the
/// gate can render three distinct UI branches (child / mobile /
/// retry).
class BdappsSubscriptionService extends ChangeNotifier {
  BdappsSubscriptionService({
    BdappsService? service,
    BdappsSubscriptionStore? store,
  })  : _service = service ?? BdappsService(),
        _store = store ?? BdappsSubscriptionStore.instance;

  /// Process-wide default. The orchestrator itself is per-session
  /// (see class doc), but for the typical app lifecycle (single
  /// sign-in per process) we expose a singleton so non-UI code can
  /// reach the service without a BuildContext. Mirrors
  /// `BdappsSubscriptionScope._default` — both lazily construct the
  /// same instance on first access.
  static BdappsSubscriptionService? _instance;
  static BdappsSubscriptionService get instance =>
      _instance ??= BdappsSubscriptionService();

  final BdappsService _service;
  final BdappsSubscriptionStore _store;

  /// Public so tests can swap or assert on the instance. Don't
  /// `try{}` around construction failures — callers should wire a
  /// stub service in their test setup if they need one.
  BdappsService get service => _service;

  /// Public for the same reason as `service`.
  BdappsSubscriptionStore get store => _store;

  /// Live state of the OTP flow. The gate's status check uses
  /// [recheckStatus] and returns a separate [BdappsStatus] — it does
  /// NOT transition this state machine.
  BdappsFlowState _state = BdappsFlowState.idle;
  BdappsFlowState get state => _state;

  /// Last user-facing error message. UI clears it via [clearError]
  /// when the user dismisses the banner / taps Retry.
  String? _lastError;
  String? get lastError => _lastError;

  /// The referenceNo from the most recent [sendOtp] call. Required by
  /// [verifyOtp]. Null when the user hasn't requested an OTP yet.
  String? _lastReferenceNo;
  String? get lastReferenceNo => _lastReferenceNo;

  /// Mobile tied to the in-flight OTP. Null until [sendOtp] is called.
  /// Held in 880-form (`8801XXXXXXXXX`) so the same value flows into
  /// `checkSubscription` / `unsubscribe` without re-normalising.
  String? _pendingMobile;
  String? get pendingMobile => _pendingMobile;

  /// The masked subscriberId returned by the most recent successful
  /// verify. Held so callers (e.g. an Unsubscribe button) don't need
  /// to round-trip through the store.
  String? _lastSubscriberIdMasked;
  String? get lastSubscriberIdMasked => _lastSubscriberIdMasked;

  /// Convenience: true iff [state] is [BdappsFlowState.subscribed].
  bool get isSubscribed => _state == BdappsFlowState.subscribed;

  // -----------------------------------------------------------------
  // Subscription status — the tri-state used by the gate and the rest
  // of the app. Distinct from [state] (which tracks the OTP-flow
  // state machine). Lives here so a single source of truth drives both
  // the gate UI and the scanners' quota bypass.
  // -----------------------------------------------------------------

  BdappsStatus _status = BdappsStatus.unknown;
  BdappsStatus get status => _status;

  /// True iff the authoritative BDApps status is [BdappsStatus.subscribed].
  /// `unknown` and `notSubscribed` both return false — never grant
  /// premium on uncertainty.
  bool get isPremium => _status == BdappsStatus.subscribed;

  /// True while the cached status is empty and the first
  /// `recheckStatus` call hasn't completed (or has failed). The gate
  /// uses this to render a "Verifying…" branch instead of immediately
  /// falling through to the mobile screen.
  bool get isPending => _status == BdappsStatus.unknown;

  /// Broadcast stream of status transitions. FreeQuotaService
  /// subscribes here to flip its `isPremium` predicate; any UI
  /// surface that needs to react to subscribe / unsubscribe can do
  /// the same.
  Stream<BdappsStatus> get statusStream => _statusController.stream;
  final StreamController<BdappsStatus> _statusController =
      StreamController<BdappsStatus>.broadcast();

  void _setStatus(BdappsStatus next) {
    if (_status == next) return;
    _status = next;
    _statusController.add(next);
    // Notify ChangeNotifier listeners too — UI listening via
    // `AnimatedBuilder(animation: service, ...)` should rebuild
    // when isPremium flips.
    notifyListeners();
  }

  /// Read the cached status from the store and seed [_status] without
  /// a network round-trip. Returns true if a cached decision was
  /// available. Intended for app boot — see `main.dart`. The caller
  /// is expected to follow up with an unawaited `recheckStatus()` for
  /// the authoritative answer.
  bool hydrateFromCache() {
    final cached = _store.getCachedSubscribed();
    if (cached) {
      _setStatus(BdappsStatus.subscribed);
      return true;
    }
    // No cached "subscribed" hint — leave as unknown so the gate can
    // show "Verifying…" while a recheck is in flight, then fall
    // through to notSubscribed on completion.
    return false;
  }

  // -----------------------------------------------------------------
  // Public API — used by the screens
  // -----------------------------------------------------------------

  /// Start the subscription. The returned outcome reports whether the
  /// call landed (success / already-subscribed / failure). The
  /// caller's job is to route the UI based on the [kind] — we do NOT
  /// pop / push screens from here.
  ///
  /// On `E1351`/`E1331` ("already registered") the PHP layer signals
  /// that the user is in fact subscribed; we set
  /// [BdappsFlowState.subscribed] and return the alreadySubscribed
  /// outcome so the caller can show the success card directly.
  Future<BdappsSendOtpOutcome> sendOtp({
    required String mobile880,
  }) async {
    if (_state == BdappsFlowState.subscribing) {
      return const BdappsSendOtpOutcome.busy();
    }
    _pendingMobile = mobile880;
    _lastError = null;
    _transition(BdappsFlowState.subscribing);

    final result = await _service.sendOtp(mobile880);

    if (result.isAlreadySubscribed) {
      // Treat as full success — fetch the masked subscriberId from
      // the store if we already have it (e.g. from a prior session),
      // else the gate will need a status check to decide.
      _lastReferenceNo = null;
      await _store.setCachedSubscribed(true);
      _transition(BdappsFlowState.subscribed);
      _setStatus(BdappsStatus.subscribed);
      return const BdappsSendOtpOutcome.alreadySubscribed();
    }
    if (result.isOk) {
      // `referenceNoOrNull` is non-null only on the `ok` branch.
      _lastReferenceNo = result.referenceNoOrNull;
      await _store.setMobile(mobile880);
      _transition(BdappsFlowState.otpSent);
      return const BdappsSendOtpOutcome.ok();
    }
    // Failure path — roll the state back and stash the message.
    final message = _messageFromSendOtp(result);
    _lastError = message;
    _transition(BdappsFlowState.idle);
    return BdappsSendOtpOutcome.failed(message: message);
  }

  /// Confirm an OTP. On success, the masked subscriberId is persisted
  /// (SharedPreferences + Firestore backup) and the state flips to
  /// [BdappsFlowState.subscribed].
  Future<BdappsVerifyOtpOutcome> verifyOtp({
    required String otp,
  }) async {
    final refNo = _lastReferenceNo;
    final mobile = _pendingMobile;
    if (refNo == null || mobile == null) {
      // UI bug — shouldn't happen unless someone wires the Verify
      // screen without going through Send first.
      _lastError = 'No OTP request in flight';
      return const BdappsVerifyOtpOutcome.notReady();
    }
    if (_state != BdappsFlowState.otpSent) {
      return const BdappsVerifyOtpOutcome.notReady();
    }
    _lastError = null;
    _transition(BdappsFlowState.subscribing);

    final result = await _service.verifyOtp(
      referenceNo: refNo,
      otp: otp,
    );
    if (result.isOk) {
      final masked = result.maskedSubscriberIdOrNull!;
      // Persist masked id BEFORE the binding claim so a binding claim
      // failure can roll back the local state cleanly. We need both:
      // the local subscriberId (for in-session recheckStatus) and the
      // server-side binding (for cross-user enforcement).
      await _store.setSubscriberId(masked);
      await _store.setCachedSubscribed(true);

      // Atomically claim the server-side binding. If another user
      // owns this mobile, the rule denies our create and we have to
      // roll back the local persistence we just did — otherwise the
      // local subscriberId cache would leak a binding we don't own.
      final claimed = await _store.claimBinding(
        mobile880: mobile,
        subscriberId: masked,
      );
      if (!claimed) {
        // Roll back the local persistence. The binding doc exists for
        // someone else; the gate will see `notSubscribed` on its next
        // recheck and the user gets routed back to the mobile-entry
        // screen with a friendly "number is on another account" toast.
        await _store.clearSubscription();
        _lastSubscriberIdMasked = null;
        _lastReferenceNo = null;
        _pendingMobile = null;
        _transition(BdappsFlowState.idle);
        _setStatus(BdappsStatus.notSubscribed);
        return const BdappsVerifyOtpOutcome.numberOwnedByOther();
      }

      _lastSubscriberIdMasked = masked;
      _lastReferenceNo = null;
      _transition(BdappsFlowState.subscribed);
      _setStatus(BdappsStatus.subscribed);
      return const BdappsVerifyOtpOutcome.ok();
    }
    final message = _messageFromVerify(result);
    _lastError = message;
    // Roll back to otpSent — the user can retry with the same OTP
    // (or hit Resend). NOT to idle: that would imply the OTP session
    // itself was reset, which it isn't.
    _transition(BdappsFlowState.otpSent);
    return BdappsVerifyOtpOutcome.failed(message: message);
  }

  /// Authoritative status check used by the gate. Does NOT transition
  /// [state]; returns a tri-state so the caller can render the right
  /// screen branch (child / mobile / retry).
  ///
  /// Tries the masked subscriberId first (the only identifier the
  /// PHP layer will accept for this app type); falls back to the
  /// mobile alone if no masked id is stored.
  ///
  /// Also performs a server-side binding check: if the
  /// `bdapps_bindings` doc for this mobile is owned by a different
  /// Firebase Auth uid, the locally-cached "subscribed" state is
  /// cleared and we return `notSubscribed`. This is the protection
  /// against the same-device / different-user attack where userB
  /// inherits userA's cached subscription state.
  Future<BdappsStatus> recheckStatus() async {
    final mobile = _store.getMobile() ?? _pendingMobile;
    final subscriberId =
        _store.getSubscriberId() ?? _lastSubscriberIdMasked;
    if (mobile == null) {
      // No mobile at all → treat as not subscribed and let the UI
      // route to the entry screen.
      return BdappsStatus.notSubscribed;
    }

    // Server-side binding check FIRST — it's cheaper than the PHP
    // round-trip and is the authoritative answer for cross-user
    // attacks. If the binding says somebody else owns this number,
    // we don't even need to ask BDApps.
    final bindingOwner = await _store.getBindingOwnerUid(mobile);
    final currentUid = _currentUid;
    if (bindingOwner != null && currentUid != null &&
        bindingOwner != currentUid) {
      // Someone else owns this number. Wipe local state so the next
      // cold start doesn't inherit userA's "subscribed" predicate.
      await _store.clearSubscription();
      _lastSubscriberIdMasked = null;
      _pendingMobile = null;
      _setStatus(BdappsStatus.notSubscribed);
      return BdappsStatus.notSubscribed;
    }

    final result = await _service.checkStatus(
      mobile880: mobile,
      subscriberId: subscriberId,
    );
    // Echo refresh: if PHP echoed a subscriberId we didn't know
    // about (operator-side rotation), promote it locally. Best-effort.
    final echoed = result.echoedSubscriberId;
    if (echoed != null && echoed.isNotEmpty && echoed != subscriberId) {
      _lastSubscriberIdMasked = echoed;
      await _store.setSubscriberId(echoed);
    }
    if (result.status == BdappsStatus.subscribed) {
      await _store.setCachedSubscribed(true);
      _pendingMobile ??= mobile;
      _setStatus(BdappsStatus.subscribed);
    } else if (result.status == BdappsStatus.notSubscribed) {
      await _store.setCachedSubscribed(false);
      _setStatus(BdappsStatus.notSubscribed);
    }
    // `unknown` is a transient — leave the cached flag alone so the
    // gate's retry path doesn't repeatedly write the same value.
    // Only update [_status] if we have something concrete to set;
    // otherwise leave it as-is so the gate's "Verifying…" branch
    // can continue to render.
    return result.status;
  }

  /// Drop the subscription. On success the local store is cleared
  /// (except for the mobile) and the state flips to
  /// [BdappsFlowState.idle]. Also releases the server-side binding
  /// so the mobile becomes free for another user to claim.
  Future<BdappsUnsubscribeOutcome> unsubscribe() async {
    final mobile = _store.getMobile() ?? _pendingMobile;
    final subscriberId =
        _store.getSubscriberId() ?? _lastSubscriberIdMasked;
    if (mobile == null || subscriberId == null) {
      // No state to cancel — treat as already-clean.
      _transition(BdappsFlowState.idle);
      return const BdappsUnsubscribeOutcome.notApplicable();
    }
    _lastError = null;
    final result = await _service.unsubscribe(
      mobile880: mobile,
      subscriberId: subscriberId,
    );
    if (result.isOk) {
      await _store.clearSubscription();
      // Release the server-side binding so the same mobile can be
      // re-claimed by a different NirapodClick account. Best-effort:
      // the PHP-side cancellation is the source of truth for
      // carrier-side unbinding; the Firestore binding is our
      // in-app-only dedup mechanism. A release failure is logged in
      // `releaseBinding` and doesn't fail this call.
      await _store.releaseBinding(mobile880: mobile);
      _lastSubscriberIdMasked = null;
      _lastReferenceNo = null;
      _transition(BdappsFlowState.idle);
      _setStatus(BdappsStatus.notSubscribed);
      return const BdappsUnsubscribeOutcome.ok();
    }
    final message = _messageFromUnsubscribe(result);
    _lastError = message;
    return BdappsUnsubscribeOutcome.failed(message: message);
  }

  /// Clear the last error so the UI can dismiss its banner. Safe to
  /// call when [lastError] is already null.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  /// Test-only hook for the OTP-flow state machine.
  void emitForTest(BdappsFlowState next) {
    _state = next;
    notifyListeners();
  }

  /// Test-only hook for [BdappsStatus] transitions.
  void emitStatusForTest(BdappsStatus next) {
    _setStatus(next);
  }

  /// Read the current Firebase Auth uid without throwing if the user
  /// is signed out. Used by [recheckStatus] to compare the binding
  /// owner against the signed-in account.
  String? get _currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // FirebaseAuth isn't ready yet (cold start before init).
      return null;
    }
  }

  /// Wipe every in-memory piece of subscription state. Called from
  /// the auth-state listener in `main.dart` whenever the user signs
  /// out OR a different user signs in on the same device.
  ///
  /// We deliberately do NOT clear the local SharedPreferences cache
  /// here — those entries are UID-scoped, so on the NEXT sign-in
  /// `hydrateFromCache()` reads them under the right account. But
  /// the in-memory `_state`, `_status`, `_lastSubscriberIdMasked`,
  /// etc. are process-wide (the singleton is shared across users),
  /// so they MUST be cleared or the new user inherits the old
  /// user's "subscribed" predicate.
  void resetForSignOut() {
    _state = BdappsFlowState.idle;
    _status = BdappsStatus.unknown;
    _lastSubscriberIdMasked = null;
    _pendingMobile = null;
    _lastReferenceNo = null;
    _lastError = null;
    notifyListeners();
    // Mirror the status flip through the broadcast stream so any
    // out-of-tree listener (FreeQuotaService, etc.) rebuilds too.
    if (!_statusController.isClosed) {
      _statusController.add(BdappsStatus.unknown);
    }
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------

  void _transition(BdappsFlowState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  String _messageFromSendOtp(BdappsSendOtpResult r) => switch (r) {
        BdappsSendOtpOk() => 'Could not send the code. Try again later.',
        BdappsSendOtpAlreadySubscribed() =>
          'Could not send the code. Try again later.',
        BdappsSendOtpValidationError(message: final m) => m,
        BdappsSendOtpNetworkError(message: final m) => m,
        BdappsSendOtpUpstreamError(message: final m) => m,
        BdappsSendOtpUnparseable() =>
          'Could not send the code. Try again later.',
      };

  String _messageFromVerify(BdappsVerifyOtpResult r) => switch (r) {
        BdappsVerifyOtpOk() => 'Wrong code. Try again.',
        BdappsVerifyOtpUpstreamError(message: final m) => m,
        BdappsVerifyOtpNetworkError(message: final m) => m,
        BdappsVerifyOtpUnparseable() => 'Wrong code. Try again.',
      };

  String _messageFromUnsubscribe(BdappsUnsubscribeResult r) => switch (r) {
        BdappsUnsubscribeOk() => 'Could not cancel. Try again later.',
        BdappsUnsubscribeUpstreamError(message: final m) => m,
        BdappsUnsubscribeNetworkError(message: final m) => m,
        BdappsUnsubscribeUnparseable() => 'Could not cancel. Try again later.',
      };
}

/// State of the in-app BDApps flow. Distinct from [BdappsStatus]
/// (which is the gate's tri-state).
enum BdappsFlowState {
  /// Initial state. No OTP request in flight.
  idle,

  /// User just typed a mobile and tapped Send; awaiting OTP delivery.
  /// Transitions: → `subscribing` on retry; → `subscribed` on
  /// verify success; → `idle` on cancel.
  otpSent,

  /// A network call is currently running (send or verify).
  subscribing,

  /// Verified. The masked subscriberId is stored locally. Transitions:
  /// → `idle` on unsubscribe.
  subscribed,
}

/// Outcome of [BdappsSubscriptionService.sendOtp]. Sealed-style so
/// `switch` can be exhaustive.
sealed class BdappsSendOtpOutcome {
  const BdappsSendOtpOutcome();

  const factory BdappsSendOtpOutcome.busy() =
      BdappsSendOtpOutcomeBusy;
  const factory BdappsSendOtpOutcome.ok() =
      BdappsSendOtpOutcomeOk;
  const factory BdappsSendOtpOutcome.alreadySubscribed() =
      BdappsSendOtpOutcomeAlreadySubscribed;
  const factory BdappsSendOtpOutcome.failed({required String message}) =
      BdappsSendOtpOutcomeFailed;
}

final class BdappsSendOtpOutcomeBusy extends BdappsSendOtpOutcome {
  const BdappsSendOtpOutcomeBusy();
}

final class BdappsSendOtpOutcomeOk extends BdappsSendOtpOutcome {
  const BdappsSendOtpOutcomeOk();
}

final class BdappsSendOtpOutcomeAlreadySubscribed extends BdappsSendOtpOutcome {
  const BdappsSendOtpOutcomeAlreadySubscribed();
}

final class BdappsSendOtpOutcomeFailed extends BdappsSendOtpOutcome {
  const BdappsSendOtpOutcomeFailed({required this.message});
  final String message;
}

/// Outcome of [BdappsSubscriptionService.verifyOtp].
sealed class BdappsVerifyOtpOutcome {
  const BdappsVerifyOtpOutcome();

  const factory BdappsVerifyOtpOutcome.notReady() =
      BdappsVerifyOtpOutcomeNotReady;
  const factory BdappsVerifyOtpOutcome.ok() =
      BdappsVerifyOtpOutcomeOk;
  const factory BdappsVerifyOtpOutcome.failed({required String message}) =
      BdappsVerifyOtpOutcomeFailed;

  /// The OTP itself was valid AND BDApps registered the user, but the
  /// Firestore binding for this mobile is owned by a DIFFERENT
  /// NirapodClick account. The local subscriberId has been rolled
  /// back; the UI should surface a friendly "already subscribed on
  /// another account" message and route the user back to the mobile
  /// entry so they can try a different number.
  const factory BdappsVerifyOtpOutcome.numberOwnedByOther() =
      BdappsVerifyOtpOutcomeNumberOwnedByOther;
}

final class BdappsVerifyOtpOutcomeNotReady extends BdappsVerifyOtpOutcome {
  const BdappsVerifyOtpOutcomeNotReady();
}

final class BdappsVerifyOtpOutcomeOk extends BdappsVerifyOtpOutcome {
  const BdappsVerifyOtpOutcomeOk();
}

final class BdappsVerifyOtpOutcomeFailed extends BdappsVerifyOtpOutcome {
  const BdappsVerifyOtpOutcomeFailed({required this.message});
  final String message;
}

final class BdappsVerifyOtpOutcomeNumberOwnedByOther
    extends BdappsVerifyOtpOutcome {
  const BdappsVerifyOtpOutcomeNumberOwnedByOther();
}

/// Outcome of [BdappsSubscriptionService.unsubscribe].
sealed class BdappsUnsubscribeOutcome {
  const BdappsUnsubscribeOutcome();

  const factory BdappsUnsubscribeOutcome.ok() =
      BdappsUnsubscribeOutcomeOk;
  const factory BdappsUnsubscribeOutcome.notApplicable() =
      BdappsUnsubscribeOutcomeNotApplicable;
  const factory BdappsUnsubscribeOutcome.failed({required String message}) =
      BdappsUnsubscribeOutcomeFailed;
}

final class BdappsUnsubscribeOutcomeOk extends BdappsUnsubscribeOutcome {
  const BdappsUnsubscribeOutcomeOk();
}

final class BdappsUnsubscribeOutcomeNotApplicable
    extends BdappsUnsubscribeOutcome {
  const BdappsUnsubscribeOutcomeNotApplicable();
}

final class BdappsUnsubscribeOutcomeFailed extends BdappsUnsubscribeOutcome {
  const BdappsUnsubscribeOutcomeFailed({required this.message});
  final String message;
}
