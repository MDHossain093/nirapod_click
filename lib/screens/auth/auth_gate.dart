import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../main/main_screen.dart';
import '../splash/splash_page.dart';
import 'login_page.dart';

/// Listens to Firebase auth state and routes between [LoginPage] and
/// [MainScreen].
///
/// Two signals gate the transition out of the splash:
///   1. Firebase auth state has emitted (`snapshot.hasData` or our cached
///      [_user] from `initState`).
///   2. The splash itself has held for its minimum display duration.
///
/// We require **both** because the splash needs to be visible long
/// enough to register (otherwise it's a 100ms flash on warm starts),
/// but we must not hand off to the destination screen until Firebase
/// has actually told us who's signed in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  User? _user;

  /// Set to true once [SplashPage.onReady] fires (its 1.5s minimum
  /// display timer has elapsed). Until then we stay on the splash even
  /// if Firebase has already resolved the user.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    // Snapshot whatever Firebase already knows about the signed-in user.
    // On a warm start this resolves synchronously to the cached user
    // (or null) and we can skip the splash as soon as its min-duration
    // timer fires.
    _user = _auth.currentUser;
  }

  void _onSplashReady() {
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        // Prefer the stream's latest value (it supersedes any cached
        // currentUser we read in initState once it emits).
        final user = snapshot.hasData ? snapshot.data : _user;

        final authResolved =
            snapshot.connectionState != ConnectionState.waiting || user != null;

        // Stay on the splash until BOTH signals are ready.
        if (!_splashDone || !authResolved) {
          return SplashPage(onReady: _onSplashReady);
        }

        if (user == null) return const LoginPage();
        return const MainScreen();
      },
    );
  }
}


