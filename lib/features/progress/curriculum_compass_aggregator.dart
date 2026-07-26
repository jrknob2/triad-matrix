import 'package:flutter/foundation.dart';

import '../coach/lesson_plan.dart';
import '../coach/lesson_progress.dart';

@immutable
class CurriculumNode {
  final String id;
  final String title;
  final String? shortDescription;
  final List<CurriculumNode> children;
  final List<Lesson> lessons;
  final String lessonFilterId;

  const CurriculumNode({
    required this.id,
    required this.title,
    this.shortDescription,
    this.children = const <CurriculumNode>[],
    this.lessons = const <Lesson>[],
    String? lessonFilterId,
  }) : lessonFilterId = lessonFilterId ?? id;

  bool get hasChildren => children.isNotEmpty;

  List<Lesson> get subtreeLessons {
    final Map<String, Lesson> byId = <String, Lesson>{};
    void collect(CurriculumNode node) {
      for (final Lesson lesson in node.lessons) {
        byId[lesson.id] = lesson;
      }
      for (final CurriculumNode child in node.children) {
        collect(child);
      }
    }

    collect(this);
    return byId.values.toList(growable: false);
  }
}

@immutable
class CurriculumBreadcrumb {
  final String id;
  final String title;

  const CurriculumBreadcrumb({required this.id, required this.title});
}

@immutable
class CurriculumCompassPoint {
  final String nodeId;
  final String label;
  final String? shortDescription;
  final String lessonFilterId;
  final bool hasChildren;
  final int practicedSeconds;
  final int practicedExerciseCount;
  final int practicedLessonCount;
  final int completedExerciseCount;
  final int totalExerciseCount;
  final int completedLessonCount;
  final double practiceInvestmentRatio;
  final double completionRatio;

  const CurriculumCompassPoint({
    required this.nodeId,
    required this.label,
    this.shortDescription,
    required this.lessonFilterId,
    required this.hasChildren,
    required this.practicedSeconds,
    required this.practicedExerciseCount,
    required this.practicedLessonCount,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
    required this.completedLessonCount,
    required this.practiceInvestmentRatio,
    required this.completionRatio,
  });

  bool get hasPractice => practicedSeconds > 0;
  bool get hasCompletions => completedExerciseCount > 0;
  bool get hasExercises => totalExerciseCount > 0;
}

@immutable
class CurriculumCompassSnapshot {
  final CurriculumNode currentNode;
  final List<CurriculumBreadcrumb> breadcrumbs;
  final List<CurriculumCompassPoint> values;

  const CurriculumCompassSnapshot({
    required this.currentNode,
    required this.breadcrumbs,
    required this.values,
  });

  bool get hasNodes => values.isNotEmpty;
  bool get isRoot => currentNode.id == CurriculumCompassTreeBuilder.rootId;

  bool get hasMetricData {
    return values.any(
      (CurriculumCompassPoint value) =>
          value.hasPractice || value.hasCompletions,
    );
  }
}

class CurriculumCompassAggregator {
  const CurriculumCompassAggregator();

  CurriculumCompassSnapshot build({
    required CurriculumNode root,
    required List<String> nodePath,
    required LessonProgressService progressService,
  }) {
    final _ResolvedNode resolved = _resolveNode(root, nodePath);
    final List<CurriculumCompassPoint> values = _valuesForChildren(
      resolved.node.children,
      progressService: progressService,
    );

    return CurriculumCompassSnapshot(
      currentNode: resolved.node,
      breadcrumbs: <CurriculumBreadcrumb>[
        const CurriculumBreadcrumb(
          id: CurriculumCompassTreeBuilder.rootId,
          title: 'Curriculum',
        ),
        for (final CurriculumNode node in resolved.path)
          CurriculumBreadcrumb(id: node.id, title: node.title),
      ],
      values: values,
    );
  }

