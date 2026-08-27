/// Compile-time allow-list of Firebase Auth UIDs that may publish
/// admin alerts.
///
/// Why a hand-curated list rather than a custom claim?
///   - Custom claims require a Cloud Function to set, which would
///     push us off the free Spark tier.
///   - The list is tiny (1–3 people in practice). Editing a list is
///     cheaper than deploying a function for every promotion.
///   - The check is intentionally O(n) and constant-time-safe — UIDs
///     are arbitrary strings, so there's no timing oracle.
///
/// To promote an admin:
///   1. Ask them to sign in once on the app.
///   2. Open Firebase Console → Authentication → Users, copy their
///      "User UID".
///   3. Add that UID below and ship a release.
const Set<String> kAdminUids = <String>{
  // <-- Add admin UIDs here, one per line, e.g.:
  // 'abc123def456...',
};
