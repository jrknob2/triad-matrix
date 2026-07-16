import '../coach/lesson_notation_document.dart';
import '../coach/lesson_plan.dart';
import '../midi/midi_input_models.dart';
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
    final List<DrumVoice> currentVoices = <DrumVoice>[];
    final Set<int> currentSelectedIndexes = <int>{};

    void flush() {
      if (currentVoices.isEmpty) return;
      final GuidedPracticeExpectedEvent event = GuidedPracticeExpectedEvent(
        currentVoices,
        sectionIndex: sectionIndex,
        selectedIndexes: currentSelectedIndexes,
      );
      if (!event.isEmpty) events.add(event);
      currentVoices.clear();
      currentSelectedIndexes.clear();
    }

    for (final PatternAudioCueV1 cue in plan.cues) {
      if (currentOffset == null || cue.offset != currentOffset) {
        flush();
        currentOffset = cue.offset;
      }
      currentVoices.add(midiDrumVoiceForPlaybackVoice(cue.voice));
      final int? displayIndex = previewPlan.displayIndexForTokenIndex(
        cue.tokenIndex,
      );
      if (displayIndex != null) currentSelectedIndexes.add(displayIndex);
    }
    flush();
    return events;
  }
}