  _ResolvedNode _resolveNode(CurriculumNode root, List<String> nodePath) {
    CurriculumNode current = root;
    final List<CurriculumNode> resolvedPath = <CurriculumNode>[];
    for (final String nodeId in nodePath) {
      final CurriculumNode? next = _childById(current, nodeId);
      if (next == null) break;
      current = next;
      resolvedPath.add(next);
    }
    return _ResolvedNode(node: current, path: resolvedPath);
  }

  CurriculumNode? _childById(CurriculumNode node, String nodeId) {
    for (final CurriculumNode child in node.children) {
      if (child.id == nodeId) return child;
    }
    return null;
  }

  List<CurriculumCompassPoint> _valuesForChildren(
    List<CurriculumNode> children, {
    required LessonProgressService progressService,
  }) {
    final Map<String, _NodeProgressAccumulator> accumulators =
        <String, _NodeProgressAccumulator>{
          for (final CurriculumNode child in children)
            child.id: _accumulatorFor(child, progressService),
        };
    final int maxPracticedSeconds = accumulators.values.fold<int>(
      0,
      (int max, _NodeProgressAccumulator value) =>
          value.practicedSeconds > max ? value.practicedSeconds : max,
    );

    return <CurriculumCompassPoint>[
      for (final CurriculumNode child in children)
        _valueFor(
          child,
          accumulators[child.id]!,
          maxPracticedSeconds: maxPracticedSeconds,
        ),
    ];
  }

  _NodeProgressAccumulator _accumulatorFor(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    final _NodeProgressAccumulator accumulator = _NodeProgressAccumulator();
    for (final Lesson lesson in node.subtreeLessons) {
      bool lessonHasPracticedExercise = false;
      bool lessonHasCompletedExercise = false;
      for (final LessonExercise exercise in lesson.exercises) {
        final ExerciseProgress progress = progressService.progressForExercise(
          lessonId: lesson.id,
          exerciseId: exercise.id,
        );
        accumulator.totalExerciseCount += 1;

        final int practicedSeconds = progress.practicedSeconds;
        accumulator.practicedSeconds += practicedSeconds;
        if (practicedSeconds > 0) {
          accumulator.practicedExerciseCount += 1;
          lessonHasPracticedExercise = true;
        }

        if (progress.status == LessonProgressStatus.completed) {
          accumulator.completedExerciseCount += 1;
          lessonHasCompletedExercise = true;
        }
      }
      if (lessonHasPracticedExercise) {
        accumulator.practicedLessonIds.add(lesson.id);
      }
      if (lessonHasCompletedExercise) {
        accumulator.completedLessonIds.add(lesson.id);
      }
    }
    return accumulator;
  }

  CurriculumCompassPoint _valueFor(
    CurriculumNode node,
    _NodeProgressAccumulator accumulator, {
    required int maxPracticedSeconds,
  }) {
    final double practiceInvestmentRatio = maxPracticedSeconds == 0
        ? 0
        : accumulator.practicedSeconds / maxPracticedSeconds;
    final double completionRatio = accumulator.totalExerciseCount == 0
        ? 0
        : accumulator.completedExerciseCount / accumulator.totalExerciseCount;

    return CurriculumCompassPoint(
      nodeId: node.id,
      label: node.title,
      shortDescription: node.shortDescription,
      lessonFilterId: node.lessonFilterId,
      hasChildren: node.hasChildren,
      practicedSeconds: accumulator.practicedSeconds,
      practicedExerciseCount: accumulator.practicedExerciseCount,
      practicedLessonCount: accumulator.practicedLessonIds.length,
      completedExerciseCount: accumulator.completedExerciseCount,
      totalExerciseCount: accumulator.totalExerciseCount,
      completedLessonCount: accumulator.completedLessonIds.length,
      practiceInvestmentRatio: practiceInvestmentRatio,
      completionRatio: completionRatio,
    );
  }
}

class CurriculumCompassTreeBuilder {
  static const String rootId = 'curriculum';

  const CurriculumCompassTreeBuilder();

