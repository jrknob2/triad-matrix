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
    for (final ExerciseNotationSection section in exercise.notation.sections) {
      events.addAll(_eventsForSection(section));
    }
    return List<GuidedPracticeExpectedEvent>.unmodifiable(events);
  }

  List<GuidedPracticeExpectedEvent> _eventsForSection(
    ExerciseNotationSection section,
  ) {
    final PatternAudioPlanV1 plan = buildSheetNotationAudioPreviewPlan(
      documentForNotationSection(section),
    );
    final List<GuidedPracticeExpectedEvent> events =
        <GuidedPracticeExpectedEvent>[];
    Duration? currentOffset;
    final List<DrumVoice> currentVoices = <DrumVoice>[];

    void flush() {
      if (currentVoices.isEmpty) return;
      final GuidedPracticeExpectedEvent event = GuidedPracticeExpectedEvent(
        currentVoices,
      );
      if (!event.isEmpty) events.add(event);
      currentVoices.clear();
    }

    for (final PatternAudioCueV1 cue in plan.cues) {
      if (currentOffset == null || cue.offset != currentOffset) {
        flush();
        currentOffset = cue.offset;
      }
      currentVoices.add(midiDrumVoiceForPlaybackVoice(cue.voice));
    }
    flush();
    return events;
  }
}
