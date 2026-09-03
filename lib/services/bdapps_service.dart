import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Client for the BDApps (Robi/Airtel, Bangladesh) carrier-billed
/// subscription backend. Companion to `BDAPPS_API_REFERENCE.md` — every
/// field name, status code, and gotcha in that doc is reflected here.
///
/// **Two layers per call:**
///   * App → PHP: form-encoded POST (`application/x-www-form-urlencoded`).
///     The PHP layer reads `$_POST`, attaches the BDApps app credentials,
///     and forwards as JSON.
///   * PHP → BDApps: JSON. We never see those payloads directly.
///
/// **Why this exists as a parallel system:**
/// `lib/services/bdapps_subscription_service.dart` is the orchestrator
/// (frontend-only today). The BDApps flow is the **carrier-billed** tier
/// — the user pays via their Robi/Airtel mobile bill and BDApps mediates.
/// The two are independent state machines; this client deliberately does
/// not touch the in-app Premium service.
///
/// **Masked-subscriberId contract (the most important lesson):**
/// for this app type, BDApps masks subscriber identities. After
/// `otp/verify` succeeds, the only accepted identifier for future
/// `getStatus` / `subscription/send` calls is the masked
/// `tel:<base64>:robi` value the verify response returns — NOT the raw
/// `tel:88...` MSISDN, NOT the `referenceNo` from `otp/request`. Losing
/// it strands the user in a dead-loop (status check returns E1951 →
/// not-subscribed → re-subscribe fails with E1351 "already
/// registered"). Persistence is handled in
/// `bdapps_subscription_store.dart`.
class BdappsService {
  BdappsService({http.Client? client})
      : _client = client ?? http.Client();

  /// Base URL of the PHP layer. Every endpoint is `base + filename`.
  /// Override at build time with
  /// `--dart-define=BDAPPS_BASE_URL=...` for staging. Production is the
  /// default and matches the live deployment per `BDAPPS_WORKFLOW.md`.
  static const String _defaultBaseUrl =
      'https://bdappsdigitalapps.com/NirapodClick';

  /// Convenience const for callers that need to log it once. Pulled from
  /// [_defaultBaseUrl] when no override is supplied.
  String get baseUrl => const String.fromEnvironment(
        'BDAPPS_BASE_URL',
        defaultValue: _defaultBaseUrl,
      );

  final http.Client _client;

  // --------------------------------------------------------------- sendOtp

  /// Start the subscription: BDApps texts an OTP to the user. On the
  /// `E1351` ("user already registered") branch, the user is treated as
  /// already subscribed — the caller should skip the OTP step entirely
  /// and route to the success / gate pass-through.
  ///
  /// [mobile880] is the canonical 13-digit form (`8801XXXXXXXXX`). The
  /// PHP layer accepts `01XXXXXXXXX` too, but normalizing at the edge
  /// keeps the rest of the codebase in one shape.
  Future<BdappsSendOtpResult> sendOtp(String mobile880) async {
    final endpoint = '$baseUrl/send_otp.php';
    final body = {'user_mobile': mobile880};

    _logRequest('POST', endpoint, body);

    final http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse(endpoint),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
    } catch (e) {
      _logError(endpoint, e);
      return BdappsSendOtpResult.networkError(e.toString());
    }
    _logResponse(endpoint, resp);

    final decoded = _safeJson(resp.body);
    if (decoded == null) {
      // PHP validation error (e.g. `{"error":"Invalid mobile format"}`)
      // returns as a flat object too. We sniff for `error` key first.
      try {
        final flat = json.decode(resp.body);
        if (flat is Map && flat['error'] is String) {
          return BdappsSendOtpResult.validationError(flat['error'] as String);
        }
      } catch (_) {/* fallthrough */}
      return BdappsSendOtpResult.unparseable(resp.body);
    }

    // Per the API ref:
    //   success:   { success: true,  referenceNo: "...", statusCode: "S1000" }
    //   already:   { success: false, referenceNo: null,
    //                statusCode: "E1351", subscriberId: "tel:8801..." }
    //   other E:   { success: false, statusCode: "E....", statusDetail: "..." }
    final statusCode = (decoded['statusCode'] as String?) ?? '';
    final success = decoded['success'] == true;

    if (success && statusCode == 'S1000') {
      final referenceNo = decoded['referenceNo'] as String?;
      if (referenceNo == null || referenceNo.isEmpty) {
        return BdappsSendOtpResult.unparseable(resp.body);
      }
      return BdappsSendOtpResult.ok(referenceNo);
    }

