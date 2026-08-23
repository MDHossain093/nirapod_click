import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../main/main_screen.dart';
import 'login_page.dart';

/// Listens to Firebase auth state and routes between [LoginPage] and
/// [MainScreen].
///
/// During the first frame we don't yet know who (if anyone) is signed in:
/// Firebase has to rehydrate its cached session from disk. We show a
/// branded splash instead of a plain spinner so the user never sees a
/// half-loaded UI or a flash of LoginPage before MainScreen.
///
/// We also poll [_auth].currentUser directly so the splash can't get
/// stuck if the auth-state stream fails to emit (e.g. a misconfigured
/// native plugin on Windows). Once either signal arrives we render the
/// appropriate screen and stop polling.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();
  User? _user;

  @override
  void initState() {
    super.initState();
    // Snapshot whatever Firebase already knows about the signed-in user.
    // On a warm start this resolves synchronously to the cached user
    // (or null) and we can skip the splash entirely.
    _user = _auth.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        // Prefer the stream's latest value (it supersedes any cached
        // currentUser we read in initState once it emits).
        final user = snapshot.hasData ? snapshot.data : _user;
        if (snapshot.connectionState == ConnectionState.waiting &&
            user == null) {
          return const _SplashScreen();
        }
        if (user == null) return const LoginPage();
        return const MainScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandHeaderGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Real logo if the asset is bundled; otherwise fall back to
              // the Flutter-drawn shield mark.
              Image.asset(
                'assets/logo_full.png',
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}