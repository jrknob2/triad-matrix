import 'package:flutter/foundation.dart';

import '../coach/lesson_plan.dart';
import '../coach/lesson_progress.dart';

const int defaultMaxVisibleCompassPoints = 10;

enum CompassNodeKind { curriculum, category, topic, lesson, exercise }

typedef CompassExerciseCallback =
    void Function(String lessonId, String exerciseId);

@immutable
class CurriculumNode {
  final String id;
  final String title;
  final CompassNodeKind kind;
  final String? shortDescription;
  final List<CurriculumNode> children;
  final String lessonFilterId;
  final Lesson? lesson;
  final LessonExercise? exercise;
  final int curriculumOrder;

  const CurriculumNode({
    required this.id,
    required this.title,
    required this.kind,
    this.shortDescription,
    this.children = const <CurriculumNode>[],
    String? lessonFilterId,
    this.lesson,
    this.exercise,
    this.curriculumOrder = 0,
  }) : lessonFilterId = lessonFilterId ?? id;

  bool get hasChildren => children.isNotEmpty;

  List<Lesson> get subtreeLessons {
    final Map<String, Lesson> byId = <String, Lesson>{};
    void collect(CurriculumNode node) {
      final Lesson? lesson = node.lesson;
      if (lesson != null) {
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
  final CompassNodeKind kind;

  const CurriculumBreadcrumb({
    required this.id,
    required this.title,
    required this.kind,
  });
}

@immutable
class CurriculumCompassPoint {
  final String nodeId;
  final String label;
  final CompassNodeKind kind;
  final String? shortDescription;
  final String lessonFilterId;
  final bool hasChildren;
  final String? lessonId;
  final String? exerciseId;
  final int practicedSeconds;
  final int practicedExerciseCount;
  final int practicedLessonCount;
  final int completedExerciseCount;
  final int totalExerciseCount;
  final int completedLessonCount;
  final double progressRatio;

  const CurriculumCompassPoint({
    required this.nodeId,
    required this.label,
    required this.kind,
    this.shortDescription,
    required this.lessonFilterId,
    required this.hasChildren,
    this.lessonId,
    this.exerciseId,
    required this.practicedSeconds,
    required this.practicedExerciseCount,
    required this.practicedLessonCount,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
    required this.completedLessonCount,
    required this.progressRatio,
  });

  bool get hasPractice => practicedSeconds > 0;
  bool get hasCompletions => completedExerciseCount > 0;
  bool get hasExercises => totalExerciseCount > 0;
  bool get isCompleted =>
      hasExercises && completedExerciseCount >= totalExerciseCount;
}

@immutable
class CurriculumCompassSnapshot {
  final CurriculumNode currentNode;
  final List<CurriculumBreadcrumb> breadcrumbs;
  final List<CurriculumCompassPoint> values;
  final int pageIndex;
  final int pageCount;
  final int totalValueCount;
  final int availableChildCount;
  final int maxVisiblePoints;
  final bool valuesFilteredByInteraction;
  final CompassNodeKind? childKind;

  const CurriculumCompassSnapshot({
    required this.currentNode,
    required this.breadcrumbs,
    required this.values,
    this.pageIndex = 0,
    this.pageCount = 0,
    this.totalValueCount = 0,
    this.availableChildCount = 0,
    this.maxVisiblePoints = defaultMaxVisibleCompassPoints,
    this.valuesFilteredByInteraction = false,
    this.childKind,
  });

  bool get hasNodes => values.isNotEmpty;
  bool get isRoot => currentNode.id == CurriculumCompassTreeBuilder.rootId;
  bool get hasPreviousPage => pageIndex > 0;
  bool get hasNextPage => pageIndex + 1 < pageCount;
  bool get hasAvailableContent => availableChildCount > 0;
  bool get hasNoInteraction =>
      valuesFilteredByInteraction && hasAvailableContent && values.isEmpty;
  bool get hasNoContent => !hasAvailableContent;

  bool get hasMetricData {
    return values.any(
      (CurriculumCompassPoint value) =>
          value.progressRatio > 0 || value.hasPractice || value.hasCompletions,
    );
  }
}

class CurriculumCompassAggregator {
  final CurriculumCompassInteractionPolicy interactionPolicy;

  const CurriculumCompassAggregator({
    this.interactionPolicy = const CurriculumCompassInteractionPolicy(),
  });

  CurriculumCompassSnapshot build({
    required CurriculumNode root,
    required List<String> nodePath,
    required LessonProgressService progressService,
    int pageIndex = 0,
    int maxVisiblePoints = defaultMaxVisibleCompassPoints,
  }) {
    final _ResolvedNode resolved = _resolveNode(root, nodePath);
    final List<CurriculumNode> availableChildren = resolved.node.children;
    final CompassNodeKind? childKind = availableChildren.isEmpty
        ? null
        : availableChildren.first.kind;
    final bool filterByInteraction =
        childKind == CompassNodeKind.lesson ||
        childKind == CompassNodeKind.exercise;
    final List<CurriculumNode> orderedChildren = _orderedChildren(
      availableChildren,
      progressService: progressService,
      filterByInteraction: filterByInteraction,
    );
    final int safeMaxVisiblePoints = maxVisiblePoints <= 0
        ? defaultMaxVisibleCompassPoints
        : maxVisiblePoints;
    final int pageCount = orderedChildren.isEmpty
        ? 0
        : ((orderedChildren.length - 1) ~/ safeMaxVisiblePoints) + 1;
    final int safePageIndex = pageCount == 0
        ? 0
        : pageIndex.clamp(0, pageCount - 1).toInt();
    final int start = safePageIndex * safeMaxVisiblePoints;
    final int end = (start + safeMaxVisiblePoints).clamp(
      0,
      orderedChildren.length,
    );
    final List<CurriculumNode> visibleChildren = orderedChildren.sublist(
      start,
      end,
    );

    return CurriculumCompassSnapshot(
      currentNode: resolved.node,
      breadcrumbs: <CurriculumBreadcrumb>[
        const CurriculumBreadcrumb(
          id: CurriculumCompassTreeBuilder.rootId,
          title: 'Curriculum',
          kind: CompassNodeKind.curriculum,
        ),
        for (final CurriculumNode node in resolved.path)
          CurriculumBreadcrumb(id: node.id, title: node.title, kind: node.kind),
      ],
      values: <CurriculumCompassPoint>[
        for (final CurriculumNode child in visibleChildren)
          _valueFor(child, _accumulatorFor(child, progressService)),
      ],
      pageIndex: safePageIndex,
      pageCount: pageCount,
      totalValueCount: orderedChildren.length,
      availableChildCount: availableChildren.length,
      maxVisiblePoints: safeMaxVisiblePoints,
      valuesFilteredByInteraction: filterByInteraction,
      childKind: childKind,
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

  List<CurriculumNode> _orderedChildren(
    List<CurriculumNode> children, {
    required LessonProgressService progressService,
    required bool filterByInteraction,
  }) {
    if (!filterByInteraction) return children;
    final List<CurriculumNode> interacted = <CurriculumNode>[
      for (final CurriculumNode child in children)
        if (interactionPolicy.hasMeaningfulInteraction(child, progressService))
          child,
    ];
    interacted.sort(
      (CurriculumNode a, CurriculumNode b) =>
          interactionPolicy.compare(a, b, progressService),
    );
    return interacted;
  }

  _NodeProgressAccumulator _accumulatorFor(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    if (node.kind == CompassNodeKind.exercise) {
      return _accumulatorForExercise(node, progressService);
    }

    final _NodeProgressAccumulator accumulator = _NodeProgressAccumulator();
    final Set<String> countedExercises = <String>{};
    for (final Lesson lesson in node.subtreeLessons) {
      bool lessonHasPracticedExercise = false;
      bool lessonHasCompletedExercise = false;
      for (final LessonExercise exercise in lesson.exercises) {
        final String exerciseKey = '${lesson.id}/${exercise.id}';
        if (!countedExercises.add(exerciseKey)) continue;
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
      final LessonProgress lessonProgress = progressService.progressForLesson(
        lesson.id,
      );
      if (lessonHasPracticedExercise || lessonProgress.practicedSeconds > 0) {
        accumulator.practicedLessonIds.add(lesson.id);
      }
      if (lessonHasCompletedExercise) {
        accumulator.completedLessonIds.add(lesson.id);
      }
    }
    return accumulator;
  }

  _NodeProgressAccumulator _accumulatorForExercise(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    final Lesson? lesson = node.lesson;
    final LessonExercise? exercise = node.exercise;
    final _NodeProgressAccumulator accumulator = _NodeProgressAccumulator();
    if (lesson == null || exercise == null) return accumulator;
    final ExerciseProgress progress = progressService.progressForExercise(
      lessonId: lesson.id,
      exerciseId: exercise.id,
    );
    accumulator.totalExerciseCount = 1;
    accumulator.practicedSeconds = progress.practicedSeconds;
    if (progress.practicedSeconds > 0) {
      accumulator.practicedExerciseCount = 1;
      accumulator.practicedLessonIds.add(lesson.id);
    }
    if (progress.status == LessonProgressStatus.completed) {
      accumulator.completedExerciseCount = 1;
      accumulator.completedLessonIds.add(lesson.id);
    }
    return accumulator;
  }

  CurriculumCompassPoint _valueFor(
    CurriculumNode node,
    _NodeProgressAccumulator accumulator,
  ) {
    final double progressRatio = accumulator.totalExerciseCount == 0
        ? 0
        : accumulator.completedExerciseCount / accumulator.totalExerciseCount;

    return CurriculumCompassPoint(
      nodeId: node.id,
      label: node.title,
      kind: node.kind,
      shortDescription: node.shortDescription,
      lessonFilterId: node.lessonFilterId,
      hasChildren: node.hasChildren,
      lessonId: node.lesson?.id,
      exerciseId: node.exercise?.id,
      practicedSeconds: accumulator.practicedSeconds,
      practicedExerciseCount: accumulator.practicedExerciseCount,
      practicedLessonCount: accumulator.practicedLessonIds.length,
      completedExerciseCount: accumulator.completedExerciseCount,
      totalExerciseCount: accumulator.totalExerciseCount,
      completedLessonCount: accumulator.completedLessonIds.length,
      progressRatio: progressRatio,
    );
  }
}

class CurriculumCompassInteractionPolicy {
  const CurriculumCompassInteractionPolicy();

  bool hasMeaningfulInteraction(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    return switch (node.kind) {
      CompassNodeKind.lesson => _hasInteractedLesson(node, progressService),
      CompassNodeKind.exercise => _hasInteractedExercise(node, progressService),
      _ => true,
    };
  }

  int compare(
    CurriculumNode a,
    CurriculumNode b,
    LessonProgressService progressService,
  ) {
    final DateTime? aLatest = latestInteraction(a, progressService);
    final DateTime? bLatest = latestInteraction(b, progressService);
    if (aLatest != null || bLatest != null) {
      if (aLatest == null) return 1;
      if (bLatest == null) return -1;
      final int latestComparison = bLatest.compareTo(aLatest);
      if (latestComparison != 0) return latestComparison;
    }

    final int practicedComparison =
        practicedSeconds(b, progressService) -
        practicedSeconds(a, progressService);
    if (practicedComparison != 0) return practicedComparison;

    return a.curriculumOrder.compareTo(b.curriculumOrder);
  }

  DateTime? latestInteraction(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    return switch (node.kind) {
      CompassNodeKind.lesson => _latestLessonInteraction(node, progressService),
      CompassNodeKind.exercise => _latestExerciseInteraction(
        node,
        progressService,
      ),
      _ => null,
    };
  }

  int practicedSeconds(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    return switch (node.kind) {
      CompassNodeKind.lesson => _lessonPracticedSeconds(node, progressService),
      CompassNodeKind.exercise => _exerciseProgress(
        node,
        progressService,
      ).practicedSeconds,
      _ => 0,
    };
  }

  bool _hasInteractedLesson(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    final Lesson? lesson = node.lesson;
    if (lesson == null) return false;
    final LessonProgress progress = progressService.progressForLesson(
      lesson.id,
    );
    if (progress.status != LessonProgressStatus.notStarted ||
        progress.startedAt != null ||
        progress.lastOpenedAt != null ||
        progress.completedAt != null ||
        progress.practicedSeconds > 0) {
      return true;
    }
    return progress.exerciseProgressById.values.any(
      _exerciseProgressInteracted,
    );
  }

  bool _hasInteractedExercise(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    return _exerciseProgressInteracted(
      _exerciseProgress(node, progressService),
    );
  }

  bool _exerciseProgressInteracted(ExerciseProgress progress) {
    return progress.status != LessonProgressStatus.notStarted ||
        progress.startedAt != null ||
        progress.lastPracticedAt != null ||
        progress.completedAt != null ||
        progress.practicedSeconds > 0;
  }

  DateTime? _latestLessonInteraction(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    final Lesson? lesson = node.lesson;
    if (lesson == null) return null;
    final LessonProgress progress = progressService.progressForLesson(
      lesson.id,
    );
    DateTime? latest = _latestOf(
      progress.startedAt,
      progress.lastOpenedAt,
      progress.completedAt,
    );
    for (final ExerciseProgress exerciseProgress
        in progress.exerciseProgressById.values) {
      latest = _maxDate(latest, _latestOfExercise(exerciseProgress));
    }
    return latest;
  }

  DateTime? _latestExerciseInteraction(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    return _latestOfExercise(_exerciseProgress(node, progressService));
  }

  DateTime? _latestOfExercise(ExerciseProgress progress) {
    return _latestOf(
      progress.startedAt,
      progress.lastPracticedAt,
      progress.completedAt,
    );
  }

  int _lessonPracticedSeconds(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    final Lesson? lesson = node.lesson;
    if (lesson == null) return 0;
    final LessonProgress progress = progressService.progressForLesson(
      lesson.id,
    );
    final int exerciseSeconds = progress.exerciseProgressById.values.fold<int>(
      0,
      (int total, ExerciseProgress exerciseProgress) =>
          total + exerciseProgress.practicedSeconds,
    );
    return progress.practicedSeconds > exerciseSeconds
        ? progress.practicedSeconds
        : exerciseSeconds;
  }

  ExerciseProgress _exerciseProgress(
    CurriculumNode node,
    LessonProgressService progressService,
  ) {
    final Lesson? lesson = node.lesson;
    final LessonExercise? exercise = node.exercise;
    if (lesson == null || exercise == null) {
      return ExerciseProgress.notStarted(lessonId: '', exerciseId: '');
    }
    return progressService.progressForExercise(
      lessonId: lesson.id,
      exerciseId: exercise.id,
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
      kind: CompassNodeKind.curriculum,
      children: <CurriculumNode>[
        _node(
          id: 'timing',
          title: 'Timing',
          shortDescription:
              'Build steady pulse, subdivision control, and confident time feel.',
          lessonsBySkill: lessonsBySkill,
          order: 0,
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
          order: 1,
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
          order: 2,
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
          order: 3,
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
          order: 4,
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
          order: 5,
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
          order: 6,
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
          order: 7,
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
          order: 8,
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
          order: 9,
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
    required int order,
  }) {
    return CurriculumNode(
      id: id,
      title: title,
      kind: CompassNodeKind.category,
      shortDescription: shortDescription,
      curriculumOrder: order,
      children: <CurriculumNode>[
        for (final (int index, _TemporaryNodeSpec child) in children.indexed)
          child.toNode(lessonsBySkill, index),
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

  CurriculumNode toNode(Map<String, List<Lesson>> lessonsBySkill, int order) {
    final Map<String, Lesson> lessonsById = <String, Lesson>{};
    for (final String skillId in skillIds) {
      for (final Lesson lesson in lessonsBySkill[skillId] ?? const <Lesson>[]) {
        lessonsById[lesson.id] = lesson;
      }
    }
    final List<Lesson> lessons = lessonsById.values.toList(growable: false)
      ..sort((Lesson a, Lesson b) => a.order.compareTo(b.order));

    return CurriculumNode(
      id: id,
      title: title,
      kind: CompassNodeKind.topic,
      shortDescription: shortDescription,
      curriculumOrder: order,
      lessonFilterId:
          lessonFilterId ?? (skillIds.isEmpty ? id : skillIds.first),
      children: <CurriculumNode>[
        for (final (int index, Lesson lesson) in lessons.indexed)
          _lessonNode(lesson, index),
      ],
    );
  }

  CurriculumNode _lessonNode(Lesson lesson, int order) {
    return CurriculumNode(
      id: 'lesson:${lesson.id}',
      title: lesson.title,
      kind: CompassNodeKind.lesson,
      shortDescription: lesson.overview,
      lessonFilterId: lesson.skill,
      lesson: lesson,
      curriculumOrder: order,
      children: <CurriculumNode>[
        for (final (int index, LessonExercise exercise)
            in lesson.exercises.indexed)
          CurriculumNode(
            id: 'exercise:${lesson.id}:${exercise.id}',
            title: exercise.title,
            kind: CompassNodeKind.exercise,
            shortDescription: exercise.what,
            lessonFilterId: lesson.skill,
            lesson: lesson,
            exercise: exercise,
            curriculumOrder: index,
          ),
      ],
    );
  }
}

DateTime? _latestOf(DateTime? first, DateTime? second, DateTime? third) {
  return _maxDate(_maxDate(first, second), third);
}

DateTime? _maxDate(DateTime? first, DateTime? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first.isAfter(second) ? first : second;
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