    if (statusCode == 'E1351' || statusCode == 'E1331') {
      // E1351 = "user already registered" — treat as subscribed.
      // E1331 also surfaces for already-subscribed per the docs.
      return const BdappsSendOtpResult.alreadySubscribed();
    }

    return BdappsSendOtpResult.upstreamError(
      code: statusCode.isEmpty ? 'UNKNOWN' : statusCode,
      message: (decoded['statusDetail'] as String?) ?? 'Send OTP failed.',
    );
  }

  // --------------------------------------------------------------- verifyOtp

  /// Confirm the OTP. On success, returns the **masked `subscriberId`**
  /// (e.g. `tel:ZDAwODFj...ea97:robi`). This is the single most
  /// important value in the integration — see class doc.
  ///
  /// The OTP field is sent as `Otp` (capital O) — that's the
  /// backend contract per `BDAPPS_API_REFERENCE.md` §2.
  Future<BdappsVerifyOtpResult> verifyOtp({
    required String referenceNo,
    required String otp,
  }) async {
    final endpoint = '$baseUrl/verify_otp.php';
    final body = {'Otp': otp, 'referenceNo': referenceNo};

    _logRequest('POST', endpoint, body);

    final http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse(endpoint),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
    } catch (e) {
      _logError(endpoint, e);
      return BdappsVerifyOtpResult.networkError(e.toString());
    }
    _logResponse(endpoint, resp);

    final decoded = _safeJson(resp.body);
    if (decoded == null) {
      // Our PHP wraps its own validation in { message, statusCode: "FAILED" }.
      try {
        final flat = json.decode(resp.body);
        if (flat is Map &&
            flat['statusCode'] == 'FAILED' &&
            flat['message'] is String) {
          return BdappsVerifyOtpResult.upstreamError(
            code: 'FAILED',
            message: flat['message'] as String,
          );
        }
      } catch (_) {/* fallthrough */}
      return BdappsVerifyOtpResult.unparseable(resp.body);
    }

    final statusCode = (decoded['statusCode'] as String?) ?? '';
    final subscriptionStatus =
        (decoded['subscriptionStatus'] as String?) ?? '';
    final subscriberId = (decoded['subscriberId'] as String?) ?? '';

    if (statusCode == 'S1000' && subscriptionStatus == 'REGISTERED') {
      if (subscriberId.isEmpty) {
        // Per the API ref this is authoritative — if PHP didn't echo a
        // masked ID we MUST NOT treat the verify as successful, otherwise
        // the user is stranded in the dead-loop.
        return BdappsVerifyOtpResult.upstreamError(
          code: 'NO_SUBSCRIBER_ID',
          message: 'Verify succeeded but no subscriberId was returned.',
        );
      }
      return BdappsVerifyOtpResult.ok(maskedSubscriberId: subscriberId);
    }

    return BdappsVerifyOtpResult.upstreamError(
      code: statusCode.isEmpty ? 'UNKNOWN' : statusCode,
      message: (decoded['statusDetail'] as String?) ?? 'Verify failed.',
    );
  }

  // --------------------------------------------------------------- checkStatus

  /// Authoritative "is this user subscribed" check. Returns a tri-state
  /// so the gate can distinguish "yes" / "no" / "I don't know — retry".
  ///
  /// Resolution rules (per `BDAPPS_API_REFERENCE.md` §3 + workflow doc
  /// §4): `isSubscribed` boolean first; then `subscriptionStatus` string
  /// with "unregistered" / "unknown" checked BEFORE "registered" (both
  /// contain the substring); then `statusCode` S/E tiebreaker; else
  /// `unknown`.
  ///
  /// Always prefer [subscriberId] (masked) when available. Without it
  /// the PHP layer falls back to the raw MSISDN, which BDApps REJECTS
  /// with E1951 for this app type — and the gate would then incorrectly
  /// mark a real subscriber as not-subscribed. Pass the mobile
  /// alongside so PHP can do its own resolution.
  Future<BdappsCheckStatusResult> checkStatus({
    required String mobile880,
    String? subscriberId,
  }) async {
    final endpoint = '$baseUrl/check_subscription.php';
    final body = <String, String>{
      'user_mobile': mobile880,
      if (subscriberId != null && subscriberId.isNotEmpty)
        'subscriberId': subscriberId,
    };

    _logRequest('POST', endpoint, body);

    final http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse(endpoint),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
    } catch (e) {
      _logError(endpoint, e);
      return BdappsCheckStatusResult.networkError(e.toString());
    }
    _logResponse(endpoint, resp);

    final decoded = _safeJson(resp.body);
    if (decoded == null) {
      return BdappsCheckStatusResult.unparseable(resp.body);
    }

    final isSubscribedBool = decoded['isSubscribed'] == true;
    final subscriptionStatus =
        ((decoded['subscriptionStatus'] as String?) ?? '').toUpperCase();
    final statusCode = (decoded['statusCode'] as String?) ?? '';

    final BdappsStatus status;
    if (isSubscribedBool) {
      status = BdappsStatus.subscribed;
    } else if (subscriptionStatus.contains('UNREGISTERED') ||
        subscriptionStatus.contains('UNKNOWN') ||
        subscriptionStatus.isEmpty) {
      // Order matters — "unregistered" / "unknown" CONTAIN "registered".
      // Check negative forms first.
      status = BdappsStatus.notSubscribed;
    } else if (subscriptionStatus.contains('REGISTERED')) {
      // isSubscribed was false but status string says REGISTERED → trust
      // the string (BDApps sometimes returns the status without the bool).
      status = BdappsStatus.subscribed;
    } else if (statusCode.startsWith('S')) {
      status = BdappsStatus.subscribed;
    } else {
      // Transport-OK but we couldn't classify the response — return
      // `unknown` so the gate shows retry rather than wrongly denying
      // access to a paying subscriber.
      status = BdappsStatus.unknown;
    }

    // Re-emit the masked subscriberId from the response if PHP echoed it
    // — that's our chance to refresh the persisted value if it ever
    // drifted (e.g. operator-side unsubscribe + re-subscribe cycle).
    final echoedId = (decoded['subscriberId'] as String?) ?? '';
    return BdappsCheckStatusResult(
      status: status,
      echoedSubscriberId: echoedId.isEmpty ? null : echoedId,
    );
  }

  // --------------------------------------------------------------- unsubscribe

  /// Drop the user's carrier-billed subscription. The PHP success rule
  /// is `statusCode == "S1000"` OR `subscriptionStatus == "UNREGISTERED"`
  /// — both indicate the unsubscribe landed.
  ///
  /// E1951 here means "already unregistered" — also a successful outcome
  /// from the user's perspective (they wanted to be unsubscribed and
  /// they are). We treat it as success.
  Future<BdappsUnsubscribeResult> unsubscribe({
    required String mobile880,
    required String subscriberId,
  }) async {
    final endpoint = '$baseUrl/unsubscribe.php';
    final body = <String, String>{
      'user_mobile': mobile880,
      'subscriberId': subscriberId,
    };

    _logRequest('POST', endpoint, body);

    final http.Response resp;
    try {
      resp = await _client.post(
        Uri.parse(endpoint),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
    } catch (e) {
      _logError(endpoint, e);
      return BdappsUnsubscribeResult.networkError(e.toString());
    }
    _logResponse(endpoint, resp);

    final decoded = _safeJson(resp.body);
    if (decoded == null) {
      return BdappsUnsubscribeResult.unparseable(resp.body);
    }

    final statusCode = (decoded['statusCode'] as String?) ?? '';
    final subscriptionStatus =
        ((decoded['subscriptionStatus'] as String?) ?? '').toUpperCase();
    final successFlag = decoded['success'] == true;

    final ok = statusCode == 'S1000' ||
        subscriptionStatus == 'UNREGISTERED' ||
        // PHP reports E1951 + success:false for "already gone" — from
        // the user's perspective that's still success.
        statusCode == 'E1951' ||
        // Defensive: PHP may also return success:true on its own rule.
        successFlag;

    if (ok) {
      return const BdappsUnsubscribeResult.ok();
    }

    return BdappsUnsubscribeResult.upstreamError(
      code: statusCode.isEmpty ? 'UNKNOWN' : statusCode,
      message: (decoded['statusDetail'] as String?) ?? 'Unsubscribe failed.',
    );
  }

  // ===================================================================
  // Internals
  // ===================================================================

  /// Tolerant JSON decode. Returns null on missing / unparseable body so
  /// the caller can fall back to the raw-body branch (per the API ref,
  /// PHP validation errors come back as `{ "error": "..." }` rather than
  /// the standard envelope).
  Map<String, dynamic>? _safeJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {/* fallthrough */}
    return null;
  }

  void _logRequest(String method, String endpoint, Map<String, String> body) {
    if (!kDebugMode) return;
    // Never log OTP / referenceNo values to the console in production;
    // kDebugMode is the gate per the workflow doc.
    debugPrint('[BDApps] -> $method $endpoint body=${_redact(body)}');
  }

  void _logResponse(String endpoint, http.Response resp) {
    if (!kDebugMode) return;
    debugPrint(
      '[BDApps] <- ${resp.statusCode} $endpoint '
      'body=${resp.body.length > 400 ? '${resp.body.substring(0, 400)}…' : resp.body}',
    );
  }

  void _logError(String endpoint, Object e) {
    if (!kDebugMode) return;
    debugPrint('[BDApps] !! $endpoint failed: $e');
  }

  /// Strip OTP and referenceNo from logs so a leaked logcat / console
  /// capture can't be replayed against the verify endpoint.
  Map<String, String> _redact(Map<String, String> body) {
    return body.map((k, v) {
      if (k == 'Otp' || k == 'referenceNo') {
        return MapEntry(k, '***');
      }
      return MapEntry(k, v);
    });
  }
}

