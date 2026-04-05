import '../../core/practice/practice_domain_v1.dart';

String formatDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${duration.inMinutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String formatShortDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  final String year = value.year.toString();
  return '$month/$day/$year';
}

Duration? timerPresetToDuration(TimerPresetV1 preset) {
  return switch (preset) {
    TimerPresetV1.none => null,
    TimerPresetV1.minutes5 => const Duration(minutes: 5),
    TimerPresetV1.minutes10 => const Duration(minutes: 10),
    TimerPresetV1.minutes20 => const Duration(minutes: 20),
    TimerPresetV1.minutes30 => const Duration(minutes: 30),
  };
}

extension MaterialFamilyLabel on MaterialFamilyV1 {
  String get label => switch (this) {
        MaterialFamilyV1.triad => 'Triad',
        MaterialFamilyV1.fiveNote => '5-Note',
        MaterialFamilyV1.custom => 'Custom',
        MaterialFamilyV1.combo => 'Combo',
      };
}

extension PracticeIntentLabel on PracticeIntentV1 {
  String get label => switch (this) {
        PracticeIntentV1.coreSkills => 'Core Skills',
        PracticeIntentV1.flow => 'Flow',
      };
}

extension PracticeContextLabel on PracticeContextV1 {
  String get label => switch (this) {
        PracticeContextV1.singleSurface => 'Single Surface',
        PracticeContextV1.kit => 'Kit',
      };
}

extension CompetencyLabel on CompetencyLevelV1 {
  String get label => switch (this) {
        CompetencyLevelV1.notStarted => 'Not Started',
        CompetencyLevelV1.learning => 'Learning',
        CompetencyLevelV1.comfortable => 'Comfortable',
        CompetencyLevelV1.reliable => 'Reliable',
        CompetencyLevelV1.musical => 'Musical',
      };
}

extension SelfRankLabel on PlayerSelfRankV1 {
  String get label => switch (this) {
        PlayerSelfRankV1.beginner => 'Beginner',
        PlayerSelfRankV1.developing => 'Developing',
        PlayerSelfRankV1.intermediate => 'Intermediate',
        PlayerSelfRankV1.advanced => 'Advanced',
      };
}

extension TimerPresetLabel on TimerPresetV1 {
  String get label => switch (this) {
        TimerPresetV1.none => 'None',
        TimerPresetV1.minutes5 => '5 Minutes',
        TimerPresetV1.minutes10 => '10 Minutes',
        TimerPresetV1.minutes20 => '20 Minutes',
        TimerPresetV1.minutes30 => '30 Minutes',
      };
}

extension FlowFillLengthLabel on FlowFillLengthV1 {
  String get label => switch (this) {
        FlowFillLengthV1.oneBeat => '1 Beat',
        FlowFillLengthV1.twoBeats => '2 Beats',
        FlowFillLengthV1.oneBar => '1 Bar',
        FlowFillLengthV1.twoBars => '2 Bars',
      };
}

extension ReflectionLabel on ReflectionRatingV1 {
  String get label => switch (this) {
        ReflectionRatingV1.easy => 'Easy',
        ReflectionRatingV1.okay => 'Okay',
        ReflectionRatingV1.hard => 'Hard',
      };
}

extension TriadMatrixViewModeLabel on TriadMatrixViewModeV1 {
  String get label => switch (this) {
        TriadMatrixViewModeV1.competency => 'Competency',
        TriadMatrixViewModeV1.lead => 'Lead Hand',
        TriadMatrixViewModeV1.handsOnly => 'Hands Only',
        TriadMatrixViewModeV1.weakHand => 'Weak Hand',
      };
}
