import 'package:drumcabulary/features/coach/lesson_notation_document.dart';
import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_plan_loader.dart';
import 'package:drumcabulary/features/practice/pattern_audio_service.dart';
import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads index levels and lessons from multiple files', () async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();

    expect(library.index.version, 1);
    expect(library.index.levels.map((ContentLevel level) => level.id), <String>[
      'beginner',
      'intermediate',
      'advanced',
    ]);
    expect(
      library.lessonsById.keys,
      containsAll(<String>[
        'money-beat',
        'six-stroke-roll',
        'triplet-vocabulary-1',
        'money-beat-triplet-fills',
      ]),
    );
    expect(
      library.lessonsForLevel('beginner').map((Lesson lesson) => lesson.id),
      <String>['money-beat', 'six-stroke-roll'],
    );
    expect(
      library.lessonsForLevel('intermediate').map((Lesson lesson) => lesson.id),
      <String>['triplet-vocabulary-1', 'money-beat-triplet-fills'],
    );
  });

  test('derives skills by level and orders lessons by skill order', () async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();

    expect(library.skillsForLevel('beginner'), <String>[
      'rudiments',
      'grooves',
    ]);
    expect(library.skillsForLevel('intermediate'), <String>[
      'grooves',
      'vocabulary',
    ]);
    expect(
      library
          .lessonsForSkill(levelId: 'intermediate', skill: 'grooves')
          .map((Lesson lesson) => lesson.id),
      <String>['money-beat-triplet-fills'],
    );
    expect(
      library
          .lessonsForSkill(levelId: 'beginner', skill: 'rudiments')
          .map((Lesson lesson) => lesson.id),
      <String>['six-stroke-roll'],
    );
  });

  test('loads Money Beat as progressive exercises', () async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final Lesson lesson = library.lessonsById['money-beat']!;

    expect(lesson.title, 'The Money Beat');
    expect(lesson.level, 'beginner');
    expect(lesson.skill, 'grooves');
    expect(lesson.order, 1);
    expect(
      lesson.exercises.map((LessonExercise exercise) => exercise.id),
      <String>[
        'hh-only',
        'hh-snare',
        'hh-snare-kick',
        'full-loop',
        'crash-resolution',
      ],
    );
    expect(
      lesson.exercises.first.notation.primarySection.pattern,
      '[HH:R][HH:R] [HH:R][HH:R] [HH:R][HH:R] [HH:R][HH:R]',
    );
    expect(lesson.exercises.first.why, contains('timekeeper'));
    expect(lesson.exercises.first.what, contains('closed hi-hat'));
    expect(lesson.exercises.first.how, contains('Count 1 and 2'));
  });

  test('parses exercise notation and preserves audio voices', () async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final Lesson lesson = library.lessonsById['money-beat']!;
    final LessonExercise crashExercise = lesson.exercises.singleWhere(
      (LessonExercise exercise) => exercise.id == 'crash-resolution',
    );

    final DrumSheetNotationDocument document = documentForNotationSection(
      crashExercise.notation.primarySection,
    );
    final List<DrumSheetNotationNote> notes = document.flattenedNotes;
    expect(document.measures, hasLength(4));
    expect(notes, hasLength(32));
    expect(notes[0].voices, <DrumSheetVoice>[
      DrumSheetVoice.hihat,
      DrumSheetVoice.kick,
    ]);
    expect(notes[2].voices, <DrumSheetVoice>[
      DrumSheetVoice.hihat,
      DrumSheetVoice.snare,
    ]);
    expect(notes[24].sticking, 'XK');
    expect(notes[24].voices, <DrumSheetVoice>[
      DrumSheetVoice.crash,
      DrumSheetVoice.kick,
    ]);

    final PatternAudioPlanV1 audioPlan =
        buildSheetNotationAudioPreviewPlanForTesting(document, bpm: 60);
    final Set<PatternAudioSampleV1> crashKickSamples = audioPlan.cues
        .where((PatternAudioCueV1 cue) => cue.tokenIndex == 24)
        .map((PatternAudioCueV1 cue) => cue.sample)
        .toSet();
    expect(crashKickSamples, <PatternAudioSampleV1>{
      PatternAudioSampleV1.accentCrash,
      PatternAudioSampleV1.kick,
    });
  });

  test('loads Six Stroke Roll as a beginner rudiment lesson', () async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final Lesson lesson = library.lessonsById['six-stroke-roll']!;

    expect(lesson.title, 'Six Stroke Roll');
    expect(lesson.level, 'beginner');
    expect(lesson.skill, 'rudiments');
    expect(lesson.order, 5);
    expect(lesson.estimatedMinutes, 40);
    expect(
      lesson.exercises.map((LessonExercise exercise) => exercise.id),
      <String>[
        'learn-the-sticking',
        'add-accents',
        'add-ghost-notes',
        'move-around-the-kit',
        'one-beat-fill',
        'groove-application',
        'creative-application',
      ],
    );

    final ExerciseNotationSection stickingSection =
        lesson.exercises.first.notation.primarySection;
    final List<String> sixStrokeSticking = <String>[
      for (int index = 0; index < 4; index += 1) ...<String>[
        'R',
        'L',
        'L',
        'R',
        'R',
        'L',
      ],
    ];
    expect(stickingSection.subdivision, '16_triplet');
    expect(stickingSection.timeSignature, '4/4');
    expect(stickingSection.sticking, sixStrokeSticking.join(' '));

    final DrumSheetNotationDocument stickingDocument =
        documentForNotationSection(stickingSection);
    expect(stickingDocument.subdivision, DrumSheetNoteValue.sixteenth);
    expect(stickingDocument.feel, DrumSheetFeel.triplet);
    expect(stickingDocument.timeSignature, '4/4');
    expect(stickingDocument.measures, hasLength(1));
    expect(stickingDocument.flattenedNotes, hasLength(24));
    expect(
      stickingDocument.flattenedNotes.any(
        (DrumSheetNotationNote note) => note.rest,
      ),
      isFalse,
    );
    expect(
      stickingDocument.flattenedNotes.map(
        (DrumSheetNotationNote note) => note.sticking,
      ),
      sixStrokeSticking,
    );

    final PatternAudioPlanV1 audioPlan =
        buildSheetNotationAudioPreviewPlanForTesting(stickingDocument, bpm: 60);
    expect(audioPlan.cues, hasLength(192));
    expect(audioPlan.cues[0].offset, Duration.zero);
    expect(audioPlan.cues[1].offset, const Duration(microseconds: 166667));
    expect(audioPlan.cues[6].offset, const Duration(seconds: 1));
    expect(audioPlan.cycleDuration, const Duration(seconds: 32));

    for (final LessonExercise exercise in lesson.exercises) {
      for (final ExerciseNotationSection section
          in exercise.notation.sections) {
        expect(section.timeSignature, isNot('1/4'));
        if (section.subdivision == '16_triplet') {
          final DrumSheetNotationDocument document = documentForNotationSection(
            section,
          );
          expect(
            document.flattenedNotes.any(
              (DrumSheetNotationNote note) => note.rest,
            ),
            isFalse,
            reason: '${exercise.id}.${section.title ?? 'notation'}',
          );
        }
      }
    }

    final LessonExercise grooveApplication = lesson.exercises.singleWhere(
      (LessonExercise exercise) => exercise.id == 'groove-application',
    );
    expect(grooveApplication.notation.sections, hasLength(3));
    expect(grooveApplication.notation.sections[0].title, 'Money Beat');
    expect(grooveApplication.notation.sections[0].repeatCount, 3);
    expect(grooveApplication.notation.sections[1].title, 'Six Stroke Fill');
    expect(
      grooveApplication.notation.sections[1].sticking,
      sixStrokeSticking.join(' '),
    );
    expect(grooveApplication.notation.sections[2].title, 'Beat One Resolution');
  });

  test('preserves sectioned exercise notation and optional sticking', () async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final Lesson lesson = library.lessonsById['money-beat-triplet-fills']!;
    final LessonExercise exercise = lesson.exercises.singleWhere(
      (LessonExercise exercise) => exercise.id == 'groove-three-fill-one',
    );

    expect(exercise.notation.sections, hasLength(2));

    final ExerciseNotationSection grooveSection = exercise.notation.sections[0];
    expect(grooveSection.title, 'Money Beat');
    expect(grooveSection.subdivision, '8');
    expect(grooveSection.timeSignature, '4/4');
    expect(grooveSection.repeatCount, 3);
    expect(shouldShowStickingForNotationSection(grooveSection), isFalse);

    final ExerciseNotationSection fillSection = exercise.notation.sections[1];
    expect(fillSection.title, 'Triplet Fill');
    expect(fillSection.subdivision, 'triplet');
    expect(fillSection.timeSignature, '4/4');
    expect(fillSection.repeatCount, 1);
    expect(fillSection.sticking, 'R L K R K L R L L XK');
    expect(shouldShowStickingForNotationSection(fillSection), isTrue);

    final DrumSheetNotationDocument fillDocument = documentForNotationSection(
      fillSection,
    );
    expect(fillDocument.feel, DrumSheetFeel.triplet);
    expect(fillDocument.subdivision, DrumSheetNoteValue.eighth);
    expect(
      fillDocument.flattenedNotes.where((note) => !note.rest),
      hasLength(10),
    );
    expect(fillDocument.flattenedNotes.last.sticking, 'XK');
  });

  test('parses standalone index and lesson YAML', () {
    final ContentIndex index = LessonPlanLoader.parseIndex(_validIndex);
    expect(index.levels.single.id, 'beginner');

    final Lesson lesson = LessonPlanLoader.parseLesson(_validLesson);
    expect(lesson.id, 'test-lesson');
    expect(lesson.exercises.single.notation.sections, hasLength(1));
    expect(lesson.exercises.single.notation.primarySection.pattern, 'R L');
  });

  test('rejects duplicate lesson IDs in loaded content', () async {
    await expectLater(
      LessonPlanLoader.loadContent(
        bundle: _MapAssetBundle(<String, String>{
          ..._validAssetMap,
          'assets/content/index.yaml': '''
content_index:
  version: 1
  levels:
    - id: beginner
      title: Beginner
      lesson_files:
        - lessons/test.yaml
        - lessons/duplicate.yaml
''',
          'assets/content/lessons/duplicate.yaml': _validLesson,
        }),
      ),
      throwsA(
        isA<LessonPlanLoadException>().having(
          (LessonPlanLoadException error) => error.message,
          'message',
          contains('lesson.id must be unique'),
        ),
      ),
    );
  });

  test('rejects lesson level mismatch from index parent level', () async {
    await expectLater(
      LessonPlanLoader.loadContent(
        bundle: _MapAssetBundle(<String, String>{
          ..._validAssetMap,
          'assets/content/index.yaml': '''
content_index:
  version: 1
  levels:
    - id: intermediate
      title: Intermediate
      lesson_files:
        - lessons/test.yaml
''',
        }),
      ),
      throwsA(
        isA<LessonPlanLoadException>().having(
          (LessonPlanLoadException error) => error.message,
          'message',
          contains('declares level beginner but is listed under intermediate'),
        ),
      ),
    );
  });

  test('rejects duplicate exercise IDs within a lesson', () {
    expect(
      () => LessonPlanLoader.parseLesson('''
lesson:
  id: duplicate-exercises
  title: Duplicate Exercises
  level: beginner
  skill: grooves
  order: 1
  estimated_minutes: 10
  overview: Test duplicate exercise validation.
  objective: Test duplicate exercise validation.
  exercises:
    - id: duplicate
      title: First
      why: Test.
      what: Test.
      how: Test.
      notation:
        pattern: "R L"
    - id: duplicate
      title: Second
      why: Test.
      what: Test.
      how: Test.
      notation:
        pattern: "R L"
'''),
      throwsA(
        isA<LessonPlanLoadException>().having(
          (LessonPlanLoadException error) => error.message,
          'message',
          contains('lesson.exercises.id must be unique'),
        ),
      ),
    );
  });

  test('rejects invalid tempo and repeat count values', () {
    expect(
      () => LessonPlanLoader.parseLesson('''
lesson:
  id: bad-tempo
  title: Bad Tempo
  level: beginner
  skill: grooves
  order: 1
  estimated_minutes: 10
  overview: Test.
  objective: Test.
  exercises:
    - id: bad
      title: Bad
      why: Test.
      what: Test.
      how: Test.
      tempo:
        start: 100
        target: 60
      notation:
        pattern: "R L"
'''),
      throwsA(isA<LessonPlanLoadException>()),
    );

    expect(
      () => LessonPlanLoader.parseLesson('''
lesson:
  id: bad-repeat
  title: Bad Repeat
  level: beginner
  skill: grooves
  order: 1
  estimated_minutes: 10
  overview: Test.
  objective: Test.
  exercises:
    - id: bad
      title: Bad
      why: Test.
      what: Test.
      how: Test.
      notation:
        repeat_count: 0
        pattern: "R L"
'''),
      throwsA(isA<LessonPlanLoadException>()),
    );
  });
}

class _MapAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  _MapAssetBundle(this.assets);

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError(
      'Binary asset loading is not used by these tests.',
    );
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final String? asset = assets[key];
    if (asset == null) {
      throw StateError('Missing test asset: $key');
    }
    return asset;
  }
}

const Map<String, String> _validAssetMap = <String, String>{
  'assets/content/index.yaml': _validIndex,
  'assets/content/lessons/test.yaml': _validLesson,
};

const String _validIndex = '''
content_index:
  version: 1
  levels:
    - id: beginner
      title: Beginner
      lesson_files:
        - lessons/test.yaml
''';

const String _validLesson = '''
lesson:
  id: test-lesson
  title: Test Lesson
  level: beginner
  skill: grooves
  order: 1
  estimated_minutes: 10
  overview: Test one valid lesson.
  objective: Test one valid lesson.
  exercises:
    - id: test-exercise
      title: Test Exercise
      why: Learn the test idea.
      what: Play the test pattern.
      how: Keep the notes even.
      tempo:
        start: 60
        target: 80
      notation:
        subdivision: 8
        time_signature: "4/4"
        pattern: "R L"
''';
