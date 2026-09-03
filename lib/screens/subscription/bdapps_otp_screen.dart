import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/app_locale.dart';
import '../../core/subscription/bdapps_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_helpers.dart';
import '../../services/bdapps_subscription_service.dart';
import 'bdapps_gradient_cta.dart';

/// Step 2 of the BDApps carrier-billed flow: enter the OTP the user
/// received by SMS.
///
/// **Behaviour:**
///   * 6 numeric boxes (one char each). Auto-submits when all six
///     are filled.
///   * "Resend code" link calls `sendOtp` again on the same mobile.
///   * On verify success: pops back to the Profile screen with a
///     snackbar ("You're subscribed") and the masked subscriberId
///     already persisted by the orchestrator.
///   * On verify failure: shakes + clears the input + shows an
///     [AuthErrorBanner].
///
/// **Why we don't auto-read SMS:** the workflow doc notes the
/// webhook can be unreliable. We treat the Verify response as
/// authoritative, not the webhook. Auto-reading SMS via the SMS
/// Retriever API is a future enhancement.
class BdappsOtpScreen extends StatefulWidget {
  const BdappsOtpScreen({super.key, required this.mobile880});

  /// Canonical `8801XXXXXXXXX` form. Passed by [BdappsMobileScreen]
  /// so the OTP header can echo "Sent to {mobile}" without
  /// re-normalising.
  final String mobile880;

  @override
  State<BdappsOtpScreen> createState() => _BdappsOtpScreenState();
}

class _BdappsOtpScreenState extends State<BdappsOtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;

  final _otpCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _busy = false;
  String? _error;
  bool _shake = false;

  late final AnimationController _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Auto-focus the OTP field on mount so the user can paste/type
    // immediately — same UX as auth OTP screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _focusNode.dispose();
    _shakeAnim.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != _otpLength) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = BdappsSubscriptionScope.of(context);
    final outcome = await service.verifyOtp(otp: otp);
    if (!mounted) return;
    if (outcome is BdappsVerifyOtpOutcomeOk) {
      // Pop back to the entry screen; the gate will re-resolve on the
      // next open and the Profile card can now refresh.
      Navigator.of(context).pop();
      return;
    }
    if (outcome is BdappsVerifyOtpOutcomeNumberOwnedByOther) {
      // Server-side binding denied: this mobile belongs to a
      // different NirapodClick account. The verify itself was valid
      // (and BDApps would happily register the user), but our
      // single-number-per-user rule forbids it. Show the localized
      // reason in a banner, shake to draw attention, and route the
      // user back to the mobile entry so they can try a different
      // number or sign in to the owning account.
      await _triggerShake();
      if (!mounted) return;
      final t = AppLocaleScope.of(context).tr;
      setState(() => _error = t('subscription.numberOwnedByOther'));
      // Don't auto-pop: the user needs to read the message and tap
      // back themselves. The status card / manage sheet path is the
      // right next step, but we don't know if it's reachable here.
    } else if (outcome is BdappsVerifyOtpOutcomeFailed) {
      await _triggerShake();
      if (!mounted) return;
      _otpCtrl.clear();
      setState(() => _error = outcome.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = BdappsSubscriptionScope.of(context);
    final outcome = await service.sendOtp(mobile880: widget.mobile880);
    if (!mounted) return;
    if (outcome is BdappsSendOtpOutcomeOk) {
      _otpCtrl.clear();
      _focusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resendSentSnackbar())),
      );
    } else if (outcome is BdappsSendOtpOutcomeAlreadySubscribed) {
      // Edge case: between Send and Resend the user was registered
      // (e.g. by a sibling flow). Pop back; the gate will resolve.
      Navigator.of(context).pop();
      return;
    } else if (outcome is BdappsSendOtpOutcomeFailed) {
      setState(() => _error = outcome.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  String _resendSentSnackbar() {
    final t = AppLocaleScope.of(context).tr;
    final template = t('subscription.otpSubtitle');
    final display = '0${widget.mobile880.substring(3)}';
    return template.replaceAll('{mobile}', display);
  }

  Future<void> _triggerShake() async {
    setState(() => _shake = true);
    _shakeAnim
      ..reset()
      ..forward();
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (mounted) setState(() => _shake = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final mobileDisplay = '0${widget.mobile880.substring(3)}';
    final subtitleTemplate = t('subscription.otpSubtitle');
    final subtitle = subtitleTemplate.replaceAll('{mobile}', mobileDisplay);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('subscription.otpTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Hero — lock + title.
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  size: 32,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t('subscription.otpTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              // OTP input — one visible field with maxLength=6 + a
              // shake-on-error decoration via [AnimatedBuilder].
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  // Translate X based on a triangle wave over [0, 1].
                  final t = _shakeAnim.value;
                  final dx = t == 0
                      ? 0.0
                      : 8 *
                          (1 - t) *
                          (t < 0.5
                              ? (t * 2)
                              : ((1 - t) * 2));
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: TextField(
                  controller: _otpCtrl,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: _otpLength,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 12,
                    color: AppTheme.textPrimary,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: BorderSide(
                        color: _shake
                            ? AppTheme.riskCritical.withValues(alpha: 0.5)
                            : AppTheme.borderSubtle,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: BorderSide(
                        color: _shake
                            ? AppTheme.riskCritical
                            : AppTheme.secondary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (s) {
                    // Auto-submit on full OTP.
                    if (s.length == _otpLength && !_busy) _verify();
                  },
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _resend,
                child: Text(t('subscription.resend')),
              ),
              const Spacer(),
              BdappsGradientCta(
                label: t('subscription.verify'),
                onPressed: _busy ? null : _verify,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}