// =====================================================================
// Result types — Dart 3 sealed classes, exhaustive via `switch`.
// =====================================================================

/// Tri-state for [BdappsService.checkStatus]. `unknown` means "I can't
/// tell — retry"; never grants or denies access on its own.
enum BdappsStatus { subscribed, notSubscribed, unknown }

/// Discriminated-union of possible [BdappsService.sendOtp] outcomes.
sealed class BdappsSendOtpResult {
  const BdappsSendOtpResult();

  /// `S1000` returned, OTP is on its way.
  const factory BdappsSendOtpResult.ok(String referenceNo) =
      BdappsSendOtpOk;

  /// `E1351` / `E1331` — user is already subscribed. Skip OTP entirely.
  const factory BdappsSendOtpResult.alreadySubscribed() =
      BdappsSendOtpAlreadySubscribed;

  /// PHP rejected the input before reaching BDApps (e.g. invalid mobile
  /// format). The [message] is the user-facing string.
  const factory BdappsSendOtpResult.validationError(String message) =
      BdappsSendOtpValidationError;

  /// Network / DNS / TLS failure. The caller should show a generic
  /// "try again" and not loop.
  const factory BdappsSendOtpResult.networkError(String detail) =
      BdappsSendOtpNetworkError;

  /// BDApps returned an E-code other than the "already subscribed"
  /// branches (e.g. `E1343` not whitelisted, `E1313` auth failed).
  /// The [code] is the BDApps statusCode; [message] is the
  /// statusDetail.
  const factory BdappsSendOtpResult.upstreamError({
    required String code,
    required String message,
  }) = BdappsSendOtpUpstreamError;

