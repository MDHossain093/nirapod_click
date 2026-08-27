import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/safety_lesson.dart';

/// Read-only view of a single [SafetyLesson] — one big icon header, the
/// subtitle, every section (heading + paragraph + tip list), then the
/// "verify through an official channel" footer card.
///
/// Visual language matches the rest of the app: editorial heading rhythm,
/// section titles with a left accent rule, soft tinted surfaces.
class LessonDetailScreen extends StatelessWidget {
  final SafetyLesson lesson;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final locale = AppLocaleScope.of(context).locale;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lesson.titleFor(locale)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          // Hero panel: emoji + subtitle, sitting on a soft tinted
          // surface so it reads as a focal point rather than floating
          // text on the background.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: AppTheme.tintPanel),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withValues(alpha: 0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      lesson.iconData,
                      color: AppTheme.secondary,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  lesson.subtitleFor(locale),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          ...lesson.sections.map(
            (section) => _buildSection(section, locale),
          ),

          const SizedBox(height: 20),

          // Footer "verify through an official channel" card.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: AppTheme.tintPanel),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppTheme.tileIconXs,
                  height: AppTheme.tileIconXs,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('learn.footerReminder'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(LessonSection section, AppLocale locale) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title with a small left accent rule — the
          // editorial touch used in modern content apps. Sized to
          // the line height so wrapping titles don't misalign.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.titleFor(locale),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            section.contentFor(locale),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          // Tip list — keep the Row-with-Expanded pattern so multi-line
          // tips wrap correctly without overflow.
          ...section.tipsFor(locale).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}