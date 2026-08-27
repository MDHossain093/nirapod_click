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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          // Tagline-style heading, matches home + check: 32 / w800 /
          // -0.6 letter-spacing for the unified editorial feel.
          Text(
            t('learn.heading'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.15,
              letterSpacing: -0.6,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            t('learn.subheading'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          ...safetyLessons.map(
            (lesson) => _LearnCard(
              lesson: lesson,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LessonDetailScreen(lesson: lesson),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -------- Reusable bits --------

/// Lightweight press-scale wrapper — same 0.97 spring used on home and
/// check, so taps feel identical across screens.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Single lesson card. Tinted surface in the brand's secondary teal so
/// the list reads as a unified "Learn" zone (vs the colored-block Quick
/// Check tiles on Home, which are the action zone).
///
/// Layout: stacked — emoji badge on top, title + subtitle + meta line
/// below. No Row to fight for horizontal space on narrow phones.
class _LearnCard extends StatelessWidget {
  const _LearnCard({required this.lesson, required this.onTap});

  final SafetyLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final locale = AppLocaleScope.of(context).locale;
    final minutesLabel = t('learn.minutesShort');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withValues(alpha: AppTheme.tintPanel),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.secondary.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppTheme.tileIconMd,
                    height: AppTheme.tileIconMd,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        lesson.iconData,
                        color: AppTheme.secondary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lesson.titleFor(locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppTheme.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.2,
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
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Meta row (minutes + category) sits below the main content
              // so it doesn't compete for horizontal space with the title.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${lesson.minutes} $minutesLabel • ${lesson.categoryFor(locale)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}