  CurriculumNode build(LessonContentLibrary library) {
    final Map<String, List<Lesson>> lessonsBySkill = <String, List<Lesson>>{};
    for (final Lesson lesson in _orderedLessons(library)) {
      lessonsBySkill.putIfAbsent(lesson.skill, () => <Lesson>[]).add(lesson);
    }

    return CurriculumNode(
      id: rootId,
      title: 'Curriculum',
      children: <CurriculumNode>[
        _node(
          id: 'timing',
          title: 'Timing',
          shortDescription:
              'Build steady pulse, subdivision control, and confident time feel.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('pulse', 'Pulse'),
            _TemporaryNodeSpec('subdivisions', 'Subdivisions'),
            _TemporaryNodeSpec('tempo-control', 'Tempo Control'),
            _TemporaryNodeSpec('odd-meter', 'Odd Meter'),
            _TemporaryNodeSpec('swing-feel', 'Swing Feel'),
            _TemporaryNodeSpec('syncopation', 'Syncopation'),
            _TemporaryNodeSpec('rests', 'Rests'),
            _TemporaryNodeSpec('counting', 'Counting'),
            _TemporaryNodeSpec('metric-modulation', 'Metric Modulation'),
            _TemporaryNodeSpec('time-keeping', 'Time Keeping'),
          ],
        ),
        _node(
          id: 'grooves',
          title: 'Grooves',
          shortDescription:
              'Develop the rhythmic patterns that support modern songs.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec(
              'core-grooves',
              'Core Grooves',
              shortDescription:
                  'Build dependable foundational beats for common musical situations.',
              skillIds: <String>['grooves'],
              lessonFilterId: 'grooves',
            ),
            _TemporaryNodeSpec('rock-grooves', 'Rock Grooves'),
            _TemporaryNodeSpec('funk-grooves', 'Funk Grooves'),
            _TemporaryNodeSpec('shuffle-grooves', 'Shuffle Grooves'),
            _TemporaryNodeSpec('latin-grooves', 'Latin Grooves'),
            _TemporaryNodeSpec('jazz-grooves', 'Jazz Grooves'),
            _TemporaryNodeSpec('half-time', 'Half-Time'),
            _TemporaryNodeSpec('linear-grooves', 'Linear Grooves'),
            _TemporaryNodeSpec('foot-patterns', 'Foot Patterns'),
            _TemporaryNodeSpec('groove-phrasing', 'Groove Phrasing'),
          ],
        ),
        _node(
          id: 'rudiments',
          title: 'Rudiments',
          shortDescription:
              'Strengthen the sticking vocabulary behind clean drum movement.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec(
              'core-rudiments',
              'Core Rudiments',
              shortDescription:
                  'Practice essential rudimental shapes and control.',
              skillIds: <String>['rudiments'],
              lessonFilterId: 'rudiments',
            ),
            _TemporaryNodeSpec('single-strokes', 'Single Strokes'),
            _TemporaryNodeSpec('double-strokes', 'Double Strokes'),
            _TemporaryNodeSpec('paradiddles', 'Paradiddles'),
            _TemporaryNodeSpec('rolls', 'Rolls'),
            _TemporaryNodeSpec('flams', 'Flams'),
            _TemporaryNodeSpec('drags', 'Drags'),
            _TemporaryNodeSpec('ratamacues', 'Ratamacues'),
            _TemporaryNodeSpec('hybrid-rudiments', 'Hybrid Rudiments'),
            _TemporaryNodeSpec('rudiment-orchestration', 'Orchestration'),
          ],
        ),
        _node(
          id: 'technique',
          title: 'Technique',
          shortDescription:
              'Refine the physical motions that make playing relaxed and clear.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('grip', 'Grip'),
            _TemporaryNodeSpec('rebound', 'Rebound'),
            _TemporaryNodeSpec('wrist-strokes', 'Wrist Strokes'),
            _TemporaryNodeSpec('finger-control', 'Finger Control'),
            _TemporaryNodeSpec('moeller', 'Moeller'),
            _TemporaryNodeSpec('push-pull', 'Push Pull'),
            _TemporaryNodeSpec('foot-technique', 'Foot Technique'),
            _TemporaryNodeSpec('doubles', 'Doubles'),
            _TemporaryNodeSpec('speed', 'Speed'),
            _TemporaryNodeSpec('endurance', 'Endurance'),
          ],
        ),
        _node(
          id: 'coordination',
          title: 'Coordination',
          shortDescription:
              'Coordinate hands and feet across layered rhythmic ideas.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('two-way', 'Two-Way'),
            _TemporaryNodeSpec('three-way', 'Three-Way'),
            _TemporaryNodeSpec('four-way', 'Four-Way'),
            _TemporaryNodeSpec('independence', 'Independence'),
            _TemporaryNodeSpec('ostinatos', 'Ostinatos'),
            _TemporaryNodeSpec('hand-foot', 'Hand + Foot'),
            _TemporaryNodeSpec('left-hand-lead', 'Left-Hand Lead'),
            _TemporaryNodeSpec('right-hand-lead', 'Right-Hand Lead'),
            _TemporaryNodeSpec('voice-control', 'Voice Control'),
            _TemporaryNodeSpec('limb-balance', 'Limb Balance'),
          ],
        ),
        _node(
          id: 'dynamics',
          title: 'Dynamics',
          shortDescription:
              'Shape accents, ghost notes, and touch into expressive control.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('accents', 'Accents'),
            _TemporaryNodeSpec('ghost-notes', 'Ghost Notes'),
            _TemporaryNodeSpec('taps', 'Taps'),
            _TemporaryNodeSpec('rimshots', 'Rimshots'),
            _TemporaryNodeSpec('crescendos', 'Crescendos'),
            _TemporaryNodeSpec('decrescendos', 'Decrescendos'),
            _TemporaryNodeSpec('dynamic-control', 'Control'),
            _TemporaryNodeSpec('comping-dynamics', 'Comping Dynamics'),
            _TemporaryNodeSpec('orchestration-dynamics', 'Orchestration'),
            _TemporaryNodeSpec('touch', 'Touch'),
          ],
        ),
        _node(
          id: 'vocabulary',
          title: 'Vocabulary',
          shortDescription:
              'Build reusable rhythmic phrases for fills, grooves, and solos.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec(
              'triads',
              'Triads',
              shortDescription:
                  'Combine three-note shapes into flexible drum vocabulary.',
            ),
            _TemporaryNodeSpec(
              'triplet-vocabulary',
              'Triplet Vocabulary',
              shortDescription:
                  'Turn triplet cells into musical fill vocabulary.',
              skillIds: <String>['vocabulary'],
              lessonFilterId: 'vocabulary',
            ),
            _TemporaryNodeSpec('fills', 'Fills'),
            _TemporaryNodeSpec('motifs', 'Motifs'),
            _TemporaryNodeSpec('phrases', 'Phrases'),
            _TemporaryNodeSpec('cells', 'Cells'),
            _TemporaryNodeSpec('call-response', 'Call + Response'),
            _TemporaryNodeSpec('turnarounds', 'Turnarounds'),
            _TemporaryNodeSpec('transitions', 'Transitions'),
            _TemporaryNodeSpec('applications', 'Applications'),
          ],
        ),
        _node(
          id: 'reading',
          title: 'Reading',
          shortDescription:
              'Connect written rhythms to reliable movement around the kit.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('quarter-notes', 'Quarter Notes'),
            _TemporaryNodeSpec('eighth-notes', 'Eighth Notes'),
            _TemporaryNodeSpec('sixteenth-notes', 'Sixteenth Notes'),
            _TemporaryNodeSpec('triplets', 'Triplets'),
            _TemporaryNodeSpec('rests-reading', 'Rests'),
            _TemporaryNodeSpec('ties', 'Ties'),
            _TemporaryNodeSpec('repeats', 'Repeats'),
            _TemporaryNodeSpec('charts', 'Charts'),
            _TemporaryNodeSpec('syncopated-reading', 'Syncopation'),
            _TemporaryNodeSpec('sight-reading', 'Sight Reading'),
          ],
        ),
        _node(
          id: 'musicianship',
          title: 'Musicianship',
          shortDescription:
              'Develop listening, feel, phrasing, and musical decision-making.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('listening', 'Listening'),
            _TemporaryNodeSpec('form', 'Form'),
            _TemporaryNodeSpec('phrasing-musicianship', 'Phrasing'),
            _TemporaryNodeSpec('feel', 'Feel'),
            _TemporaryNodeSpec('time-feel', 'Time Feel'),
            _TemporaryNodeSpec('ensemble-awareness', 'Ensemble'),
            _TemporaryNodeSpec('songcraft', 'Songcraft'),
            _TemporaryNodeSpec('style', 'Style'),
            _TemporaryNodeSpec('texture', 'Texture'),
            _TemporaryNodeSpec('taste', 'Taste'),
          ],
        ),
        _node(
          id: 'improvisation',
          title: 'Improvisation',
          shortDescription:
              'Practice variation and spontaneous ideas with clear structure.',
          lessonsBySkill: lessonsBySkill,
          children: const <_TemporaryNodeSpec>[
            _TemporaryNodeSpec('variation', 'Variation'),
            _TemporaryNodeSpec('development', 'Development'),
            _TemporaryNodeSpec('solo-phrasing', 'Solo Phrasing'),
            _TemporaryNodeSpec('space', 'Space'),
            _TemporaryNodeSpec('question-answer', 'Question + Answer'),
            _TemporaryNodeSpec('theme-variation', 'Theme + Variation'),
            _TemporaryNodeSpec('trading', 'Trading'),
            _TemporaryNodeSpec('solo-structure', 'Solo Structure'),
            _TemporaryNodeSpec('motivic-play', 'Motivic Play'),
            _TemporaryNodeSpec('creative-constraints', 'Constraints'),
          ],
        ),
      ],
    );
  }

  CurriculumNode _node({
    required String id,
    required String title,
    String? shortDescription,
    required Map<String, List<Lesson>> lessonsBySkill,
    required List<_TemporaryNodeSpec> children,
  }) {
    return CurriculumNode(
      id: id,
      title: title,
      shortDescription: shortDescription,
      children: <CurriculumNode>[
        for (final _TemporaryNodeSpec child in children)
          child.toNode(lessonsBySkill),
      ],
    );
  }

  List<Lesson> _orderedLessons(LessonContentLibrary library) {
    return <Lesson>[
      for (final ContentLevel level in library.index.levels)
        ...library.lessonsForLevel(level.id),
    ];
  }
}

