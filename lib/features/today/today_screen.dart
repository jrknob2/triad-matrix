import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../coach/lesson_detail_screen.dart';
import '../coach/lesson_plan.dart';
import '../coach/lesson_plan_loader.dart';
import '../practice/widgets/pattern_text_styles.dart';

typedef OpenMatrixCallback =
    void Function({
      LearningLaneV1? lane,
      Set<TriadMatrixFilterV1>? filters,
      List<String>? selectedItemIds,
    });

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required AppController controller,
    required OpenMatrixCallback onOpenMatrix,
    required VoidCallback onOpenFocus,
    required ValueChanged<String> onOpenItem,
    required void Function(String, PracticeModeV1) onPracticeItemInMode,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final Future<LessonPlan> _lessonPlanFuture =
      LessonPlanLoader.loadFlowFoundations();

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<LessonPlan>(
        future: _lessonPlanFuture,
        builder: (BuildContext context, AsyncSnapshot<LessonPlan> snapshot) {
          if (snapshot.hasError) {
            return _CoachLoadError(error: snapshot.error);
          }
          final LessonPlan? lessonPlan = snapshot.data;
          if (lessonPlan == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _CoachLessonPlanView(lessonPlan: lessonPlan);
        },
      ),
    );
  }
}

class _CoachLessonPlanView extends StatelessWidget {
  final LessonPlan lessonPlan;

  const _CoachLessonPlanView({required this.lessonPlan});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        Text(
          lessonPlan.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lessonPlan.subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DrumcabularyTheme.mutedInk,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        DrumPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (
                int index = 0;
                index < lessonPlan.lessons.length;
                index += 1
              ) ...<Widget>[
                if (index > 0) const Divider(height: 1),
                _LessonListRow(
                  lessonPlan: lessonPlan,
                  lesson: lessonPlan.lessons[index],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonListRow extends StatelessWidget {
  final LessonPlan lessonPlan;
  final Lesson lesson;

  const _LessonListRow({required this.lessonPlan, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final LessonPattern? primaryPattern = lesson.primaryPattern;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openLesson(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LessonNumberBadge(number: lesson.number),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lesson.objective,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DrumcabularyTheme.mutedInk,
                        height: 1.28,
                      ),
                    ),
                    if (primaryPattern != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        primaryPattern.notation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PatternTextStyles.compact(
                          context,
                        ).copyWith(fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${lesson.estimatedMinutes} min',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: DrumcabularyTheme.mutedInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLesson(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(lessonPlan: lessonPlan, lesson: lesson);
        },
      ),
    );
  }
}

class _LessonNumberBadge extends StatelessWidget {
  final int number;

  const _LessonNumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DrumcabularyTheme.ink,
          shape: BoxShape.circle,
          border: Border.all(color: DrumcabularyTheme.line),
        ),
        child: Center(
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.surface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachLoadError extends StatelessWidget {
  final Object? error;

  const _CoachLoadError({required this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        DrumPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Lesson Plan Unavailable'),
              const SizedBox(height: 10),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF9D2B24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
