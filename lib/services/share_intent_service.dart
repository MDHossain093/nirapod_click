import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:share_handler/share_handler.dart';

/// Singleton wrapper around the `share_handler` plugin's
/// [ShareHandler] API.
///
/// The plugin gives us two channels for receiving Android ACTION_SEND
/// shares:
///
///   1. **Cold start** — the app was closed when the user picked
///      NirapodClick in the system share sheet. The intent is
///      delivered to MainActivity, which the plugin captures and
///      stores in memory until something calls
///      `getInitialSharedMedia()`.
///   2. **Warm start** — the app was already running. The plugin
///      re-broadcasts the new intent through its event channel,
///      exposed as [ShareHandler.sharedMediaStream].
///
/// Both paths funnel through the same [_pendingText] queue, which
/// the router (`MainScreen`) drains via [takePendingText].
/// [ChangeNotifier.notifyListeners] fires on every enqueue so the
/// router's listener can react to warm-start shares without waiting
/// for the next rebuild to happen by chance.
///
/// **Scope**: This implementation only handles `text/plain` MIME.
/// Image / file shares are silently dropped — the spec is explicit
/// about text-only support and the plugin's `SharedAttachment`
/// surface for binary content is a much larger contract that we
/// don't need.
///
/// **Auth gating**: The service itself does NOT decide whether to
/// route the share — that's `MainScreen`'s job. If the user is
/// signed out when a share arrives, the share is dropped (the auth
/// flow shows the login page first; the security model requires
/// that unauthenticated users never see scan history). The share
/// text is not cached across sign-out → sign-in transitions; the
/// router checks auth state at the moment it pops the queue.
class ShareIntentService extends ChangeNotifier {
  ShareIntentService._();

  /// Module-level singleton — same posture as
  /// [SubscriptionService.instance] / [AlertService.instance].
  /// `main.dart` calls [start] once before `runApp`, and `MainScreen`
  /// reads via `ShareIntentService.instance`.
  static final ShareIntentService instance = ShareIntentService._();

  /// Underlying plugin handle. `ShareHandler.instance` returns the
  /// federated `ShareHandlerPlatform.instance`, which is what
  /// `share_handler_android` registers against on Android. The static
  /// `ShareHandler` class is just a thin wrapper exposing that getter
  /// — the actual instance is a `ShareHandlerPlatform`.
  final ShareHandlerPlatform _handler = ShareHandler.instance;

  /// Subscription on the warm-start event channel.
  StreamSubscription<SharedMedia>? _streamSub;

  /// Pending shares awaiting the router. Most-recent-wins semantics:
  /// if the user fires two shares in quick succession before the
  /// router drains the queue, only the most recent is delivered.
  /// The earlier share is effectively overwritten — matches the
  /// user's expectation that the most recent share is what they
  /// want to check.
  String? _pendingText;

  /// Guard flag for [start]. `start` is idempotent so we can call it
  /// from `main.dart` without worrying about double-subscription.
  bool _started = false;

  /// Initialize the service. Must be called once before `runApp`,
  /// AFTER `WidgetsFlutterBinding.ensureInitialized()`. Subsequent
  /// calls are no-ops.
  ///
  /// Two things happen here:
  ///   1. The cold-start share (if any) is read off the plugin and
  ///      pushed into [_pendingText]. The plugin stores it as a
  ///      one-shot — see [resetInitialSharedMedia] below for the
  ///      re-arm.
  ///   2. The warm-start event channel is subscribed; every emission
  ///      flows through the same [_onSharedMedia] handler, which
  ///      calls [notifyListeners] so the router can react
  ///      immediately rather than waiting for the next rebuild.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      // Cold-start share. The plugin returns null when the app was
      // launched normally (no share intent). Any exception (e.g.
      // platform channel not yet wired) is swallowed so a broken
      // share channel can't block app launch.
      final initial = await _handler.getInitialSharedMedia();
      if (initial != null) {
        _onSharedMedia(initial);
        // Wipe the plugin's stored one-shot so the same share isn't
        // re-delivered if `getInitialSharedMedia` is called again
        // (e.g. after a hot restart, or by a future caller). The
        // queue inside this service is now the source of truth.
        await _handler.resetInitialSharedMedia();
      }
    } catch (_) {
      // ignored — see comment above.
    }

    // Warm-start stream. `sharedMediaStream` emits the latest
    // SharedMedia each time the user shares into a running app.
    _streamSub = _handler.sharedMediaStream.listen(
      _onSharedMedia,
      // Errors on the platform channel (e.g. native side crashes)
      // must not tear down the subscription; we just swallow.
      onError: (_) {
        // ignored
      },
    );
  }

  /// Common path for cold-start and warm-start shares. Filters to
  /// text/plain, trims, and stores if non-empty. Non-text shares
  /// are dropped silently (per spec — we don't show a UI for them).
  /// Notifies listeners so the router can react.
  void _onSharedMedia(SharedMedia media) {
    final raw = media.content;
    if (raw == null) return;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    _pendingText = trimmed;
    notifyListeners();
  }

  /// Pop the next pending shared text (or null if the queue is
  /// empty). The router calls this from its post-frame callback so
  /// the share is delivered exactly once.
  String? takePendingText() {
    final t = _pendingText;
    _pendingText = null;
    return t;
  }

  /// Test / debug hook — peek without consuming.
  String? peekPendingText() => _pendingText;

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}
