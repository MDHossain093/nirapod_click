import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';

/// Branded splash screen shown at app launch.
///
/// Two responsibilities:
///   1. **Brand the launch** — logo + tagline on the 2-stop
///      [AppTheme.headerGradient] (primary → secondary) so the user
///      always sees an intentional screen instead of a blank frame
///      while Firebase rehydrates. The 3-stop `brandHeaderGradient`
///      is reserved for the login / signup mobile heroes where the
///      wider color band reads better on a tall card.
///   2. **Hold the screen for at least [minDisplayDuration]** — without a
///      floor the splash flashes for ~200ms on warm starts and the user
///      never registers it. 1.5s is enough to read as "the splash screen"
///      but short enough not to feel sluggish.
///
/// Once **both** the minimum duration has elapsed AND [onReady] has been
/// invoked by the parent (i.e. Firebase auth state has resolved), this
/// widget is no longer needed and the parent navigates to LoginPage or
/// MainScreen.
///
/// Layout:
///   ┌──────────────────────────┐
///   │                          │
///   │         🛡 logo           │  (fade + scale-in)
///   │                          │
///   │     Stay safe online      │  (fade-in)
///   │      (Bangla alt)         │
///   │                          │
///   │          ◔               │  (spinner, fade-in)
///   │                          │
///   └──────────────────────────┘
class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.onReady,
    this.minDisplayDuration = const Duration(milliseconds: 1500),
  });

  /// Called once the splash is ready to hand off. The parent (typically
  /// [AuthGate]) is responsible for actually swapping to LoginPage or
  /// MainScreen; this widget just signals that it is done displaying.
  final VoidCallback onReady;

  /// Minimum time the splash stays visible. 1500ms is the default —
  /// short enough to feel snappy, long enough to register.
  final Duration minDisplayDuration;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  // Three sequentially-revealed layers. Each starts hidden (opacity 0 /
  // scale 0.92) and animates to its rest state. Driving them with
  // [AnimationController]s keeps the splash cheap and lets us cancel
  // cleanly on dispose.
  late final AnimationController _logoCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _spinnerCtrl;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _spinnerOpacity;

  Timer? _minDurationTimer;
  bool _signaledReady = false;

  @override
  void initState() {
    super.initState();

    // Logo: 600ms fade + scale, ease-out. Starts immediately on mount.
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );

    // Tagline: 400ms fade-in, starts 200ms after the logo so the eye
    // lands on the mark first, then reads the wordmark.
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _taglineOpacity = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut);

    // Spinner: 300ms fade-in, last so the spinner appears just before
    // the splash hands off.
    _spinnerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _spinnerOpacity = CurvedAnimation(parent: _spinnerCtrl, curve: Curves.easeOut);

    // Kick off the entrance choreography on the next frame so the
    // initial layout (gradient + logo asset) is in place first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _logoCtrl.forward();
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _taglineCtrl.forward();
      });
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _spinnerCtrl.forward();
      });
    });

    // Hold the splash for at least [widget.minDisplayDuration] regardless
    // of how fast Firebase rehydrates.
    _minDurationTimer = Timer(widget.minDisplayDuration, _signalReady);
  }

  /// Idempotent — safe to call from both the timer and the parent.
  void _signalReady() {
    if (_signaledReady) return;
    _signaledReady = true;
    widget.onReady();
  }

  @override
  void dispose() {
    _minDurationTimer?.cancel();
    _logoCtrl.dispose();
    _taglineCtrl.dispose();
    _spinnerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.headerGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo block: fades + scales in over 600ms.
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/logo_full.png',
                      height: 140,
                      fit: BoxFit.contain,
                      // Fallback to the shield mark if the asset isn't
                      // bundled (e.g. running on a desktop flavor that
                      // doesn't ship it). Keeps the splash usable.
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.shield_outlined,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Tagline block: fades in 200ms after the logo.
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t('app.tagline'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 36,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Spinner: fades in last so it appears just before the
                // hand-off. White stroke against the dark gradient.
                FadeTransition(
                  opacity: _spinnerOpacity,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}