class _TemporaryNodeSpec {
  final String id;
  final String title;
  final String? shortDescription;
  final List<String> skillIds;
  final String? lessonFilterId;

  const _TemporaryNodeSpec(
    this.id,
    this.title, {
    this.shortDescription,
    this.skillIds = const <String>[],
    this.lessonFilterId,
  });

  CurriculumNode toNode(Map<String, List<Lesson>> lessonsBySkill) {
    final Map<String, Lesson> lessonsById = <String, Lesson>{};
    for (final String skillId in skillIds) {
      for (final Lesson lesson in lessonsBySkill[skillId] ?? const <Lesson>[]) {
        lessonsById[lesson.id] = lesson;
      }
    }

    return CurriculumNode(
      id: id,
      title: title,
      shortDescription: shortDescription,
      lessons: lessonsById.values.toList(growable: false),
      lessonFilterId:
          lessonFilterId ?? (skillIds.isEmpty ? id : skillIds.first),
    );
  }
}

class _ResolvedNode {
  final CurriculumNode node;
  final List<CurriculumNode> path;

  const _ResolvedNode({required this.node, required this.path});
}

class _NodeProgressAccumulator {
  int practicedSeconds = 0;
  int practicedExerciseCount = 0;
  int completedExerciseCount = 0;
  int totalExerciseCount = 0;
  final Set<String> practicedLessonIds = <String>{};
  final Set<String> completedLessonIds = <String>{};
}
