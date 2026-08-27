import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_helpers.dart';
import '../../core/widgets/auth_scaffold.dart';
import '../../core/widgets/google_g_icon.dart';
import '../../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  // Lazy — see login_page.dart for why we don't initialize eagerly.
  AuthService get _auth => AuthService();
  bool _busy = false;
  bool _googleBusy = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
      await _auth.registerWithEmail(
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
      mobileHeader: const _SignUpMobileHeader(),
      formPanel: _SignUpForm(
        formKey: _formKey,
        nameCtrl: _nameCtrl,
        emailCtrl: _emailCtrl,
        passCtrl: _passCtrl,
        confirmCtrl: _confirmCtrl,
        busy: _busy,
        googleBusy: _googleBusy,
        obscurePass: _obscurePass,
        obscureConfirm: _obscureConfirm,
        error: _error,
        onTogglePass: () => setState(() => _obscurePass = !_obscurePass),
        onToggleConfirm: () =>
            setState(() => _obscureConfirm = !_obscureConfirm),
        onSubmitEmail: _submitEmail,
        onSubmitGoogle: _submitGoogle,
      ),
    );
  }
}

// ─── Mobile header (AppBar-style) ──────────────────────────────────────────────

/// Narrow-screen header: a gradient AppBar with a back arrow and the
/// "Create Account" title. The wide layout skips this and uses
/// `AuthBrandPanel` instead.
class _SignUpMobileHeader extends StatelessWidget {
  const _SignUpMobileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandHeaderGradient),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const Text(
              'Create Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Form (shared between layouts) ─────────────────────────────────────────────

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.busy,
    required this.googleBusy,
    required this.obscurePass,
    required this.obscureConfirm,
    required this.error,
    required this.onTogglePass,
    required this.onToggleConfirm,
    required this.onSubmitEmail,
    required this.onSubmitGoogle,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final bool busy;
  final bool googleBusy;
  final bool obscurePass;
  final bool obscureConfirm;
  final String? error;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;
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
          // Wide-layout title above the first field.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < AuthScaffold.wideBreakpoint) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Join NirapodClick to start checking messages safely.',
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
            controller: nameCtrl,
            enabled: !anyBusy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 2) return 'Enter your full name';
              return null;
            },
          ),
          const SizedBox(height: 16),
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
            obscureText: obscurePass,
            enabled: !anyBusy,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppTheme.primary),
              suffixIcon: IconButton(
                tooltip: obscurePass ? 'Show password' : 'Hide password',
                onPressed: anyBusy ? null : onTogglePass,
                icon: Icon(
                  obscurePass
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
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmCtrl,
            obscureText: obscureConfirm,
            enabled: !anyBusy,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppTheme.primary),
              suffixIcon: IconButton(
                tooltip: obscureConfirm ? 'Show password' : 'Hide password',
                onPressed: anyBusy ? null : onToggleConfirm,
                icon: Icon(
                  obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            validator: (v) {
              if (v != passCtrl.text) return "Passwords don't match";
              return null;
            },
          ),
          const SizedBox(height: 24),
          // Brand-gradient primary CTA — same `primary → secondary`
          // gradient used by the in-app AppBar / Subscription card /
          // Home "Go Premium" banner. See login_page.dart for the
          // wrapping pattern (transparent button + gradient container).
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
                  : const Text('Create Account'),
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
              // See login_page.dart — same overflow guard for the
              // localized Bangla copy.
              Flexible(
                child: const Text(
                  'Already have an account? ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: anyBusy ? null : () => Navigator.of(context).pop(),
                child: const Text('Login'),
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