  /// Body didn't match any known shape — caller should treat as upstream
  /// failure.
  const factory BdappsSendOtpResult.unparseable(String body) =
      BdappsSendOtpUnparseable;
}

final class BdappsSendOtpOk extends BdappsSendOtpResult {
  const BdappsSendOtpOk(this.referenceNo);
  final String referenceNo;
}

final class BdappsSendOtpAlreadySubscribed extends BdappsSendOtpResult {
  const BdappsSendOtpAlreadySubscribed();
}

final class BdappsSendOtpValidationError extends BdappsSendOtpResult {
  const BdappsSendOtpValidationError(this.message);
  final String message;
}

final class BdappsSendOtpNetworkError extends BdappsSendOtpResult {
  const BdappsSendOtpNetworkError(this.message);
  final String message;
}

final class BdappsSendOtpUpstreamError extends BdappsSendOtpResult {
  const BdappsSendOtpUpstreamError({required this.code, required this.message});
  final String code;
  final String message;
}

final class BdappsSendOtpUnparseable extends BdappsSendOtpResult {
  const BdappsSendOtpUnparseable(this.body);
  final String body;
}

extension BdappsSendOtpResultX on BdappsSendOtpResult {
  bool get isOk => this is BdappsSendOtpOk;
  bool get isAlreadySubscribed => this is BdappsSendOtpAlreadySubscribed;
  bool get isError => !isOk && !isAlreadySubscribed;

  /// Convenience: the `referenceNo` from the [ok] branch. Null for
  /// every other outcome — callers should branch on [isOk] first.
  String? get referenceNoOrNull =>
      this is BdappsSendOtpOk ? (this as BdappsSendOtpOk).referenceNo : null;
}

/// Outcome of [BdappsService.verifyOtp]. The single happy path is
/// [BdappsVerifyOtpOk.maskedSubscriberId] being non-null — that value
/// MUST be persisted (see `BdappsSubscriptionStore.setSubscriberId`)
/// or the user is stranded.
sealed class BdappsVerifyOtpResult {
  const BdappsVerifyOtpResult();

