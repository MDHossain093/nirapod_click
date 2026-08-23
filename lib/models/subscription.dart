/// Premium subscription model.
///
/// Pure data — no Flutter, no Firebase. The actual bKash / bdapps
/// integration will be plugged into [SubscriptionService] later; this
/// file just defines the shapes the UI speaks.
///
/// Free vs Premium plan numbers were chosen to mirror common freemium
/// scam-checker apps: enough daily scans to evaluate the app, but a
/// clear incentive to upgrade.
library;

/// High-level subscription state machine. The UI keys off this enum;
/// the service is responsible for transitions.
enum SubscriptionStatus {
  /// Default for new users. Quotas apply.
  free,

  /// Mid-purchase. The subscribe button is pressed but the bdapps
  /// callback has not resolved yet. UI shows a spinner + "Verifying..."
  subscribing,

  /// Subscription is live. Quotas are unlimited.
  active,

  /// Was active, is now expired. Returns the user to free tier but
  /// preserves history.
  expired,
}

/// Per-plan quota counts. `null` means unlimited.
///
/// We count remaining scans per day, not per session, so the service
/// is expected to reset these at midnight local time. For v1 we only
/// show them in the UI; enforcement is added once the rest of the
/// quota plumbing is in place.
class PlanLimits {
  const PlanLimits({
    this.messageScansRemaining,
    this.urlScansRemaining,
    this.screenshotScansRemaining,
    this.phoneScansRemaining,
  });

  final int? messageScansRemaining;
  final int? urlScansRemaining;
  final int? screenshotScansRemaining;
  final int? phoneScansRemaining;

  /// Free-tier defaults. URL + phone stay unlimited on free because
  /// those rely on local engines with no per-call cost; the message
  /// and screenshot paths are the ones that burn Gemini quota.
  factory PlanLimits.freeDefault() => const PlanLimits(
        messageScansRemaining: 4,
        urlScansRemaining: null,
        screenshotScansRemaining: 3,
        phoneScansRemaining: null,
      );

  /// Premium — every scan type is unlimited.
  factory PlanLimits.unlimited() => const PlanLimits(
        messageScansRemaining: null,
        urlScansRemaining: null,
        screenshotScansRemaining: null,
        phoneScansRemaining: null,
      );

  /// Pretty label for the profile card's quota line.
  ///
  /// Returns "Unlimited" when the quota is null, otherwise the
  /// integer count.
  static String format(int? remaining) =>
      remaining == null ? '∞' : remaining.toString();
}

/// Snapshot of a user's subscription at a point in time. The service
/// emits new copies of this whenever state changes.
class SubscriptionState {
  const SubscriptionState({
    required this.status,
    required this.limits,
    this.nextRenewalAt,
    this.lastError,
  });

  /// Initial state for a freshly-signed-up user.
  factory SubscriptionState.fresh() => SubscriptionState(
        status: SubscriptionStatus.free,
        limits: PlanLimits.freeDefault(),
      );

  final SubscriptionStatus status;
  final PlanLimits limits;

  /// Null for free tier; populated when the user is active so the
  /// profile card can render `Next renewal: <date>`.
  final DateTime? nextRenewalAt;

  /// Set by the service when [SubscriptionStatus.subscribing] fails
  /// so the UI can render an error banner with a Try Again button.
  final String? lastError;

  bool get isPremium => status == SubscriptionStatus.active;
  bool get isFree =>
      status == SubscriptionStatus.free || status == SubscriptionStatus.expired;
  bool get isSubscribing => status == SubscriptionStatus.subscribing;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    PlanLimits? limits,
    DateTime? nextRenewalAt,
    String? lastError,
    bool clearLastError = false,
    bool clearNextRenewal = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      limits: limits ?? this.limits,
      nextRenewalAt:
          clearNextRenewal ? null : (nextRenewalAt ?? this.nextRenewalAt),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
