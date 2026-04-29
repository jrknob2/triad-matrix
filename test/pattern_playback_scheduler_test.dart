import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/practice/pattern_playback_scheduler.dart';

void main() {
  group('PatternPlaybackSchedulerV1 pulse-map defaults', () {
    test('maps RLLRLLK as two triad pulses plus a tag', () {
      final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
        tokens: PatternSequenceV1.parse('RLLRLLK').tokens,
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
      );

      expect(
        plan.events
            .where((PatternPlaybackEventV1 event) => event.pulseStart)
            .map((PatternPlaybackEventV1 event) => event.tokenIndex),
        <int>[0, 3],
      );
      expect(plan.events[6].role, PatternPulseRoleV1.tag);
      expect(plan.events[6].startBeat, 2);
      expect(plan.events[6].beatDuration, closeTo(1 / 3, 0.000001));
      expect(plan.totalBeatCount, closeTo(2 + (1 / 3), 0.000001));
    });

    test('maps three tokens as one pulse evenly inside one beat', () {
      final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
        tokens: PatternSequenceV1.parse('RLK').tokens,
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
      );

      expect(plan.totalBeatCount, 1);
      expect(plan.events[0].pulseStart, isTrue);
      expect(plan.events[1].startBeat, closeTo(1 / 3, 0.000001));
      expect(plan.events[2].startBeat, closeTo(2 / 3, 0.000001));
    });

    test('maps four tokens as one pulse evenly inside one beat', () {
      final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
        tokens: PatternSequenceV1.parse('RLRL').tokens,
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
      );

      expect(plan.totalBeatCount, 1);
      expect(
        plan.events.singleWhere((event) => event.pulseStart).tokenIndex,
        0,
      );
      expect(plan.events[3].startBeat, 0.75);
    });

    test('maps five tokens as one pulse evenly inside one beat', () {
      final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
        tokens: PatternSequenceV1.parse('RLRKL').tokens,
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
      );

      expect(plan.totalBeatCount, 1);
      expect(
        plan.events.singleWhere((event) => event.pulseStart).tokenIndex,
        0,
      );
      expect(plan.events[4].startBeat, 0.8);
    });

    test('maps six tokens as two three-token pulse spans', () {
      final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
        tokens: PatternSequenceV1.parse('RLLRLL').tokens,
        grouping: PatternGroupingV1.none,
        timing: const PatternTimingV1.auto(),
      );

      expect(
        plan.events
            .where((PatternPlaybackEventV1 event) => event.pulseStart)
            .map((PatternPlaybackEventV1 event) => event.tokenIndex),
        <int>[0, 3],
      );
      expect(plan.totalBeatCount, 2);
      expect(plan.events[3].startBeat, 1);
    });

    test('uses explicit pulse metadata when present', () {
      final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
        tokens: PatternSequenceV1.parse('RLRK').tokens,
        grouping: PatternGroupingV1.none,
        timing: PatternTimingV1(
          pulses: <PatternPulseMetadataV1>[
            PatternPulseMetadataV1(pulseStart: true),
            PatternPulseMetadataV1(),
            PatternPulseMetadataV1(pulseStart: true),
            PatternPulseMetadataV1(role: PatternPulseRoleV1.tag),
          ],
        ),
      );

      expect(
        plan.events
            .where((PatternPlaybackEventV1 event) => event.pulseStart)
            .map((PatternPlaybackEventV1 event) => event.tokenIndex),
        <int>[0, 2],
      );
      expect(plan.events[3].role, PatternPulseRoleV1.tag);
      expect(plan.events[3].beatDuration, 1);
    });
  });
}
