import '../coach/lesson_notation_document.dart';
import '../coach/lesson_plan.dart';
import '../midi/led_frame_command_encoder.dart';
import '../practice/pattern_audio_service.dart';
import '../practice/playback_drum_voice_mapper.dart';
import '../practice/widgets/sheet_notation_display.dart';
import 'guided_practice_controller.dart';

class GuidedPracticeSequenceBuilder {
  const GuidedPracticeSequenceBuilder();

  List<GuidedPracticeExpectedEvent> buildForExercise(LessonExercise exercise) {
    final List<GuidedPracticeExpectedEvent> events =
        <GuidedPracticeExpectedEvent>[];
    for (
      int sectionIndex = 0;
      sectionIndex < exercise.notation.sections.length;
      sectionIndex += 1
    ) {
      events.addAll(
        _eventsForSection(
          exercise.notation.sections[sectionIndex],
          sectionIndex: sectionIndex,
        ),
      );
    }
    return List<GuidedPracticeExpectedEvent>.unmodifiable(events);
  }

  List<GuidedPracticeExpectedEvent> _eventsForSection(
    ExerciseNotationSection section, {
    required int sectionIndex,
  }) {
    final DrumSheetAudioPreviewPlan previewPlan =
        buildSheetNotationAudioPreviewPlanDetails(
          documentForNotationSection(section),
        );
    final PatternAudioPlanV1 plan = previewPlan.audioPlan;
    final List<GuidedPracticeExpectedEvent> events =
        <GuidedPracticeExpectedEvent>[];
    Duration? currentOffset;
    final List<LedCue> currentCues = <LedCue>[];
    final Set<int> currentSelectedIndexes = <int>{};

    void flush() {
      if (currentCues.isEmpty) return;
      final GuidedPracticeExpectedEvent event =
          GuidedPracticeExpectedEvent.fromCues(
            currentCues,
            sectionIndex: sectionIndex,
            selectedIndexes: currentSelectedIndexes,
          );
      if (!event.isEmpty) events.add(event);
      currentCues.clear();
      currentSelectedIndexes.clear();
    }

    for (final PatternAudioCueV1 cue in plan.cues) {
      if (currentOffset == null || cue.offset != currentOffset) {
        flush();
        currentOffset = cue.offset;
      }
      currentCues.add(
        LedCue(
          midiDrumVoiceForPlaybackVoice(cue.voice),
          sticking: cue.sticking,
        ),
      );
      final int? displayIndex = previewPlan.displayIndexForTokenIndex(
        cue.tokenIndex,
      );
      if (displayIndex != null) currentSelectedIndexes.add(displayIndex);
    }
    flush();
    return events;
  }
}
