import '../../core/practice/practice_domain_v1.dart';

class PatternPlaybackEventV1 {
  final int tokenIndex;
  final double startBeat;
  final double beatDuration;
  final bool pulseStart;
  final PatternPulseRoleV1 role;

  const PatternPlaybackEventV1({
    required this.tokenIndex,
    required this.startBeat,
    required this.beatDuration,
    this.pulseStart = false,
    this.role = PatternPulseRoleV1.normal,
  });
}

class PatternPlaybackPlanV1 {
  final List<PatternPlaybackEventV1> events;
  final double totalBeatCount;

  const PatternPlaybackPlanV1({
    required this.events,
    required this.totalBeatCount,
  });
}

class PatternPlaybackSchedulerV1 {
  static PatternPlaybackPlanV1 buildPlan({
    required List<PatternTokenV1> tokens,
    required PatternGroupingV1 grouping,
    required PatternTimingV1 timing,
  }) {
    if (tokens.isEmpty) {
      return const PatternPlaybackPlanV1(
        events: <PatternPlaybackEventV1>[],
        totalBeatCount: 0,
      );
    }

    if (timing.hasPulseMetadata) {
      return _planFromPulseMetadata(tokens: tokens, pulses: timing.pulses);
    }

    if (timing.usesExplicitSpans && timing.spans.isNotEmpty) {
      return _planFromExplicitSpans(tokens: tokens, spans: timing.spans);
    }

    return _planFromPulseMetadata(
      tokens: tokens,
      pulses: _deriveDefaultPulseMetadata(tokens),
    );
  }

  static int? activeTokenIndex({
    required List<PatternTokenV1> tokens,
    required PatternGroupingV1 grouping,
    required PatternTimingV1 timing,
    required Duration elapsed,
    required int bpm,
  }) {
    if (tokens.isEmpty || bpm <= 0 || elapsed.isNegative) return null;
    final PatternPlaybackPlanV1 plan = buildPlan(
      tokens: tokens,
      grouping: grouping,
      timing: timing,
    );
    if (plan.events.isEmpty || plan.totalBeatCount <= 0) return null;

    final double beatsElapsed =
        elapsed.inMicroseconds / (Duration.microsecondsPerMinute / bpm);
    final double beatInCycle = beatsElapsed % plan.totalBeatCount;

    for (final PatternPlaybackEventV1 event in plan.events) {
      final double eventEnd = event.startBeat + event.beatDuration;
      if (beatInCycle >= event.startBeat && beatInCycle < eventEnd) {
        return event.tokenIndex;
      }
    }

    return plan.events.last.tokenIndex;
  }

  static PatternPlaybackPlanV1 _planFromAutoTiming({
    required List<PatternTokenV1> tokens,
    required PatternGroupingV1 grouping,
  }) {
    final int? groupSize = grouping.groupSize;
    if (groupSize != null && tokens.length % groupSize == 0) {
      final List<PatternPlaybackEventV1> events = <PatternPlaybackEventV1>[];
      double beatCursor = 0;
      for (int start = 0; start < tokens.length; start += groupSize) {
        final double tokenBeatDuration = 1 / groupSize;
        for (int offset = 0; offset < groupSize; offset++) {
          events.add(
            PatternPlaybackEventV1(
              tokenIndex: start + offset,
              startBeat: beatCursor + (offset * tokenBeatDuration),
              beatDuration: tokenBeatDuration,
              pulseStart: offset == 0,
            ),
          );
        }
        beatCursor += 1;
      }
      return PatternPlaybackPlanV1(events: events, totalBeatCount: beatCursor);
    }

    final List<PatternPlaybackEventV1> events =
        List<PatternPlaybackEventV1>.generate(
          tokens.length,
          (int index) => PatternPlaybackEventV1(
            tokenIndex: index,
            startBeat: index.toDouble(),
            beatDuration: 1,
            pulseStart: true,
          ),
          growable: false,
        );
    return PatternPlaybackPlanV1(
      events: events,
      totalBeatCount: tokens.length.toDouble(),
    );
  }

