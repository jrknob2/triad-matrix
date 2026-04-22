import '../../core/practice/practice_domain_v1.dart';

class PatternPlaybackEventV1 {
  final int tokenIndex;
  final double startBeat;
  final double beatDuration;

  const PatternPlaybackEventV1({
    required this.tokenIndex,
    required this.startBeat,
    required this.beatDuration,
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

    if (timing.usesExplicitSpans && timing.spans.isNotEmpty) {
      return _planFromExplicitSpans(tokens: tokens, spans: timing.spans);
    }

    return _planFromAutoTiming(tokens: tokens, grouping: grouping);
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
}
