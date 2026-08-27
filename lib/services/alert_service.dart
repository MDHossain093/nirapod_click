import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/admin_alert.dart';
import '../models/safety_alert.dart';
import 'admin_alert_service.dart';
import 'alert_filter.dart';
import 'checker_repository.dart';

/// SharedPreferences key under which the set of seen alert IDs is
/// persisted. The value is a `List<String>` of [HistoryEntry.checkId]s.
const String _kSeenAlertIdsKey = 'alerts.seen_ids';

/// Cap on the number of seen IDs we keep around. Past this we drop the
/// oldest entries FIFO. Two reasons:
///
///   1. The cap bounds the raw SharedPreferences string size. Auto-IDs are
///      ~20 chars + comma = ~21 bytes; at 1000 entries that's ~21 KB —
///      well under the platform-channel overhead threshold (a few hundred
///      KB starts to measurably slow reads/writes).
///   2. `CheckerRepository.watchRecent(limit: 50)` only returns the most
///      recent 50 scans anyway, so anything older than that can never be
///      "seen again" through this service. Keeping > 1000 is pure waste.
const int _kMaxSeenIds = 1000;

/// How often we poll the `admin_alerts` collection while the app is in
/// the foreground. We don't use a live Firestore listener because the
/// admin publish rate is very low (manual console edits) and a
/// 30-second poll is plenty responsive for "admin posts → users see".
/// 30s also bounds the worst-case stale-display window for the bell
/// badge when the device just came back online.
const Duration _kAdminPollInterval = Duration(seconds: 30);

/// Owns the alert pipeline so the bell badge and the alerts screen share
/// a single Firestore subscription, a single read of the seen-IDs
/// preference, and a single badge-count stream.
///
/// The class is intentionally a process-scoped singleton: the service
/// outlives any single screen and keeps its subscription warm so the
/// badge updates within a second of a new scan appearing in Firestore.
class AlertService {
  AlertService({CheckerRepository? repo})
      : _injectedRepo = repo;

  /// Repo provided by the caller (typically tests). When non-null it's
  /// used as-is — the live auth flow is skipped so test doubles don't
  /// need to mock FirebaseAuth.
  final CheckerRepository? _injectedRepo;

  /// Single source of truth: the live list of *every* recent check,
  /// cached so multiple subscribers don't each open a Firestore listener.
  /// Null until the first emission lands.
  List<HistoryEntry>? _allChecks;

  /// Cached admin-published alerts. Populated by [ensureStarted]'s
  /// background refresh and refreshed on demand via [refreshAdminAlerts].
  List<AdminAlert>? _adminAlerts;

  Stream<List<HistoryEntry>>? _allChecksStream;
  StreamSubscription<List<HistoryEntry>>? _allChecksSub;

  /// Active broadcast streams that downstream widgets listen on.
  final _alertsCtrl = StreamController<List<SafetyAlert>>.broadcast();
  final _badgeCtrl = StreamController<int>.broadcast();

  /// Latest known seen-IDs set. Driven by [_seenIdsSub] below.
  Set<String> _seenIds = const <String>{};

  /// Loaded from SharedPreferences on startup; persisted on every write.
  Set<String>? _seenIdsLoaded;

  StreamSubscription<Set<String>>? _seenIdsSub;