  static PatternPlaybackPlanV1 _planFromExplicitSpans({
    required List<PatternTokenV1> tokens,
    required List<PatternTimingSpanV1> spans,
  }) {
    final List<PatternPlaybackEventV1> events = <PatternPlaybackEventV1>[];
    double beatCursor = 0;

    for (final PatternTimingSpanV1 span in spans) {
      if (span.startIndex < 0 ||
          span.startIndex >= tokens.length ||
          span.tokenCount <= 0 ||
          span.startIndex + span.tokenCount > tokens.length ||
          span.beatCount <= 0) {
        continue;
      }
      final double tokenBeatDuration = span.beatCount / span.tokenCount;
      for (int offset = 0; offset < span.tokenCount; offset++) {
        events.add(
          PatternPlaybackEventV1(
            tokenIndex: span.startIndex + offset,
            startBeat: beatCursor + (offset * tokenBeatDuration),
            beatDuration: tokenBeatDuration,
            pulseStart: offset == 0,
          ),
        );
      }
      beatCursor += span.beatCount;
    }

    if (events.isEmpty || beatCursor <= 0) {
      return _planFromAutoTiming(
        tokens: tokens,
        grouping: PatternGroupingV1.none,
      );
    }

    return PatternPlaybackPlanV1(events: events, totalBeatCount: beatCursor);
  }

  static PatternPlaybackPlanV1 _planFromPulseMetadata({
    required List<PatternTokenV1> tokens,
    required List<PatternPulseMetadataV1> pulses,
  }) {
    final List<PatternPulseMetadataV1> normalized =
        List<PatternPulseMetadataV1>.generate(tokens.length, (int index) {
          if (index < pulses.length) return pulses[index];
          return const PatternPulseMetadataV1();
        }, growable: false);
    if (!normalized.any((PatternPulseMetadataV1 pulse) => pulse.pulseStart)) {
      normalized[0] = normalized[0].copyWith(pulseStart: true);
    }

    final int normalEnd = normalized.indexWhere(
      (PatternPulseMetadataV1 pulse) => pulse.role == PatternPulseRoleV1.tag,
    );
    final int normalTokenEnd = normalEnd == -1 ? tokens.length : normalEnd;
    final List<int> pulseStarts = <int>[];
    for (int index = 0; index < normalTokenEnd; index++) {
      if (normalized[index].pulseStart) {
        pulseStarts.add(index);
      }
    }
    if (pulseStarts.isEmpty || pulseStarts.first != 0) {
      pulseStarts.insert(0, 0);
    }

    final List<PatternPlaybackEventV1> events = <PatternPlaybackEventV1>[];
    double beatCursor = 0;
    double previousSubdivision = 1;

    for (int pulseIndex = 0; pulseIndex < pulseStarts.length; pulseIndex++) {
      final int start = pulseStarts[pulseIndex];
      final int end = pulseIndex + 1 < pulseStarts.length
          ? pulseStarts[pulseIndex + 1]
          : normalTokenEnd;
      final int tokenCount = end - start;
      if (tokenCount <= 0) continue;
      final double tokenBeatDuration = 1 / tokenCount;
      previousSubdivision = tokenBeatDuration;
      for (int offset = 0; offset < tokenCount; offset++) {
        final int tokenIndex = start + offset;
        events.add(
          PatternPlaybackEventV1(
            tokenIndex: tokenIndex,
            startBeat: beatCursor + (offset * tokenBeatDuration),
            beatDuration: tokenBeatDuration,
            pulseStart: offset == 0,
            role: normalized[tokenIndex].role,
          ),
        );
      }
      beatCursor += 1;
    }

    for (int index = normalTokenEnd; index < tokens.length; index++) {
      events.add(
        PatternPlaybackEventV1(
          tokenIndex: index,
          startBeat: beatCursor,
          beatDuration: previousSubdivision,
          role: PatternPulseRoleV1.tag,
        ),
      );
      beatCursor += previousSubdivision;
    }

    if (events.isEmpty || beatCursor <= 0) {
      return _planFromAutoTiming(
        tokens: tokens,
        grouping: PatternGroupingV1.none,
      );
    }
    return PatternPlaybackPlanV1(events: events, totalBeatCount: beatCursor);
  }

  static List<PatternPulseMetadataV1> _deriveDefaultPulseMetadata(
    List<PatternTokenV1> tokens,
  ) {
    final List<PatternPulseMetadataV1> pulses =
        List<PatternPulseMetadataV1>.generate(
          tokens.length,
          (_) => const PatternPulseMetadataV1(),
          growable: false,
        );
    if (tokens.isEmpty) return pulses;
    pulses[0] = const PatternPulseMetadataV1(pulseStart: true);

    if (tokens.length == 6) {
      pulses[3] = const PatternPulseMetadataV1(pulseStart: true);
      return pulses;
    }

    if (tokens.length == 7 &&
        tokens[0] == tokens[3] &&
        tokens[1] == tokens[4] &&
        tokens[2] == tokens[5]) {
      pulses[3] = const PatternPulseMetadataV1(pulseStart: true);
      pulses[6] = const PatternPulseMetadataV1(role: PatternPulseRoleV1.tag);
      return pulses;
    }

    return pulses;
  }
}
