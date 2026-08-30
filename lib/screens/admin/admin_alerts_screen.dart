import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_alert.dart';
import '../../services/admin_alert_service.dart';
import '../../services/alert_service.dart';

/// Admin-only screen that previews the published alerts and offers a
/// "compose" flow.
///
/// IMPORTANT — write path: the in-app form below does NOT push
/// directly to Firestore. `firestore.rules` denies client writes to
/// `admin_alerts/*` because that collection is treated as trusted
/// reference data (a malicious signed-in user must not be able to
/// publish fake alerts that other users see). The form exists so the
/// admin can:
///   1. See what's already published (live preview).
///   2. Compose a new alert locally and copy the matching doc to the
///      clipboard or share sheet, then paste it into the Firebase
///      Console "Add document" dialog (which uses the Admin SDK and
///      bypasses the rules).
///
/// When we ship a Cloud Function for this (see README roadmap), the
/// compose form will call it directly via httpsCallable() and the
/// preview/clipboard fallback can be removed.
class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key, this.adminAlertService})
      : alertService = null;

  /// Convenience constructor for tests that want to inject the
  /// downstream service the screen pulls alerts from.
  const AdminAlertsScreen.withServices({
    super.key,
    required this.adminAlertService,
    required this.alertService,
  });

  final AdminAlertService? adminAlertService;
  final AlertService? alertService;

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  late final AdminAlertService _admin;
  late final AlertService _alertService;

  @override
  void initState() {
    super.initState();
    _admin = widget.adminAlertService ?? AdminAlertService.instance;
    _alertService = widget.alertService ?? AlertService.instance;
    // Warm both caches so the screen renders synchronously.
    _admin.refresh();
    _alertService.refreshAdminAlerts();
  }

  Future<void> _refresh() async {
    await _admin.refresh();
    await _alertService.refreshAdminAlerts();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final alerts = _admin.lastAlerts;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('adminAlerts.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t('adminAlerts.refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('adminAlerts.compose')),
        onPressed: _onCompose,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _NoticeBanner(text: t('adminAlerts.consoleOnlyNotice')),
          const SizedBox(height: 16),
          Text(
            t('adminAlerts.sectionLive'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Text(
                t('adminAlerts.emptyLive'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            )
          else
            for (final a in alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AdminAlertPreviewCard(alert: a),
              ),
        ],
      ),
    );
  }

  Future<void> _onCompose() async {
    final t = AppLocaleScope.of(context).tr;
    final result = await Navigator.of(context).push<AdminAlertDraft>(
      MaterialPageRoute(builder: (_) => const _ComposeAdminAlertScreen()),
    );
    if (result == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(t('adminAlerts.draftCopied')),
      ),
    );
  }
}