  /// Lazily-opened backing stream of the seen-IDs set in SharedPreferences.
  Future<Set<String>> _loadSeenIds() async {
    if (_seenIdsLoaded != null) return _seenIdsLoaded!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kSeenAlertIdsKey) ?? const [];
      final loaded = raw.toSet();
      _seenIds = loaded;
      _seenIdsLoaded = loaded;
      return loaded;
    } catch (e) {
      // SharedPreferences failure should NEVER prevent the alerts
      // pipeline from starting — fall back to an empty set so the
      // page and bell both render. A prefs hiccup just means every
      // alert will read as "unread" until the next launch.
      debugPrint('[AlertService] Failed to load seen IDs: $e');
      _seenIds = const <String>{};
      _seenIdsLoaded = _seenIds;
      return _seenIds;
    }
  }

  /// Process-scoped singleton — initialized lazily on first access so
  /// `main()` doesn't have to wire it up explicitly. Callers can also
  /// inject their own instance via constructor for tests.
  static AlertService? _instance;
  static AlertService get instance => _instance ??= AlertService();

  /// Long-lived listener on [FirebaseAuth.authStateChanges] so the
  /// service re-arms the scan watcher automatically on sign-in / sign-out.
  StreamSubscription<User?>? _authSub;

  /// UID the current subscription is bound to, or null when no user is
  /// signed in. Used to dedupe `_armForUser` calls so the auth listener
  /// firing right after [ensureStarted] doesn't double-open the stream.
  String? _armedUid;

  /// Background poll timer — refreshes admin alerts every
  /// [_kAdminPollInterval] while the app is alive so admin posts
  /// surface to every user without needing a live Firestore listener
  /// (which would require a composite index we'd rather avoid).
  Timer? _adminPollTimer;

  /// Open the underlying subscription. Idempotent — safe to call from
  /// every screen that needs alerts (bell + page + profile).
  ///
  /// IMPORTANT: this method now does TWO things in parallel:
  ///   1. Install the scan-watcher auth listener (gated on signed-in user).
  ///   2. **Immediately refresh admin alerts AND start a 30-second poll.**
  ///
  /// Step 2 was deliberately decoupled from auth: admin alerts are public
  /// data (`firestore.rules` allows `read: if true`), so every user —
  /// signed in or not — can fetch them. Previously we only triggered
  /// admin alerts inside `_armWithRepo`, which meant a user with no
  /// cached Firebase session (e.g. just landed on LoginPage) saw an
  /// empty bell even if there were admin alerts in Firestore.
  Future<void> ensureStarted() async {
    await _loadSeenIds();

    // Always kick off the admin alerts pipeline — independent of auth.
    // `AdminAlertService.refresh` returns `[]` on any error and is
    // already capped at 4 seconds, so this never blocks `main()`.
    unawaited(_refreshAdminAlertsAndEmit());

    // Start the 30s polling loop. Idempotent — re-starting it on every
    // `ensureStarted` call would create extra timers; guard with null-check.
    _ensureAdminPollingStarted();

    // Tests own their own repo — wire it up directly and skip auth.
    if (_injectedRepo != null) {
      await _armWithRepo('<test>', _injectedRepo);
      return;
    }

    // Production path: install the auth listener (idempotent). The
    // listener synchronously fires with the current cached-session
    // state, so a signed-in user gets armed immediately, and a
    // signed-out user (cold-start with no cached session) just stays
    // unsubscribed until they sign in from LoginPage.
    _ensureAuthListenerInstalled();
  }

  /// Starts (or restarts) the 30s admin-alerts poll loop. Idempotent —
  /// re-calling this is a no-op if a timer is already scheduled.
  void _ensureAdminPollingStarted() {
    if (_adminPollTimer != null) return;
    _adminPollTimer = Timer.periodic(
      _kAdminPollInterval,
      (_) => unawaited(_refreshAdminAlertsAndEmit()),
    );
  }

  void _stopAdminPolling() {
    _adminPollTimer?.cancel();
    _adminPollTimer = null;
  }

  /// Installs the persistent [authStateChanges] listener that keeps
  /// the bell subscription bound to whichever user is currently
  /// signed in. Idempotent — safe to call from every [ensureStarted].
  void _ensureAuthListenerInstalled() {
    if (_authSub != null) return;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        // Sign-out: tear down the per-user subscription. The next
        // sign-in will re-arm through this same listener.
        unawaited(_teardownUserSubscription());
      } else {
        // Sign-in (including the initial cached-session emission at
        // cold start): open the per-user subscription now.
        unawaited(_armForUser(user.uid));
      }
    });
  }

  Future<void> _armForUser(String uid) async {
    if (_armedUid == uid) return; // already armed for this user — dedupe
    await _armWithRepo(uid, CheckerRepository(uid: uid));
  }

  Future<void> _armWithRepo(String uid, CheckerRepository repo) async {
    // Track the user we're now bound to so the auth listener can dedupe.
    _armedUid = uid;
    await _loadSeenIds();

    if (_allChecksSub != null) {
      await _allChecksSub!.cancel();
      _allChecksSub = null;
      _allChecksStream = null;
    }
    _allChecksStream = repo.watchRecent(limit: 50);
    _allChecksSub = _allChecksStream!.listen(_onChecks);
    // Also refresh admin alerts on arm — covers the case where the user
    // just signed in and the initial ensureStarted() refresh happened
    // before any auth was available.
    unawaited(_refreshAdminAlertsAndEmit());
  }

  Future<void> _teardownUserSubscription() async {
    _armedUid = null;
    if (_allChecksSub == null) return;
    await _allChecksSub!.cancel();
    _allChecksSub = null;
    _allChecksStream = null;
    _allChecks = null;
    // Force a re-emit on the next call by invalidating the dedup
    // caches — without this, sign-out's subsequent _emitMergedAlerts
    // would compare the now-empty merged list to the previous
    // user's last emission and skip the broadcast, leaving the bell
    // showing the old user's badge count.
    _lastEmittedAlertsLen = -1;
    _lastEmittedAlertsHead = null;
    _lastEmittedAlertsTail = null;
    _lastEmittedBadgeCount = null;
    // Re-emit an empty list so the bell + alerts page clear out
    // instead of showing stale data from the previous user.
    _emitMergedAlerts();
  }

  /// Public refresh hook — also called from the bell on tap so opening
  /// the bell always shows the freshest data, bypassing any in-flight
  /// poll that might be stale by seconds.
  Future<void> refreshAdminAlerts() async {
    await _refreshAdminAlertsAndEmit();
  }

  /// Refresh + emit in one step. Used by the poll timer, the auth-arm
  /// path, and the public refresh hook.
  Future<void> _refreshAdminAlertsAndEmit() async {
    _adminAlerts = await AdminAlertService.instance.refresh();
    _emitMergedAlerts();
  }

  /// Latest admin-published alerts snapshot.
  List<AdminAlert> get lastAdminAlerts =>
      _adminAlerts ?? const <AdminAlert>[];

  /// All currently-known alerts (scan + admin), with admin alerts
  /// pinned to the top. Newest first within each kind.
  List<SafetyAlert> _buildMergedAlerts() {
    final scanItems = (_allChecks ?? const <HistoryEntry>[])
        .where(isAlert)
        .map((e) => ScanAlert(
              id: e.checkId,
              entry: e,
              createdAt: e.createdAt,
            ))
        .toList();
    final adminItems = (_adminAlerts ?? const <AdminAlert>[])
        .map((a) => AdminAlertItem(
              id: 'admin:${a.id}',
              alert: a,
            ))
        .toList();
    return [...adminItems, ...scanItems];
  }

  /// Last emitted badge count. Used to dedupe identical emissions —
  /// `StreamController.broadcast.add` always notifies subscribers even
  /// for an unchanged value, and an unbounded stream of identical
  /// notifications back into `AlertBadgeBell.setState` can fire
  /// `setState` faster than Flutter can complete a frame, racing the
  /// semantics tree's walk of render-object parent data and
  /// tripping `!semantics.parentDataDirty`. We compare against this
  /// cached value and skip the broadcast when the count hasn't
  /// actually moved.
  int? _lastEmittedBadgeCount;

  /// Last emitted list identity for the alerts stream. Compared by
  /// length + first/last id, which is enough to catch the common
  /// case (the underlying Firestore snapshot re-emitting with the
  /// same 50 docs after a no-op poll) without paying for a deep
  /// equality walk on every emission.
  int _lastEmittedAlertsLen = -1;
  String? _lastEmittedAlertsHead;
  String? _lastEmittedAlertsTail;

  void _emitMergedAlerts() {
    final merged = _buildMergedAlerts();
    final unread = merged.where((a) => !_seenIds.contains(a.id)).length;

    // Dedupe the alerts list: skip the broadcast when the merged set
    // is structurally identical to the last one we sent (same length
    // and same first/last id — cheap proxy for "nothing changed").
    final head = merged.isEmpty ? null : merged.first.id;
    final tail = merged.isEmpty ? null : merged.last.id;
    final alertsChanged =
        merged.length != _lastEmittedAlertsLen ||
        head != _lastEmittedAlertsHead ||
        tail != _lastEmittedAlertsTail;
    if (alertsChanged) {
      _lastEmittedAlertsLen = merged.length;
      _lastEmittedAlertsHead = head;
      _lastEmittedAlertsTail = tail;
      if (!_alertsCtrl.isClosed) _alertsCtrl.add(merged);
    }

    // Dedupe the badge count: identical unread counts are a no-op for
    // every known subscriber. Skipping the broadcast here is what
    // stops the parent-data-dirty flood when multiple internal paths
    // (Firestore snapshot + 30s poll + admin refresh) race each
    // other on the same frame.
    if (unread != _lastEmittedBadgeCount) {
      _lastEmittedBadgeCount = unread;
      if (!_badgeCtrl.isClosed) _badgeCtrl.add(unread);
    }
  }

  void _onChecks(List<HistoryEntry> checks) {
    _allChecks = checks;
    _emitMergedAlerts();
  }

  /// All currently-known alerts (scan + admin), newest first. Admin
  /// alerts are pinned to the top. Empty list = nothing urgent.
  Stream<List<SafetyAlert>> watchAlerts() {
    ensureStarted();
    return _alertsCtrl.stream;
  }

  /// Current unread alert count, derived as
  /// `(alerts - seenIds).length`. Updates on every Firestore emission
  /// AND every seen-IDs write.
  Stream<int> watchBadgeCount() {
    ensureStarted();
    return _badgeCtrl.stream;
  }

  /// Synchronous snapshot for callers that want the last value (e.g. the
  /// alerts screen on first frame, to render without a spinner).
  List<SafetyAlert> get lastAlerts => _buildMergedAlerts();

  /// Synchronous snapshot of the badge count.
  int get lastBadgeCount {
    final alerts = lastAlerts;
    return alerts.where((e) => !_seenIds.contains(e.id)).length;
  }

  /// Mark these alert IDs as seen, persist the set (FIFO-capped), and
  /// re-emit the badge count. Called from the alerts screen on open and
  /// from any other entry point that wants to dismiss badges.
  Future<void> markSeen(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await _loadSeenIds();
    final next = <String>{..._seenIds, ...ids};
    if (next.length > _kMaxSeenIds) {
      final ordered = next.toList();
      _seenIds = ordered.sublist(ordered.length - _kMaxSeenIds).toSet();
    } else {
      _seenIds = next;
    }
    await _persistSeenIds();
    _emitMergedAlerts();
  }

  /// Wipe the seen-IDs set. Called from "Clear history" so the badge
  /// doesn't ghost-stale after every check doc is deleted.
  Future<void> clearSeen() async {
    _seenIds = const <String>{};
    await _persistSeenIds();
    _emitMergedAlerts();
  }

  Future<void> _persistSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSeenAlertIdsKey, _seenIds.toList());
  }

  /// Cancel the Firestore subscription, stop the poll timer, and close
  /// the broadcast controllers. For app-lifetime singletons this is
  /// usually fine to skip (the OS reclaims everything on app exit).
  Future<void> dispose() async {
    _stopAdminPolling();
    await _allChecksSub?.cancel();
    _allChecksSub = null;
    await _seenIdsSub?.cancel();
    _seenIdsSub = null;
    await _alertsCtrl.close();
    await _badgeCtrl.close();
  }
}
