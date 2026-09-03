import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the BDApps carrier-billed subscription state for a single
/// user. All keys are scoped by Firebase UID so multiple accounts on the
/// same device don't collide.
///
/// **Why three separate keys (not one JSON blob):**
///   * `mobile` is small and frequently read at gate-check time.
///   * `subscriberId` is the **masked** identifier — the only thing the
///     BDApps PHP layer will accept on `checkStatus` / `unsubscribe`
///     for this app type. Losing it strands the user in the dead-loop
///     described in `bdapps_service.dart`'s class doc, so we keep its
///     write path small and obvious.
///   * `cachedSubscribed` is a UI hint only — the gate's authoritative
///     check always goes through `BdappsService.checkStatus`. Kept
///     separate so a partial-write failure (e.g. quota error on one key)
///     doesn't roll back the other two.
///
/// **Why also write to Firestore:**
/// the masked subscriberId is precious (see above). If the user wipes
/// app data (or installs the app on a new device signed in to the same
/// Firebase account), the gate would otherwise see no stored subscriberId
/// and treat them as not-subscribed — but BDApps still has them
/// registered, so `sendOtp` would fail with `E1351`. The Firestore
/// backup at `users/{uid}.bdappsSubscriberId` lets us rehydrate.
/// SharedPreferences is the primary fast-path; Firestore is the safety
/// net.
class BdappsSubscriptionStore {
  BdappsSubscriptionStore._();

  /// Lazy singleton. The store is process-wide — no instance is held
  /// inside `BdappsScope` — because the data is keyed by UID and
  /// survives sign-out → sign-in cycles for the same device. The
  /// `BdappsSubscriptionService` (orchestrator) holds its own
  /// ChangeNotifier state, which DOES reset per sign-in.
  static final BdappsSubscriptionStore instance = BdappsSubscriptionStore._();

  /// Firestore field name on `users/{uid}` that holds the masked
  /// subscriberId. Public so tests / migrations can reference it.
  static const String firestoreField = 'bdappsSubscriberId';

  /// Firestore collection that enforces one Robi/Airtel number ↔ one
  /// NirapodClick account. Doc id = `bd_<mobile880>`; payload carries
  /// the owner's uid so the rule layer can authoritatively answer
  /// "is this mobile already bound to someone else?" without trusting
  /// the client. See `firestore.rules` for the rule block.
  static const String bindingCollection = 'bdapps_bindings';
  static const String _bindingOwnerUidField = 'ownerUid';
  static const String _bindingSubscriberIdField = 'subscriberId';
  static const String _bindingMobileField = 'mobile';
  static const String _bindingUpdatedAtField = 'updatedAt';

  /// Doc-id encoding for a mobile in the binding collection. The
  /// `bd_` prefix keeps the namespace clean (no clash with users' uid
  /// if anyone ever moves them into the same collection by mistake).
  static String bindingDocId(String mobile880) => 'bd_$mobile880';

  // --------------------------------------------------------------- keys

  String _mobileKey(String uid) => 'bdapps_mobile_$uid';
  String _subscriberIdKey(String uid) => 'bdapps_subscriber_id_$uid';
  String _cachedSubKey(String uid) => 'bdapps_cached_sub_$uid';

  // Legacy unscoped keys from any pre-UID-scoped version. We migrate
  // them into the UID-scoped slot on first read, then delete the old.
  // Mirrors QuizBee's per-user scoping fix.
  static const String _legacySubscriberIdKey = 'bdapps_subscriber_id';
  static const String _legacyCachedSubKey = 'bdapps_cached_sub';

  // --------------------------------------------------------------- reads

  /// User's mobile in canonical `8801XXXXXXXXX` form, or null if not
  /// yet entered. Lazy-resolves the UID on each call so the store is
  /// safe to call across sign-in / sign-out.
  String? getMobile() {
    final uid = _requireUid();
    if (uid == null) return null;
    return _prefs?.getString(_mobileKey(uid));
  }

  /// The masked subscriberId (`tel:<base64>:robi` shape) — the single
  /// most important piece of state. See class doc for why.
  String? getSubscriberId() {
    final uid = _requireUid();
    if (uid == null) return null;
    final prefs = _prefs;
    if (prefs == null) return null;
    final scoped = prefs.getString(_subscriberIdKey(uid));
    if (scoped != null && scoped.isNotEmpty) return scoped;
    // Legacy unscoped key — migrate on read so the next call hits the
    // scoped slot.
    final legacy = prefs.getString(_legacySubscriberIdKey);
    if (legacy != null && legacy.isNotEmpty) {
      // Fire-and-forget migration. The read itself returns the legacy
      // value; the write happens asynchronously so we don't block the
      // caller's hot path.
      _migrateLegacySubscriberId(uid, legacy);
      return legacy;
    }
    return null;
  }

  /// Cached "currently subscribed" hint. UI-only — authoritative checks
  /// go through `BdappsService.checkStatus`.
  bool getCachedSubscribed() {
    final uid = _requireUid();
    if (uid == null) return false;
    final prefs = _prefs;
    if (prefs == null) return false;
    final scoped = prefs.getBool(_cachedSubKey(uid));
    if (scoped != null) return scoped;
    final legacy = prefs.getBool(_legacyCachedSubKey);
    if (legacy != null) {
      _migrateLegacyCached(uid, legacy);
      return legacy;
    }
    return false;
  }

