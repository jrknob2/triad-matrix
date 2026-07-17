import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../coach/lesson_detail_screen.dart';
import '../coach/lesson_plan.dart';
import '../coach/lesson_plan_loader.dart';
import '../coach/lesson_progress.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<_TeachingFlowData> _dataFuture = _loadData();

  Future<_TeachingFlowData> _loadData() async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final LessonProgressService progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    return _TeachingFlowData(
      library: library,
      progressService: progressService,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<_TeachingFlowData>(
        future: _dataFuture,
        builder:
            (BuildContext context, AsyncSnapshot<_TeachingFlowData> snapshot) {
              if (snapshot.hasError) {
                return _LessonLoadError(error: snapshot.error);
              }
              final _TeachingFlowData? data = snapshot.data;
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _LevelListView(data: data, onProgressChanged: _refresh);
            },
      ),
    );
  }
}

class _TeachingFlowData {
  final LessonContentLibrary library;
  final LessonProgressService progressService;

  const _TeachingFlowData({
    required this.library,
    required this.progressService,
  });
}

class _LevelListView extends StatelessWidget {
  final _TeachingFlowData data;
  final VoidCallback onProgressChanged;

  const _LevelListView({required this.data, required this.onProgressChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        Text(
          'Choose Level',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start where the lessons match your playing today.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        for (final ContentLevel level in data.library.index.levels) ...[
          _LevelRow(
            level: level,
            summary: data.progressService.summaryForLevel(
              level,
              data.library.lessonsForLevel(level.id),
            ),
            onOpen: () => _openLevel(context, level),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _openLevel(BuildContext context, ContentLevel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _SkillListScreen(
            data: data,
            level: level,
            onProgressChanged: onProgressChanged,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _LevelRow extends StatelessWidget {
  final ContentLevel level;
  final LevelProgressSummary summary;
  final VoidCallback onOpen;

  const _LevelRow({
    required this.level,
    required this.summary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        level.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: DrumcabularyTheme.edgeTextPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (summary.showsCompletionIndicator) ...<Widget>[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: DrumcabularyTheme.edgeOrange,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(label: _durationLabel(summary.practicedSeconds)),
                    _Pill(
                      label:
                          '${summary.completedLessons}/${summary.totalLessons} complete',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: DrumcabularyTheme.edgeOrange,
          ),
        ],
      ),
    );
  }
}

class _SkillListScreen extends StatelessWidget {
  final _TeachingFlowData data;
  final ContentLevel level;
  final VoidCallback onProgressChanged;

  const _SkillListScreen({
    required this.data,
    required this.level,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> skills = data.library.skillsForLevel(level.id);
    return Scaffold(
      appBar: AppBar(title: Text(level.title)),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: <Widget>[
            Text(
              'Choose Skill',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick the area you want to work on.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            if (skills.isEmpty)
              const DrumPanel(
                padding: EdgeInsets.all(18),
                child: Text('No lessons have been added for this level yet.'),
              )
            else
              for (final String skill in skills) ...[
                _SkillRow(
                  skill: skill,
                  summary: data.progressService.summaryForSkill(
                    id: '${level.id}:$skill',
                    lessons: data.library.lessonsForSkill(
                      levelId: level.id,
                      skill: skill,
                    ),
                  ),
                  onOpen: () => _openSkill(context, skill),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSkill(BuildContext context, String skill) async {
    final List<Lesson> lessons = data.library.lessonsForSkill(
      levelId: level.id,
      skill: skill,
    );
    if (lessons.length == 1) {
      await _openLesson(context, lessons.single);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _SkillLessonsScreen(
            data: data,
            level: level,
            skill: skill,
            lessons: lessons,
            onProgressChanged: onProgressChanged,
          );
        },
      ),
    );
    onProgressChanged();
  }

  Future<void> _openLesson(BuildContext context, Lesson lesson) async {
    await data.progressService.openLesson(lesson.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
            progressService: data.progressService,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _SkillRow extends StatelessWidget {
  final String skill;
  final LevelProgressSummary summary;
  final VoidCallback onOpen;

  const _SkillRow({
    required this.skill,
    required this.summary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _labelFor(skill),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DrumcabularyTheme.edgeTextPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(label: _durationLabel(summary.practicedSeconds)),
                    _Pill(
                      label:
                          '${summary.completedLessons}/${summary.totalLessons} complete',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: DrumcabularyTheme.edgeOrange,
          ),
        ],
      ),
    );
  }
}

class _SkillLessonsScreen extends StatelessWidget {
  final _TeachingFlowData data;
  final ContentLevel level;
  final String skill;
  final List<Lesson> lessons;
  final VoidCallback onProgressChanged;

  const _SkillLessonsScreen({
    required this.data,
    required this.level,
    required this.skill,
    required this.lessons,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_labelFor(skill))),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: <Widget>[
            Text(
              'Choose Lesson',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              level.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            for (final Lesson lesson in lessons) ...[
              _LessonRow(
                lesson: lesson,
                progress: data.progressService.progressForLesson(lesson.id),
                onOpen: () => _openLesson(context, lesson),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openLesson(BuildContext context, Lesson lesson) async {
    await data.progressService.openLesson(lesson.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
            progressService: data.progressService,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _LessonRow extends StatelessWidget {
  final Lesson lesson;
  final LessonProgress progress;
  final VoidCallback onOpen;

  const _LessonRow({
    required this.lesson,
    required this.progress,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DrumcabularyTheme.edgeTextPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.overview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(label: 'Lesson ${lesson.order}'),
                    _Pill(label: '${lesson.estimatedMinutes} min'),
                    _Pill(label: _statusLabel(progress.status)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: DrumcabularyTheme.edgeOrange,
          ),
        ],
      ),
    );
  }
}

class _NavPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NavPanel({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LessonLoadError extends StatelessWidget {
  final Object? error;

  const _LessonLoadError({required this.error});

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
              const DrumSectionTitle(text: 'Lessons Unavailable'),
              const SizedBox(height: 10),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _statusLabel(LessonProgressStatus status) {
  return switch (status) {
    LessonProgressStatus.inProgress => 'In Progress',
    LessonProgressStatus.completed => 'Complete',
    LessonProgressStatus.notStarted => 'Not Started',
  };
}

String _durationLabel(int seconds) {
  if (seconds <= 0) return '0m practiced';
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m practiced';
  return '${minutes}m practiced';
}

String _labelFor(String value) {
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
