import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/app_locale.dart';
import '../../core/subscription/bdapps_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/auth_helpers.dart';
import '../../services/bdapps_subscription_service.dart';
import 'bdapps_gradient_cta.dart';
import 'bdapps_otp_screen.dart';

/// Step 1 of the BDApps carrier-billed flow: collect the user's mobile
/// and kick off the OTP request.
///
/// **Behaviour:**
///   * Validates a Bangladesh 11-digit mobile (`01XXXXXXXXX`).
///   * Normalises to `8801XXXXXXXXX` before submitting.
///   * On `S1000`: navigates to [BdappsOtpScreen] with the mobile.
///   * On `E1351` / `E1331` (already registered): shows a brief
///     "You're already subscribed" snack and pops back (the gate will
///     re-resolve status on next entry).
///   * On any other failure: shows an [AuthErrorBanner] + keeps the
///     user on this screen for retry.
class BdappsMobileScreen extends StatefulWidget {
  const BdappsMobileScreen({super.key});

  @override
  State<BdappsMobileScreen> createState() => _BdappsMobileScreenState();
}

class _BdappsMobileScreenState extends State<BdappsMobileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Whether to render the "already-subscribed" full-screen state.
  /// When true, the form is hidden and a back button is offered so
  /// the user can leave after reading the toast. This branch is hit
  /// only on the `E1351` short-circuit — the gate normally catches
  /// already-subscribed users before they reach this screen.
  bool _alreadySubscribed = false;

  /// Guards [_prefillFromStore] so we only run the inherited-widget
  /// lookup once. [didChangeDependencies] can fire multiple times if
  /// an ancestor rebuilds with a different InheritedWidget; pre-filling
  /// each time would clobber the user's edits.
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill from the store if a mobile is already known — saves the
    // user a keystroke if they re-enter the flow after a previous
    // verify failed. Must run here, NOT in initState, because
    // [BdappsSubscriptionScope.of] calls
    // `dependOnInheritedWidgetOfExactType`, which is forbidden during
    // initState.
    if (_prefilled) return;
    _prefilled = true;
    final service = BdappsSubscriptionScope.of(context);
    final stored = service.store.getMobile();
    if (stored != null && stored.length >= 13) {
      // 8801XXXXXXXXX → 01XXXXXXXXX for display.
      _mobileCtrl.text = '0${stored.substring(3)}';
    }
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = BdappsSubscriptionScope.of(context);
    final display = _mobileCtrl.text.trim();
    final mobile880 = _to880(display);
    final outcome = await service.sendOtp(mobile880: mobile880);
    if (!mounted) return;
    if (outcome is BdappsSendOtpOutcomeOk) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BdappsOtpScreen(mobile880: mobile880),
        ),
      );
      return;
    }
    if (outcome is BdappsSendOtpOutcomeAlreadySubscribed) {
      setState(() => _alreadySubscribed = true);
      // Brief delay so the user can read the state before we pop.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    if (outcome is BdappsSendOtpOutcomeFailed) {
      setState(() => _error = outcome.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Validate the display-form `01XXXXXXXXX` (11 digits) and
  /// normalise to `8801XXXXXXXXX` for the BDApps API.
  String? _validateDisplay(String? raw) {
    final s = raw?.trim() ?? '';
    if (!_bdMobileRegExp.hasMatch(s)) {
      return AppLocaleScope.of(context).tr(
        'subscription.invalidMobile',
      );
    }
    return null;
  }

  String _to880(String display) => '88$display';

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final service = BdappsSubscriptionScope.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('subscription.mobileTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
        leading: _alreadySubscribed
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: _alreadySubscribed
          ? _AlreadySubscribedBody(message: t('subscription.alreadySubscribed'))
          // Defensive belt for the "one number per user" rule. The
          // gate normally routes subscribed users to the status
          // card, but if someone deep-links here directly (or the
          // gate ever short-circuits incorrectly), we must NOT
          // render the entry form — letting a subscribed user enter
          // a new mobile and verify would silently re-bind them to
          // a different number without first releasing the old one.
          : service.isPremium
              ? _AlreadySubscribedMobileBody(
                  message: t('subscription.alreadySubscribedMobile'),
                  onBack: () => Navigator.of(context).pop(),
                )
              : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero — lock + title.
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                        ),
                        child: const Icon(
                          Icons.sms_outlined,
                          size: 32,
                          color: AppTheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t('subscription.mobileTitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('subscription.mobileSubtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Carrier-eligibility notice. BDApps billing is
                      // supported only on Robi and Airtel today, so
                      // we tell the user BEFORE they type a number
                      // instead of letting the carrier-side error
                      // bubble up as a generic "OTP failed".
                      _EligibleCarriersBanner(
                        message: t('subscription.mobileEligibleCarriers'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mobileCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: t('subscription.mobileHint'),
                          prefixIcon: const Icon(Icons.phone_iphone_rounded),
                        ),
                        validator: _validateDisplay,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        AuthErrorBanner(message: _error!),
                      ],
                      const Spacer(),
                      BdappsGradientCta(
                        label: t('subscription.sendOtp'),
                        onPressed: _busy ? null : _submit,
                        busy: _busy,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Bangladesh mobile validator: 11 digits, starts with `01`.
final RegExp _bdMobileRegExp = RegExp(r'^01\d{9}$');

/// Lightweight success body shown briefly when `sendOtp` returns
/// `alreadySubscribed`. Mirrors the lock+icon visual language of the
/// Mobile screen so the transition feels continuous.
class _AlreadySubscribedBody extends StatelessWidget {
  const _AlreadySubscribedBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.riskLow.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 36,
                color: AppTheme.riskLow,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft-tinted info banner shown above the mobile input on the
/// BDApps mobile-entry screen. Tells the user that subscription is
/// only available on Robi and Airtel today, so they don't waste an
/// OTP round-trip on a GP / Banglalink / Teletalk number. Uses
/// `secondary` (the same accent as the lock hero) at low alpha so it
/// reads as "informational, not an error" and visually rhymes with
/// the hero icon above it.
class _EligibleCarriersBanner extends StatelessWidget {
  const _EligibleCarriersBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Defensive full-screen fallback for a subscribed user who somehow
/// reached the mobile-entry screen (deep link, gate short-circuit,
/// etc.). Enforces the "unsubscribe before changing numbers" rule by
/// refusing to render the entry form and pointing the user back at
/// the Profile status card where Manage → Cancel lives.
class _AlreadySubscribedMobileBody extends StatelessWidget {
  const _AlreadySubscribedMobileBody({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.riskLow.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 36,
                color: AppTheme.riskLow,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onBack,
              child: Text(
                AppLocaleScope.of(context).tr('common.close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}