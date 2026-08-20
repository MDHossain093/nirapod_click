import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';

/// Default Google **Web client ID** for the `nirapodclick` Firebase
/// project. Source: `android/app/google-services.json` →
/// `oauth_client[].client_type == 3`.
///
/// This is what `GoogleSignIn(serverClientId: ...)` must receive so the
/// issued ID token has an `aud` claim that Firebase Auth accepts. Using
/// a `client_type == 2` (iOS) or `client_type == 1` (Android) client ID
/// here causes `FirebaseAuthException(audience-mismatch)`.
///
/// Override at build time with
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` for staging/prod.
const String _defaultGoogleWebClientId =
    '70465752929-7b4pglo57g9bmfd21nhoft8nkauegj37.apps.googleusercontent.com';

/// Thin wrapper around [FirebaseAuth] (email/password) and
/// [GoogleSignIn] (Google account picker). Screens depend on this service
/// instead of Firebase directly so:
///   * mocking in tests is straightforward (drop in a fake AuthService),
///   * error messages stay in one place (see [describeError]),
///   * swapping providers later doesn't ripple through every screen.
///
/// The Google Web client ID (serverClientId) is read from the
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` build flag so different
/// build flavours (dev / prod) can target different Firebase projects
/// without code changes. To find it: Firebase Console → Project settings
/// → General → Your apps → Android app → "Web client ID". Pass it on the
/// command line, e.g.:
///   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? google,
    String? googleWebClientId,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _google = google ??
            GoogleSignIn(
              // serverClientId is REQUIRED for Firebase Auth integration —
              // without it Firebase rejects the credential with
              // `audience-mismatch`. It can be overridden in tests.
              serverClientId: googleWebClientId ??
                  const String.fromEnvironment(
                    'GOOGLE_WEB_CLIENT_ID',
                    defaultValue: _defaultGoogleWebClientId,
                  ),
            );

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// Stream of auth state changes (used by `AuthGate` for persistent login).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Currently signed-in user, or `null` if nobody is.
  User? get currentUser => _auth.currentUser;

  /// Register a brand new account with email + password.
  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in an existing user with email + password.
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Trigger the Google account picker, then exchange the resulting ID token
  /// for a Firebase credential. Returns `null` if the user dismisses the
  /// picker (that's a silent no-op — we don't want to error on cancel).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // google_sign_in 6.x: signIn() resolves to null on cancel already.
      final GoogleSignInAccount? account = await _google.signIn();
      if (account == null) return null; // user closed the picker

      // Exchange Google ID token for a Firebase credential. We require
      // serverClientId (the Web client ID from google-services.json) so the
      // ID token is issued for our Firebase project; without it Firebase
      // rejects the sign-in with `audience-mismatch`.
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-id-token',
          message: 'Google sign-in did not return an ID token.',
        );
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e, st) {
      // Surface the real error code in the console so we can see *why*
      // Firebase rejected us (audience-mismatch, network-failed, etc.).
      // The UI still shows the friendly message via describeError().
      // ignore: avoid_print
      debugPrint('AuthService.signInWithGoogle failed: $e');
      // ignore: avoid_print
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Sign out from both Firebase Auth and the Google account so the next
  /// `signInWithGoogle()` shows the picker again instead of silently reusing
  /// the previous Google account.
  Future<void> signOut() async {
    await Future.wait<void>([
      _auth.signOut(),
      _google.signOut(),
    ]);
  }

  /// Human-friendly error string for any auth exception. UI shows it as a
  /// SnackBar / inline error. Unmapped codes include the raw code so we
  /// can diagnose issues (audience-mismatch, INVALID_PROVIDER_ID, etc.)
  /// without rebuilding the whole app.
  static String describeError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'That email is already registered. Try signing in.';
        case 'invalid-email':
          return 'That email looks invalid.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'too-many-requests':
          return 'Too many attempts. Try again in a moment.';
        case 'network-request-failed':
          return 'Network error. Check your connection.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using a different sign-in method.';
        case 'missing-id-token':
          return 'Google sign-in failed. Please try again.';
        case 'audience-mismatch':
          return 'Google sign-in failed (audience-mismatch). The Web client ID passed to GoogleSignIn does not match this Firebase project. Re-download google-services.json and rebuild.';
        case 'invalid-api-key':
        case 'invalid-app-credential':
        case 'invalid-user-token':
          return 'Authentication is misconfigured. Re-download google-services.json and rebuild.';
        case 'provider-already-linked':
          return 'This account is already linked.';
        case 'credential-already-in-use':
          return 'That credential is already linked to another account.';
        case 'operation-not-allowed':
          return 'Sign-in with Google is not enabled in the Firebase Console. Enable it under Authentication → Sign-in method.';
        case 'user-disabled':
          return 'This account has been disabled.';
      }
      // Unmapped FirebaseAuthException — surface the code so we can fix
      // the mapping without rebuilding.
      return 'Sign-in failed (${e.code}). Please try again.';
    }
    // google_sign_in 6.x throws PlatformException, not a typed exception.
    // Surface the platform error code so we can diagnose Google-side
    // failures (e.g. sign_in_canceled, network_error, sign_in_failed).
    if (e is PlatformException) {
      return 'Google sign-in failed (${e.code}). Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}