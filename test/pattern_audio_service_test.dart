import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/practice/pattern_audio_service.dart';

void main() {
  group('PatternAudioService.buildPlan', () {
    test('maps grouped simple drills to timed cues', () {
      final PatternAudioPlanV1 plan = PatternAudioService.buildPlan(
        tokens: const <PatternTokenV1>[
          PatternTokenV1.right,
          PatternTokenV1.left,
          PatternTokenV1.kick,
        ],
        markings: const <PatternNoteMarkingV1>[
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
        ],
        voices: const <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
        ],
        grouping: PatternGroupingV1.triads,
        timing: const PatternTimingV1.auto(),
        bpm: 60,
      );

      expect(plan.cycleDuration, const Duration(seconds: 1));
      expect(plan.cues.length, 3);
      expect(plan.cues[0].offset, Duration.zero);
      expect(plan.cues[1].offset, const Duration(microseconds: 333333));
      expect(plan.cues[2].offset, const Duration(microseconds: 666667));
      expect(plan.cues[2].sample, PatternAudioSampleV1.kick);
    });

    test('skips rests and maps voices and dynamics to audible cues', () {
      final PatternAudioPlanV1 plan = PatternAudioService.buildPlan(
        tokens: const <PatternTokenV1>[
          PatternTokenV1.right,
          PatternTokenV1.left,
          PatternTokenV1.rest,
          PatternTokenV1.right,
        ],
        markings: const <PatternNoteMarkingV1>[
          PatternNoteMarkingV1.accent,
          PatternNoteMarkingV1.ghost,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
        ],
        voices: const <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.hihat,
          DrumVoiceV1.snare,
          DrumVoiceV1.floorTom,
        ],
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
        bpm: 120,
      );

      expect(plan.cues.length, 3);
      expect(
        plan.cues.map((PatternAudioCueV1 cue) => cue.tokenIndex).toList(),
        <int>[0, 1, 3],
      );
      expect(plan.cues[0].sample, PatternAudioSampleV1.snareAccent);
      expect(plan.cues[1].sample, PatternAudioSampleV1.hihat);
      expect(plan.cues[2].sample, PatternAudioSampleV1.floorTom);
      expect(plan.cues[1].volume, lessThan(plan.cues[2].volume));
    });

    test('maps expressive tokens without expanding timing positions', () {
      final PatternAudioPlanV1 plan = PatternAudioService.buildPlan(
        tokens: const <PatternTokenV1>[
          PatternTokenV1.flam,
          PatternTokenV1.kick,
          PatternTokenV1.left,
          PatternTokenV1.right,
          PatternTokenV1.kick,
          PatternTokenV1.accent,
          PatternTokenV1.rest,
        ],
        markings: const <PatternNoteMarkingV1>[
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
        ],
        voices: const <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
        ],
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
        bpm: 60,
        accentVoice: AccentVoiceV1.ride,
      );

      expect(plan.cycleDuration, const Duration(seconds: 1));
      expect(plan.cues.length, 6);
      expect(
        plan.cues.map((PatternAudioCueV1 cue) => cue.tokenIndex).toList(),
        <int>[0, 1, 2, 3, 4, 5],
      );
      expect(plan.cues[0].sample, PatternAudioSampleV1.flam);
      expect(plan.cues[5].sample, PatternAudioSampleV1.accentRide);
      expect(plan.cues[5].offset, const Duration(microseconds: 714286));
    });

    test('maps X to the selected accent voice', () {
      PatternAudioPlanV1 planFor(AccentVoiceV1 accentVoice) {
        return PatternAudioService.buildPlan(
          tokens: const <PatternTokenV1>[PatternTokenV1.accent],
          markings: const <PatternNoteMarkingV1>[PatternNoteMarkingV1.normal],
          voices: const <DrumVoiceV1>[DrumVoiceV1.snare],
          grouping: PatternGroupingV1.none,
          timing: const PatternTimingV1.auto(),
          bpm: 60,
          accentVoice: accentVoice,
        );
      }

      expect(
        planFor(AccentVoiceV1.snare).cues.single.sample,
        PatternAudioSampleV1.accentSnare,
      );
      expect(
        planFor(AccentVoiceV1.crash).cues.single.sample,
        PatternAudioSampleV1.accentCrash,
      );
      expect(
        planFor(AccentVoiceV1.ride).cues.single.sample,
        PatternAudioSampleV1.accentRide,
      );
    });

    test('schedules simultaneous hit voices at the same offset', () {
      final PatternAudioPlanV1 plan = PatternAudioService.buildPlan(
        tokens: const <PatternTokenV1>[PatternTokenV1.accent],
        markings: const <PatternNoteMarkingV1>[PatternNoteMarkingV1.normal],
        voices: const <DrumVoiceV1>[DrumVoiceV1.crash],
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
        bpm: 60,
        accentVoice: AccentVoiceV1.crash,
        additionalVoicesByIndex: const <int, List<DrumVoiceV1>>{
          0: <DrumVoiceV1>[DrumVoiceV1.kick],
        },
      );

      expect(plan.cues.length, 2);
      expect(
        plan.cues.map((PatternAudioCueV1 cue) => cue.offset).toSet(),
        <Duration>{Duration.zero},
      );
      expect(
        plan.cues.map((PatternAudioCueV1 cue) => cue.sample).toSet(),
        <PatternAudioSampleV1>{
          PatternAudioSampleV1.accentCrash,
          PatternAudioSampleV1.kick,
        },
      );
    });

    test('uses explicit timing spans for cue offsets', () {
      final PatternAudioPlanV1 plan = PatternAudioService.buildPlan(
        tokens: const <PatternTokenV1>[
          PatternTokenV1.right,
          PatternTokenV1.left,
          PatternTokenV1.left,
          PatternTokenV1.kick,
          PatternTokenV1.right,
        ],
        markings: const <PatternNoteMarkingV1>[
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
          PatternNoteMarkingV1.normal,
        ],
        voices: const <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
          DrumVoiceV1.snare,
        ],
        grouping: PatternGroupingV1.fiveNote,
        timing: const PatternTimingV1.explicit(
          spans: <PatternTimingSpanV1>[
            PatternTimingSpanV1(startIndex: 0, tokenCount: 3, beatCount: 1),
            PatternTimingSpanV1(startIndex: 3, tokenCount: 2, beatCount: 1),
          ],
        ),
        bpm: 60,
      );

      expect(plan.cycleDuration, const Duration(seconds: 2));
      expect(plan.cues[2].offset, const Duration(microseconds: 666667));
      expect(plan.cues[3].offset, const Duration(seconds: 1));
      expect(plan.cues[4].offset, const Duration(milliseconds: 1500));
    });
  });
}