/// One preview row matching the live admin alert rendered in the
/// user-facing Alerts page (see `_AdminAlertCard`). Kept private to
/// this screen so the styling can evolve independently.
class _AdminAlertPreviewCard extends StatelessWidget {
  const _AdminAlertPreviewCard({required this.alert});
  final AdminAlert alert;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final isBn = AppLocaleScope.of(context).locale == AppLocale.bangla;
    final title =
        (isBn && alert.titleBn.isNotEmpty) ? alert.titleBn : alert.titleEn;
    final body =
        (isBn && alert.bodyBn.isNotEmpty) ? alert.bodyBn : alert.bodyEn;
    final color = switch (alert.severity) {
      AdminAlert.severityCritical => AppTheme.riskCritical,
      AdminAlert.severityWarning => AppTheme.riskHigh,
      _ => AppTheme.primary,
    };
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: AppTheme.tintBorderEmphasis)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: AppTheme.tintPanelSoft),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Text(
                  t('alerts.severity.${alert.severity}'),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                alert.id,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// In-memory draft the compose screen hands back. Keeps the publish
/// surface decoupled from the actual persistence (which today is the
/// Firebase Console; later a Cloud Function).
class AdminAlertDraft {
  const AdminAlertDraft({
    required this.docId,
    required this.titleEn,
    required this.titleBn,
    required this.bodyEn,
    required this.bodyBn,
    required this.severity,
    required this.active,
  });

  final String docId;
  final String titleEn;
  final String titleBn;
  final String bodyEn;
  final String bodyBn;
  final String severity;
  final bool active;

  /// Field/value map shaped to match [AdminAlert.toFirestore]. Used by
  /// the clipboard/console workflow today and by the future Cloud
  /// Function call.
  Map<String, dynamic> toFirestoreMap() => {
        'titleEn': titleEn,
        'titleBn': titleBn,
        'bodyEn': bodyEn,
        'bodyBn': bodyBn,
        'severity': severity,
        'active': active,
        'version': 1,
      };
}

class _ComposeAdminAlertScreen extends StatefulWidget {
  const _ComposeAdminAlertScreen();

  @override
  State<_ComposeAdminAlertScreen> createState() =>
      _ComposeAdminAlertScreenState();
}

class _ComposeAdminAlertScreenState
    extends State<_ComposeAdminAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docIdCtrl = TextEditingController();
  final _titleEnCtrl = TextEditingController();
  final _titleBnCtrl = TextEditingController();
  final _bodyEnCtrl = TextEditingController();
  final _bodyBnCtrl = TextEditingController();
  String _severity = AdminAlert.severityInfo;
  bool _active = true;

  @override
  void dispose() {
    _docIdCtrl.dispose();
    _titleEnCtrl.dispose();
    _titleBnCtrl.dispose();
    _bodyEnCtrl.dispose();
    _bodyBnCtrl.dispose();
    super.dispose();
  }

  String _humanDocId() {
    final raw = _docIdCtrl.text.trim();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final draft = AdminAlertDraft(
      docId: _humanDocId(),
      titleEn: _titleEnCtrl.text.trim(),
      titleBn: _titleBnCtrl.text.trim(),
      bodyEn: _bodyEnCtrl.text.trim(),
      bodyBn: _bodyBnCtrl.text.trim(),
      severity: _severity,
      active: _active,
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('adminAlerts.composeTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NoticeBanner(text: t('adminAlerts.consoleOnlyNotice')),
                const SizedBox(height: 16),
                _Field(
                  controller: _docIdCtrl,
                  label: t('adminAlerts.fieldDocId'),
                  hint: t('adminAlerts.fieldDocIdHint'),
                  required: true,
                  maxLength: AdminAlert.maxTitle,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _titleEnCtrl,
                  label: t('adminAlerts.fieldTitleEn'),
                  required: true,
                  maxLength: AdminAlert.maxTitle,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _titleBnCtrl,
                  label: t('adminAlerts.fieldTitleBn'),
                  maxLength: AdminAlert.maxTitle,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _bodyEnCtrl,
                  label: t('adminAlerts.fieldBodyEn'),
                  maxLines: 4,
                  maxLength: AdminAlert.maxBody,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _bodyBnCtrl,
                  label: t('adminAlerts.fieldBodyBn'),
                  maxLines: 4,
                  maxLength: AdminAlert.maxBody,
                ),
                const SizedBox(height: 16),
                Text(
                  t('adminAlerts.fieldSeverity'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final sev in const [
                      AdminAlert.severityInfo,
                      AdminAlert.severityWarning,
                      AdminAlert.severityCritical,
                    ])
                      ChoiceChip(
                        label: Text(t('alerts.severity.$sev')),
                        selected: _severity == sev,
                        onSelected: (_) => setState(() => _severity = sev),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(t('adminAlerts.fieldActive')),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  onPressed: _submit,
                  child: Text(
                    t('adminAlerts.compose'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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

/// Banner used at the top of the admin screens so the v1
/// console-only write path is never surprising.
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: AppTheme.tintPanelSoft),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning.withValues(alpha: AppTheme.tintBorderEmphasis)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single form row. Wraps a [TextFormField] in our standard container
/// so all fields share one visual idiom.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          counterText: '',
        ),
        validator: (v) {
          if (!required) return null;
          if (v == null || v.trim().isEmpty) return '$label *';
          return null;
        },
      ),
    );
  }
}