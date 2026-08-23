import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/safety_lesson.dart';

/// Read-only view of a single [SafetyLesson] — one big icon header, the
/// subtitle, every section (heading + paragraph + tip list), then the
/// "verify through an official channel" footer card.
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Text(
              lesson.icon,
              style: const TextStyle(fontSize: 60),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              lesson.subtitleFor(locale),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 28),

          ...lesson.sections.map(
            (section) => _buildSection(section, locale),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: AppTheme.tintPanel),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('learn.footerReminder'),
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w600,
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
          Text(
            section.titleFor(locale),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            section.contentFor(locale),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 14),

          ...section.tipsFor(locale).map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}