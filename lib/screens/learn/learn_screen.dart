import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/safety_lessons.dart';
import '../../models/safety_lesson.dart';
import 'lesson_detail_screen.dart';

/// Local, offline Safety Learning Center.
///
/// Lists every lesson shipped in `lib/data/safety_lessons.dart`. Tapping a
/// card pushes [LessonDetailScreen] which renders the lesson body.
///
/// No Gemini, no Firebase — the whole list is `const` so it costs zero at
/// runtime and ships with the app binary.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('learn.appBarTitle')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t('learn.heading'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            t('learn.subheading'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          ...safetyLessons.map(
            (lesson) => _buildLessonCard(
              context,
              lesson,
              t,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context,
    SafetyLesson lesson,
    String Function(String key) t,
  ) {
    final locale = AppLocaleScope.of(context).locale;
    final minutesLabel = t('learn.minutesShort');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LessonDetailScreen(lesson: lesson),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      lesson.icon,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.titleFor(locale),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        lesson.subtitleFor(locale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '${lesson.minutes} $minutesLabel • ${lesson.categoryFor(locale)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}