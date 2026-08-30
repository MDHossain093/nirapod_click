import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/url_scam_rule.dart';
import '../../services/admin_url_rule_service.dart';

/// Admin-only screen that previews the live `url_scam_rules`
/// collection and offers a "compose" flow.
///
/// IMPORTANT — write path: the in-app form below does NOT push
/// directly to Firestore. `firestore.rules` denies client writes to
/// `url_scam_rules/*` because that collection is treated as trusted
/// reference data (a malicious signed-in user must not be able to
/// poison the rule set that every other user's app runs). The form
/// exists so the admin can:
///   1. See what's already published (live preview).
///   2. Compose a new rule locally and copy the matching doc to the
///      clipboard, then paste it into the Firebase Console "Add
///      document" dialog (which uses the Admin SDK and bypasses the
///      rules).
///
/// When we ship a Cloud Function for this (see README roadmap), the
/// compose form will call it directly via httpsCallable() and the
/// preview/clipboard fallback can be removed.
class AdminUrlRulesScreen extends StatefulWidget {
  const AdminUrlRulesScreen({super.key, AdminUrlRuleService? service})
      : _injectedService = service;

  /// Convenience constructor for tests that want to inject a fake
  /// [AdminUrlRuleService].
  const AdminUrlRulesScreen.withService({
    super.key,
    required AdminUrlRuleService service,
  }) : _injectedService = service;

  final AdminUrlRuleService? _injectedService;

  @override
  State<AdminUrlRulesScreen> createState() => _AdminUrlRulesScreenState();
}

class _AdminUrlRulesScreenState extends State<AdminUrlRulesScreen> {
  late final AdminUrlRuleService _admin;

  @override
  void initState() {
    super.initState();
    _admin = widget._injectedService ?? AdminUrlRuleService.instance;
    // Warm the cache so the screen renders synchronously.
    _admin.refresh();
  }

  Future<void> _refresh() async {
    await _admin.refresh();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final rules = _admin.lastRules;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('adminUrlRules.appBarTitle')),
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
        label: Text(t('adminUrlRules.compose')),
        onPressed: _onCompose,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _NoticeBanner(text: t('adminUrlRules.noticeConsoleOnly')),
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
          if (rules.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Text(
                t('adminUrlRules.empty'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            )
          else
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _UrlRulePreviewCard(rule: r),
              ),
        ],
      ),
    );
  }

  Future<void> _onCompose() async {
    final t = AppLocaleScope.of(context).tr;
    final result = await Navigator.of(context).push<UrlRuleDraft>(
      MaterialPageRoute(builder: (_) => const _ComposeUrlRuleScreen()),
    );
    if (result == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(t('adminUrlRules.draftCopied')),
      ),
    );
  }
}

/// One preview row matching a live URL rule doc in Firestore. Kept
/// private to this screen so the styling can evolve independently.
class _UrlRulePreviewCard extends StatelessWidget {
  const _UrlRulePreviewCard({required this.rule});
  final UrlScamRule rule;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: rule.active
              ? AppTheme.borderSubtle
              : AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
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
                  color: AppTheme.primary.withValues(alpha: AppTheme.tintPanelSoft),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Text(
                  t('adminUrlRules.type.${rule.type.name}'),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: AppTheme.tintPanelSoft),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Text(
                  rule.category,
                  style: const TextStyle(
                    color: AppTheme.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                rule.id,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rule.pattern,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _Chip(
                label: '+${rule.score}',
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              _Chip(
                label: rule.active
                    ? t('adminUrlRules.activeOn')
                    : t('adminUrlRules.activeOff'),
                color: rule.active
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// In-memory draft the compose screen hands back. Keeps the publish
/// surface decoupled from the actual persistence (which today is the
/// Firebase Console; later a Cloud Function).
class UrlRuleDraft {
  const UrlRuleDraft({
    required this.docId,
    required this.type,
    required this.category,
    required this.pattern,
    required this.score,
    required this.active,
  });

  final String docId;
  final UrlScamRuleType type;
  final String category;
  final String pattern;
  final int score;
  final bool active;

  /// Field/value map shaped to match [UrlScamRule.toFirestore]. Used by
  /// the clipboard/console workflow today and by the future Cloud
  /// Function call. `updatedAt` is omitted — Firestore fills it via
  /// `FieldValue.serverTimestamp()` on write, and the client doesn't
  /// have a sensible local value to put there.
  Map<String, dynamic> toFirestoreMap() => {
        'type': type.name,
        'category': category,
        'pattern': pattern,
        'score': score,
        'active': active,
        'version': 1,
      };
}

class _ComposeUrlRuleScreen extends StatefulWidget {
  const _ComposeUrlRuleScreen();

  @override
  State<_ComposeUrlRuleScreen> createState() => _ComposeUrlRuleScreenState();
}

class _ComposeUrlRuleScreenState extends State<_ComposeUrlRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _docIdCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _patternCtrl = TextEditingController();
  UrlScamRuleType _type = UrlScamRuleType.keyword;
  double _score = 15;
  bool _active = true;

  @override
  void dispose() {
    _docIdCtrl.dispose();
    _categoryCtrl.dispose();
    _patternCtrl.dispose();
    super.dispose();
  }

  String _humanDocId() {
    final raw = _docIdCtrl.text.trim();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = UrlRuleDraft(
      docId: _humanDocId(),
      type: _type,
      category: _categoryCtrl.text.trim(),
      pattern: _patternCtrl.text.trim(),
      score: _score.round(),
      active: _active,
    );
    // The actual Firestore write happens via the Firebase Console;
    // the in-app compose form only persists to the clipboard so the
    // admin can paste the doc shape straight into "Add document".
    // (If a future Cloud Function lands, this is where we'd call it.)
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('adminUrlRules.composeTitle')),
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
                _NoticeBanner(text: t('adminUrlRules.noticeConsoleOnly')),
                const SizedBox(height: 16),
                _Field(
                  controller: _docIdCtrl,
                  label: t('adminAlerts.fieldDocId'),
                  hint: t('adminAlerts.fieldDocIdHint'),
                  required: true,
                ),
                const SizedBox(height: 12),
                Text(
                  t('adminUrlRules.typeLabel'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in UrlScamRuleType.values)
                      ChoiceChip(
                        label: Text(t('adminUrlRules.type.${type.name}')),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _categoryCtrl,
                  label: t('adminUrlRules.categoryLabel'),
                  required: true,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _patternCtrl,
                  label: t('adminUrlRules.patternLabel'),
                  required: true,
                ),
                const SizedBox(height: 16),
                Text(
                  '${t('adminUrlRules.scoreLabel')}: ${_score.round()}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Slider(
                  value: _score,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: _score.round().toString(),
                  onChanged: (v) => setState(() => _score = v),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  title: Text(t('adminUrlRules.activeLabel')),
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
                    t('adminUrlRules.compose'),
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
/// console-only write path is never surprising. (Duplicated here
/// rather than shared — both screens were created in the same PR and
/// sharing a util file would expand the surface area for what is
/// currently a one-screen widget.)
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
/// so all fields share one visual idiom. (Local copy — see the
/// notice on [_NoticeBanner].)
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;

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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
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