  // --------------------------------------------------------------- writes

  /// Store the mobile. Caller is responsible for canonicalising to
  /// `8801XXXXXXXXX` before passing in.
  Future<void> setMobile(String mobile) async {
    final uid = _requireUid();
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mobileKey(uid), mobile);
    } catch (e) {
      debugPrint('[BdappsStore] setMobile failed: $e');
    }
  }

  /// Store the masked subscriberId. Writes both SharedPreferences
  /// (primary) and Firestore (backup). The Firestore write is
  /// best-effort — a failure there logs but doesn't fail the call,
  /// because the in-app flow can still proceed using the local copy.
  Future<void> setSubscriberId(String maskedSubscriberId) async {
    final uid = _requireUid();
    if (uid == null) return;
    if (maskedSubscriberId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_subscriberIdKey(uid), maskedSubscriberId);
    } catch (e) {
      debugPrint('[BdappsStore] setSubscriberId (prefs) failed: $e');
    }
    // Best-effort Firestore backup. We don't `await` an outer Future
    // gate on this — losing the backup doesn't lose the primary copy.
    _fireAndForgetFirestoreWrite(_uidToFirestoreDoc(uid).set(
      {firestoreField: maskedSubscriberId},
      SetOptions(merge: true),
    ));
  }

  /// Refresh the cached subscribed flag. The gate's authoritative
  /// check is `checkStatus`; this is the hint used to skip a network
  /// round-trip on warm starts.
  Future<void> setCachedSubscribed(bool value) async {
    final uid = _requireUid();
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cachedSubKey(uid), value);
    } catch (e) {
      debugPrint('[BdappsStore] setCachedSubscribed failed: $e');
    }
  }

  /// Reset everything except the mobile — used after a successful
  /// unsubscribe so a re-subscribe starts from a clean slate. Keeps
  /// the mobile so the user doesn't have to retype it.
  Future<void> clearSubscription() async {
    final uid = _requireUid();
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_subscriberIdKey(uid));
      await prefs.remove(_cachedSubKey(uid));
    } catch (e) {
      debugPrint('[BdappsStore] clearSubscription failed: $e');
    }
    // Clear the Firestore backup too so a reinstall on a new device
    // doesn't rehydrate a now-dead subscriberId.
    _fireAndForgetFirestoreWrite(_uidToFirestoreDoc(uid).set(
      {firestoreField: FieldValue.delete()},
      SetOptions(merge: true),
    ));
  }

  /// Rehydrate the masked subscriberId from the Firestore backup into
  /// SharedPreferences. Called when the local store is empty but the
  /// gate has reason to believe the user is subscribed (e.g. after a
  /// reinstall). Returns the rehydrated value, or null if no backup
  /// exists or the read fails.
  ///
  /// **This is a one-shot call** — the orchestrator should invoke it
  /// at gate-mount time and persist the result via [setSubscriberId].
  Future<String?> rehydrateFromFirestore() async {
    final uid = _requireUid();
    if (uid == null) return null;
    try {
      final snap = await _uidToFirestoreDoc(uid).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final raw = data[firestoreField];
      if (raw is! String || raw.isEmpty) return null;
      // Promote into the local cache so the next read is synchronous.
      await setSubscriberId(raw);
      return raw;
    } catch (e) {
      debugPrint('[BdappsStore] rehydrateFromFirestore failed: $e');
      return null;
    }
  }

  // --------------------------------------------------------------- bindings

  /// Read the Firebase Auth uid of the account that currently owns a
  /// binding for [mobile880] in Firestore. Returns:
  ///   * the owner's uid if a binding exists,
  ///   * `null` if the doc doesn't exist (the mobile is unbound),
  ///   * `null` if the read fails (network / rules / cold-start race)
  ///     so the caller falls back to "unknown" instead of
  ///     misclassifying a real subscriber as free.
  ///
  /// IMPORTANT: this is the *authoritative* server-side check. The
  /// local SharedPreferences subscriberId cache is per-UID and cannot
  /// be used to answer "is THIS mobile bound to someone else?".
  Future<String?> getBindingOwnerUid(String mobile880) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(bindingCollection)
          .doc(bindingDocId(mobile880))
          .get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final owner = data[_bindingOwnerUidField];
      return owner is String && owner.isNotEmpty ? owner : null;
    } catch (e) {
      debugPrint('[BdappsStore] getBindingOwnerUid failed: $e');
      return null;
    }
  }

  /// Atomically claim the binding for [mobile880] on behalf of the
  /// currently signed-in user. Returns:
  ///   * `true` if the binding was created (or already belonged to us
  ///     — auto-claim is supported because Firestore rules let the
  ///     current owner overwrite their own doc under UPDATE).
  ///   * `false` if the binding already exists and is owned by
  ///     somebody else. The verify-time caller should map this to a
  ///     "number already subscribed on another account" UX.
  ///
  /// Implementation notes:
  ///   * Runs inside a Firestore transaction so the read-then-write is
  ///     atomic against other clients racing for the same mobile.
  ///   * On race-loss (the rule denies the create because a parallel
  ///     transaction won), re-reads the doc to disambiguate "owned
  ///     by self" (treat as success — likely a recovery case) vs
  ///     "owned by other" (return false). The rule's atomic-create
  ///     guard (`!exists(...)`) is what protects us here.
  Future<bool> claimBinding({
    required String mobile880,
    required String subscriberId,
  }) async {
    final uid = _requireUid();
    if (uid == null) {
      debugPrint('[BdappsStore] claimBinding: no signed-in user, '
          'treating as failure.');
      return false;
    }
    final docRef = FirebaseFirestore.instance
        .collection(bindingCollection)
        .doc(bindingDocId(mobile880));

    try {
      return await FirebaseFirestore.instance.runTransaction<bool>((
        txn,
      ) async {
        final snap = await txn.get(docRef);
        if (snap.exists) {
          final owner = snap.data()?[_bindingOwnerUidField] as String?;
          if (owner == uid) {
            // Auto-claim: we're already the owner. Refresh the
            // subscriberId + timestamp via an in-transaction update
            // (the rule allows update by the existing owner).
            txn.update(docRef, {
              _bindingSubscriberIdField: subscriberId,
              _bindingMobileField: mobile880,
              _bindingUpdatedAtField: FieldValue.serverTimestamp(),
            });
            return true;
          }
          // Owned by somebody else.
          return false;
        }
        // No binding yet — create it. The rule will reject this if
        // somebody else won the race between our read and our write,
        // in which case the transaction surfaces a
        // `permission-denied` we map to "owned by other" by retrying
        // the read once.
        txn.set(docRef, {
          _bindingOwnerUidField: uid,
          _bindingSubscriberIdField: subscriberId,
          _bindingMobileField: mobile880,
          _bindingUpdatedAtField: FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('[BdappsStore] claimBinding failed: $e');
      // On rule denial (race-loss), the doc now exists for someone
      // (or us). Re-read once to give the caller a definite answer.
      try {
        final owner = await getBindingOwnerUid(mobile880);
        return owner == uid;
      } catch (_) {
        return false;
      }
    }
  }

  /// Drop the binding for [mobile880]. The Firestore rule only
  /// allows delete if `resource.data.ownerUid == request.auth.uid`,
  /// so a wrong-user delete is rejected silently by the server
  /// (the local delete call still "succeeds" client-side because
  /// we don't await the underlying write for ordering reasons; we
  /// just log the failure). Best-effort.
  Future<void> releaseBinding({required String mobile880}) async {
    try {
      await FirebaseFirestore.instance
          .collection(bindingCollection)
          .doc(bindingDocId(mobile880))
          .delete();
    } catch (e) {
      debugPrint('[BdappsStore] releaseBinding failed: $e');
    }
  }

  // --------------------------------------------------------------- helpers

  /// Returns the current UID, or null if no user is signed in. We do
  /// NOT throw — every call site is in a UI flow that should fall back
  /// to "no subscription yet" when the user isn't logged in.
  String? _requireUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      // FirebaseAuth isn't ready yet (cold start before init). Treat as
      // signed-out rather than crashing.
      return null;
    }
  }

  /// Cached SharedPreferences instance. Populated by [warmUp] on app
  /// boot (mirrors `NotificationsPrefsService.load`).
  /// Reads that fire before warmUp complete fall through to null — the
  /// gate's network check will still resolve correctly without a
  /// cached value.
  static SharedPreferences? _prefs;

  /// Called from `main.dart` before first frame so all subsequent
  /// reads are synchronous. Idempotent — safe to call again.
  static Future<void> warmUp() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[BdappsStore] warmUp failed: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _uidToFirestoreDoc(String uid) {
    // Firestore's typed `.doc()` returns a `DocumentReference`
    // (untyped) at this version; the underlying read/write always
    // deals in `Map<String, dynamic>` payloads. The cast through
    // `withConverter` would be more idiomatic but is unnecessary
    // for our two-operation use (one set, one read).
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  /// Fire-and-forget wrapper for a Firestore write that logs failures
  /// but never throws into the caller's hot path.
  void _fireAndForgetFirestoreWrite(Future<void> future) {
    future.catchError((Object e, StackTrace stack) {
      debugPrint('[BdappsStore] Firestore write failed: $e\n$stack');
      return null;
    });
  }

  // --------------------------------------------------------------- migration

  Future<void> _migrateLegacySubscriberId(String uid, String legacy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_subscriberIdKey(uid), legacy);
      await prefs.remove(_legacySubscriberIdKey);
    } catch (e) {
      debugPrint('[BdappsStore] legacy subscriberId migration failed: $e');
    }
  }

  Future<void> _migrateLegacyCached(String uid, bool legacy) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cachedSubKey(uid), legacy);
      await prefs.remove(_legacyCachedSubKey);
    } catch (e) {
      debugPrint('[BdappsStore] legacy cached migration failed: $e');
    }
  }
}
