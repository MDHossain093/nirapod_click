import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_helpers.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/google_g_icon.dart';
import '../../services/auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // Lazy so the State can be constructed even before Firebase is
  // initialized (e.g., on first frame after splash, or in widget tests
  // that don't initialize Firebase). The auth service is only created
  // when the user actually submits.
  AuthService get _auth => AuthService();
  bool _busy = false;
  bool _googleBusy = false;
  bool _obscure = true; // password visibility toggle state
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Submit handlers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signInWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      // AuthGate listens to authStateChanges() — no manual navigation.
    } catch (e) {
      setState(() => _error = AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
      // Sign-in may return null if the user closed the picker — silent no-op.
    } catch (e) {
      setState(() => _error = AuthService.describeError(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      mobileHeader: const _LoginMobileHero(),
      formPanel: _LoginForm(
        formKey: _formKey,
        emailCtrl: _emailCtrl,
        passCtrl: _passCtrl,
        busy: _busy,
        googleBusy: _googleBusy,
        obscure: _obscure,
        error: _error,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onSubmitEmail: _submitEmail,
        onSubmitGoogle: _submitGoogle,
      ),
    );
  }
}

// ─── Mobile hero ───────────────────────────────────────────────────────────────

/// Compact gradient header shown only on narrow screens. The wide
/// layout uses `AuthBrandPanel` instead — it carries the same brand
/// mark but with a longer headline + feature list.
class _LoginMobileHero extends StatelessWidget {
  const _LoginMobileHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandHeaderGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: const [
          Icon(Icons.shield_outlined, size: 36, color: Colors.white),
          SizedBox(height: 10),
          Text(
            'NirapodClick',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'ক্লিক করার আগে যাচাই করুন।',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form (shared between layouts) ─────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.busy,
    required this.googleBusy,
    required this.obscure,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmitEmail,
    required this.onSubmitGoogle,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool busy;
  final bool googleBusy;
  final bool obscure;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmitEmail;
  final VoidCallback onSubmitGoogle;

  @override
  Widget build(BuildContext context) {
    final anyBusy = busy || googleBusy;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section title above the form (only visible on wide layout
          // where the brand panel supplies the marketing context).
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < AuthScaffold.wideBreakpoint) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Login to your account',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              );
            },
          ),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enabled: !anyBusy,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primary),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passCtrl,
            obscureText: obscure,
            enabled: !anyBusy,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppTheme.primary),
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: anyBusy ? null : onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: anyBusy
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            'Forgot password is coming soon.',
                          ),
                        ),
                      );
                    },
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 8),
          // Brand-gradient primary CTA — same `primary → secondary`
          // gradient used by the in-app AppBar / Subscription card /
          // Home "Go Premium" banner. Wrapping the ElevatedButton in a
          // Container with BoxDecoration(gradient: …) lets the gradient
          // show through (the button itself is transparent so its
          // own backgroundColor / foregroundColor never overrides it).
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: ElevatedButton(
              onPressed: anyBusy ? null : onSubmitEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: Colors.white70,
                // Inherit the full-width + height from the theme but
                // strip the theme's own backgroundColor/foregroundColor
                // overrides so the gradient + white text show through.
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Login'),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(message: error!),
          ],
          const SizedBox(height: 24),
          const AuthOrDivider(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: anyBusy ? null : onSubmitGoogle,
            icon: googleBusy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const GoogleGIcon(size: 18),
            label: const Text('Continue with Google'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.borderSubtle, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Localized Bangla strings can run ~200 dp wide; on a
              // 320 dp phone with default padding the row overflows.
              // Flexible + ellipsis keeps both pieces on one line.
              Flexible(
                child: const Text(
                  "Don't have an account? ",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: anyBusy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignUpPage(),
                          ),
                        ),
                child: const Text('Create an account'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const AuthTrustFooter(),
        ],
      ),
    );
  }
}