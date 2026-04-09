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
    MaterialFamilyV1.warmup => 'Warmup',
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

extension TimerPresetLabel on TimerPresetV1 {
  String get label => switch (this) {
    TimerPresetV1.none => 'None',
    TimerPresetV1.minutes5 => '5 Minutes',
    TimerPresetV1.minutes10 => '10 Minutes',
    TimerPresetV1.minutes20 => '20 Minutes',
    TimerPresetV1.minutes30 => '30 Minutes',
  };
}

extension ReflectionLabel on ReflectionRatingV1 {
  String get label => switch (this) {
    ReflectionRatingV1.easy => 'Easy',
    ReflectionRatingV1.okay => 'Okay',
    ReflectionRatingV1.hard => 'Hard',
  };
}

extension SelfReportControlLabel on SelfReportControlV1 {
  String get label => switch (this) {
    SelfReportControlV1.low => 'Rough',
    SelfReportControlV1.medium => 'Mostly Controlled',
    SelfReportControlV1.high => 'Clean',
  };
}

extension SelfReportTensionLabel on SelfReportTensionV1 {
  String get label => switch (this) {
    SelfReportTensionV1.none => 'Relaxed',
    SelfReportTensionV1.some => 'Some Tension',
    SelfReportTensionV1.high => 'Too Tight',
  };
}

extension SelfReportTempoReadinessLabel on SelfReportTempoReadinessV1 {
  String get label => switch (this) {
    SelfReportTempoReadinessV1.decrease => 'Slow Down',
    SelfReportTempoReadinessV1.same => 'Stay Here',
    SelfReportTempoReadinessV1.increase => 'Bump It Up',
  };
}

extension HandednessLabel on HandednessV1 {
  String get label => switch (this) {
    HandednessV1.right => 'Right Handed',
    HandednessV1.left => 'Left Handed',
  };
}

extension PracticeModeLabel on PracticeModeV1 {
  String get label => switch (this) {
    PracticeModeV1.singleSurface => 'Single Surface',
    PracticeModeV1.flow => 'Flow',
  };
}

extension MatrixProgressStateLabel on MatrixProgressStateV1 {
  String get label => switch (this) {
    MatrixProgressStateV1.notTrained => 'Not Practiced',
    MatrixProgressStateV1.active => 'Active',
    MatrixProgressStateV1.needsWork => 'Needs Work',
    MatrixProgressStateV1.strong => 'Strong',
  };
}

extension LearningLaneLabel on LearningLaneV1 {
  String get label => switch (this) {
    LearningLaneV1.control => 'Control',
    LearningLaneV1.balance => 'Balance',
    LearningLaneV1.dynamics => 'Dynamics',
    LearningLaneV1.integration => 'Integration',
    LearningLaneV1.phrasing => 'Phrasing',
    LearningLaneV1.flow => 'Flow',
  };
}

extension DrumVoiceLabel on DrumVoiceV1 {
  String get shortLabel => switch (this) {
    DrumVoiceV1.snare => 'S',
    DrumVoiceV1.rackTom => 'T1',
    DrumVoiceV1.tom2 => 'T2',
    DrumVoiceV1.floorTom => 'FT',
    DrumVoiceV1.hihat => 'HH',
    DrumVoiceV1.kick => 'K',
  };

  String get label => switch (this) {
    DrumVoiceV1.snare => 'Snare',
    DrumVoiceV1.rackTom => 'Tom 1',
    DrumVoiceV1.tom2 => 'Tom 2',
    DrumVoiceV1.floorTom => 'Floor Tom',
    DrumVoiceV1.hihat => 'Hi-Hat',
    DrumVoiceV1.kick => 'Kick',
  };
}

extension AppMockScenarioLabel on AppMockScenarioV1 {
  String get label => switch (this) {
    AppMockScenarioV1.firstLight => 'First Light',
    AppMockScenarioV1.starterItemsSelected => 'Starter Items Selected',
    AppMockScenarioV1.earlyStruggle => 'Early Struggle',
    AppMockScenarioV1.steadyProgress => 'Steady Progress',
    AppMockScenarioV1.phraseReady => 'Phrase Ready',
    AppMockScenarioV1.flowReady => 'Flow Ready',
  };
}

extension TriadMatrixFilterLabel on TriadMatrixFilterV1 {
  String get label => switch (this) {
    TriadMatrixFilterV1.inRoutine => 'Working On',
    TriadMatrixFilterV1.inPhrases => 'In Phrases',
    TriadMatrixFilterV1.underPracticed => 'Light Time',
    TriadMatrixFilterV1.recent => 'Recent',
    TriadMatrixFilterV1.notTrained => 'Not Practiced',
    TriadMatrixFilterV1.activeStatus => 'Active',
    TriadMatrixFilterV1.needsWorkStatus => 'Needs Work',
    TriadMatrixFilterV1.strongStatus => 'Strong',
    TriadMatrixFilterV1.rightLead => 'Right',
    TriadMatrixFilterV1.leftLead => 'Left',
    TriadMatrixFilterV1.handsOnly => 'Hands Only',
    TriadMatrixFilterV1.hasKick => 'Has Kick',
    TriadMatrixFilterV1.startsWithKick => 'Starts w/ Kick',
    TriadMatrixFilterV1.endsWithKick => 'Ends w/ Kick',
    TriadMatrixFilterV1.doubles => 'Doubles',
  };
}