  const factory BdappsVerifyOtpResult.ok({required String maskedSubscriberId}) =
      BdappsVerifyOtpOk;

  const factory BdappsVerifyOtpResult.upstreamError({
    required String code,
    required String message,
  }) = BdappsVerifyOtpUpstreamError;

  const factory BdappsVerifyOtpResult.networkError(String detail) =
      BdappsVerifyOtpNetworkError;

  const factory BdappsVerifyOtpResult.unparseable(String body) =
      BdappsVerifyOtpUnparseable;
}

final class BdappsVerifyOtpOk extends BdappsVerifyOtpResult {
  const BdappsVerifyOtpOk({required this.maskedSubscriberId});
  final String maskedSubscriberId;
}

final class BdappsVerifyOtpUpstreamError extends BdappsVerifyOtpResult {
  const BdappsVerifyOtpUpstreamError({
    required this.code,
    required this.message,
  });
  final String code;
  final String message;
}

final class BdappsVerifyOtpNetworkError extends BdappsVerifyOtpResult {
  const BdappsVerifyOtpNetworkError(this.message);
  final String message;
}

final class BdappsVerifyOtpUnparseable extends BdappsVerifyOtpResult {
  const BdappsVerifyOtpUnparseable(this.body);
  final String body;
}

extension BdappsVerifyOtpResultX on BdappsVerifyOtpResult {
  bool get isOk => this is BdappsVerifyOtpOk;
  bool get isError => !isOk;

  /// Convenience: the masked subscriberId from the [ok] branch.
  /// Null for every other outcome — callers should branch on [isOk].
  String? get maskedSubscriberIdOrNull =>
      this is BdappsVerifyOtpOk
          ? (this as BdappsVerifyOtpOk).maskedSubscriberId
          : null;
}

/// Tri-state result for [BdappsService.checkStatus].
class BdappsCheckStatusResult {
  const BdappsCheckStatusResult({
    required this.status,
    this.echoedSubscriberId,
    this.networkDetail,
    this.unparseableBody,
  });

  /// Convenience for the network-error branch.
  factory BdappsCheckStatusResult.networkError(String detail) =>
      BdappsCheckStatusResult(
        status: BdappsStatus.unknown,
        networkDetail: detail,
      );

  /// Convenience for the unparseable-body branch.
  factory BdappsCheckStatusResult.unparseable(String body) =>
      BdappsCheckStatusResult(
        status: BdappsStatus.unknown,
        unparseableBody: body,
      );

  final BdappsStatus status;

  /// If PHP echoed back a `subscriberId` (the masked one), the caller
  /// can use this to refresh the persisted value. Null when PHP didn't
  /// echo one (typical for not-subscribed responses).
  final String? echoedSubscriberId;

  /// Set when the failure was network-level; null otherwise. Surfaced
  /// in logs only — never user-facing verbatim.
  final String? networkDetail;

  /// Set when PHP returned a body we couldn't parse. Null otherwise.
  final String? unparseableBody;

  bool get isError =>
      networkDetail != null || unparseableBody != null;
}

/// Outcome of [BdappsService.unsubscribe].
sealed class BdappsUnsubscribeResult {
  const BdappsUnsubscribeResult();

  const factory BdappsUnsubscribeResult.ok() = BdappsUnsubscribeOk;

  const factory BdappsUnsubscribeResult.upstreamError({
    required String code,
    required String message,
  }) = BdappsUnsubscribeUpstreamError;

  const factory BdappsUnsubscribeResult.networkError(String detail) =
      BdappsUnsubscribeNetworkError;

  const factory BdappsUnsubscribeResult.unparseable(String body) =
      BdappsUnsubscribeUnparseable;
}

final class BdappsUnsubscribeOk extends BdappsUnsubscribeResult {
  const BdappsUnsubscribeOk();
}

final class BdappsUnsubscribeUpstreamError extends BdappsUnsubscribeResult {
  const BdappsUnsubscribeUpstreamError({
    required this.code,
    required this.message,
  });
  final String code;
  final String message;
}

final class BdappsUnsubscribeNetworkError extends BdappsUnsubscribeResult {
  const BdappsUnsubscribeNetworkError(this.message);
  final String message;
}

final class BdappsUnsubscribeUnparseable extends BdappsUnsubscribeResult {
  const BdappsUnsubscribeUnparseable(this.body);
  final String body;
}

extension BdappsUnsubscribeResultX on BdappsUnsubscribeResult {
  bool get isOk => this is BdappsUnsubscribeOk;
  bool get isError => !isOk;
}