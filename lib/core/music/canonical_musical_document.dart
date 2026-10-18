import '../practice/practice_domain_v1.dart';

/// Exact quarter-note beats. BigInt keeps arithmetic exact on native and web.
final class MusicalTime implements Comparable<MusicalTime> {
  final BigInt numerator;
  final BigInt denominator;

  factory MusicalTime(int numerator, [int denominator = 1]) =>
      MusicalTime.fromBigInts(BigInt.from(numerator), BigInt.from(denominator));

  factory MusicalTime.fromBigInts(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError('Musical time denominator must be nonzero.');
    }
    if (denominator.isNegative) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final divisor = numerator.gcd(denominator);
    return MusicalTime._(numerator ~/ divisor, denominator ~/ divisor);
  }

  const MusicalTime._(this.numerator, this.denominator);
  static final zero = MusicalTime(0);
  bool get isNegative => numerator.isNegative;
  bool get isPositive => numerator > BigInt.zero;
  MusicalTime operator +(MusicalTime other) => MusicalTime.fromBigInts(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
  MusicalTime operator -(MusicalTime other) => MusicalTime.fromBigInts(
    numerator * other.denominator - other.numerator * denominator,
    denominator * other.denominator,
  );
  MusicalTime operator *(MusicalTime other) => MusicalTime.fromBigInts(
    numerator * other.numerator,
    denominator * other.denominator,
  );
  MusicalTime operator /(MusicalTime other) => MusicalTime.fromBigInts(
    numerator * other.denominator,
    denominator * other.numerator,
  );
  @override
  int compareTo(MusicalTime other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
  bool operator <(MusicalTime other) => compareTo(other) < 0;
  bool operator >(MusicalTime other) => compareTo(other) > 0;
  bool operator <=(MusicalTime other) => compareTo(other) <= 0;
  bool operator >=(MusicalTime other) => compareTo(other) >= 0;
  @override
  bool operator ==(Object other) =>
      other is MusicalTime &&
      numerator == other.numerator &&
      denominator == other.denominator;
  @override
  int get hashCode => Object.hash(numerator, denominator);
  @override
  String toString() =>
      denominator == BigInt.one ? '$numerator' : '$numerator/$denominator';
}

final class MusicalTimeSignature {
  final int numerator;
  final int denominator;
  MusicalTimeSignature(this.numerator, this.denominator) {
    if (numerator <= 0 ||
        denominator <= 0 ||
        (denominator & (denominator - 1)) != 0) {
      throw ArgumentError(
        'Time signature requires a positive numerator and power-of-two denominator.',
      );
    }
  }
  MusicalTime get duration =>
      MusicalTime(numerator) * MusicalTime(4, denominator);
}

enum MusicalHand { left, right }

enum StrikeArticulation { normal, accent, ghost }

final class InstrumentStrike {
  /// Reuses the existing domain voice vocabulary; no second instrument registry.
  final DrumVoiceV1 voice;
  final MusicalHand? hand;
  final StrikeArticulation articulation;

  /// Namespaced string values allow extensions without mutable nested objects.
  final Map<String, String> articulationMetadata;
  InstrumentStrike({
    required this.voice,
    this.hand,
    this.articulation = StrikeArticulation.normal,
    Map<String, String> articulationMetadata = const {},
  }) : articulationMetadata = Map.unmodifiable(articulationMetadata);
}

final class TimedMusicalEvent {
  final String id;
  final MusicalTime onset;
  final MusicalTime duration;

  /// Unscaled note value, also in quarter-note beats.
  final MusicalTime writtenDuration;
  final List<InstrumentStrike> strikes;
  final bool isRest;
  final String layerId;
  TimedMusicalEvent({
    required this.id,
    required this.onset,
    required this.duration,
    MusicalTime? writtenDuration,
    List<InstrumentStrike> strikes = const [],
    this.isRest = false,
    this.layerId = 'main',
  }) : writtenDuration = writtenDuration ?? duration,
       strikes = List.unmodifiable(strikes) {
    if (id.isEmpty ||
        layerId.isEmpty ||
        onset.isNegative ||
        !duration.isPositive ||
        !this.writtenDuration.isPositive ||
        (isRest ? this.strikes.isNotEmpty : this.strikes.isEmpty)) {
      throw ArgumentError(
        'Invalid event identity, time, or rest/strike combination.',
      );
    }
  }
  MusicalTime get end => onset + duration;
}

final class MusicalMeasure {
  final String id;
  final MusicalTime onset;
  final MusicalTime duration;
  final MusicalTimeSignature timeSignature;
  final bool isIncomplete;
  MusicalMeasure({
    required this.id,
    required this.onset,
    required this.duration,
    required this.timeSignature,
    this.isIncomplete = false,
  }) {
    if (id.isEmpty ||
        onset.isNegative ||
        !duration.isPositive ||
        duration > timeSignature.duration ||
        (isIncomplete
            ? duration == timeSignature.duration
            : duration != timeSignature.duration)) {
      throw ArgumentError(
        'Measure overflow or undeclared/incorrect incomplete measure.',
      );
    }
  }
  MusicalTime get end => onset + duration;
}

final class PhraseGroup {
  final String id;
  final List<String> eventIds;
  final String? label;
  final String? displayIntent;
  PhraseGroup({
    required this.id,
    required List<String> eventIds,
    this.label,
    this.displayIntent,
  }) : eventIds = List.unmodifiable(eventIds);
}

final class TupletGroup {
  final String id;
  final List<String> eventIds;
  final int actual;
  final int normal;

  /// An explicitly partial tuplet, e.g. a fragment under legacy triplet feel.
  final bool isIncomplete;
  TupletGroup({
    required this.id,
    required List<String> eventIds,
    required this.actual,
    required this.normal,
    this.isIncomplete = false,
  }) : eventIds = List.unmodifiable(eventIds) {
    if (actual <= 0 ||
        normal <= 0 ||
        actual == normal ||
        (isIncomplete
            ? eventIds.isEmpty || eventIds.length >= actual
            : eventIds.length != actual)) {
      throw ArgumentError('Invalid tuplet ratio or membership count.');
    }
  }
  MusicalTime get scale => MusicalTime(normal, actual);
  MusicalTime scaleDuration(MusicalTime writtenDuration) =>
      writtenDuration * scale;
}

final class CanonicalMusicalDocument {
  static const currentSchemaVersion = 1;
  final int schemaVersion;
  final MusicalTimeSignature timeSignature;
  final List<TimedMusicalEvent> events;
  final List<MusicalMeasure> measures;
  final List<PhraseGroup> phraseGroups;
  final List<TupletGroup> tupletGroups;

  CanonicalMusicalDocument({
    this.schemaVersion = currentSchemaVersion,
    required this.timeSignature,
    required List<TimedMusicalEvent> events,
    required List<MusicalMeasure> measures,
    List<PhraseGroup> phraseGroups = const [],
    List<TupletGroup> tupletGroups = const [],
  }) : events = List.unmodifiable(
         List<TimedMusicalEvent>.of(events)..sort(_order),
       ),
       measures = List.unmodifiable(measures),
       phraseGroups = List.unmodifiable(phraseGroups),
       tupletGroups = List.unmodifiable(tupletGroups) {
    _validate();
  }

  static int _order(TimedMusicalEvent a, TimedMusicalEvent b) {
    final time = a.onset.compareTo(b.onset);
    if (time != 0) return time;
    final layer = a.layerId.compareTo(b.layerId);
    return layer != 0 ? layer : a.id.compareTo(b.id);
  }

  void _validate() {
    if (schemaVersion != currentSchemaVersion ||
        measures.isEmpty ||
        events.isEmpty) {
      throw ArgumentError('Unsupported schema or empty musical document.');
    }
    final byId = <String, TimedMusicalEvent>{};
    for (final event in events) {
      if (byId.containsKey(event.id)) {
        throw ArgumentError('Duplicate event ID: ${event.id}');
      }
      byId[event.id] = event;
    }
    final measureIds = <String>{};
    var cursor = MusicalTime.zero;
    for (final measure in measures) {
      if (!measureIds.add(measure.id) ||
          measure.onset != cursor ||
          measure.timeSignature.numerator != timeSignature.numerator ||
          measure.timeSignature.denominator != timeSignature.denominator) {
        throw ArgumentError(
          'Measures must have unique IDs, contiguous boundaries and the document meter.',
        );
      }
      cursor = measure.end;
      final layerEnds = <String, MusicalTime>{};
      for (final event in events.where(
        (e) => e.onset >= measure.onset && e.onset < measure.end,
      )) {
        if (event.end > measure.end ||
            event.onset != (layerEnds[event.layerId] ?? measure.onset)) {
          throw ArgumentError(
            'Event crosses a boundary, overlaps, or leaves an implicit rest: ${event.id}',
          );
        }
        layerEnds[event.layerId] = event.end;
      }
      if (layerEnds.isEmpty ||
          layerEnds.values.any((end) => end != measure.end)) {
        throw ArgumentError(
          'Measure layers must cover their declared duration with events or rests.',
        );
      }
    }
    if (events.any((e) => e.end > cursor)) {
      throw ArgumentError('Event outside measures.');
    }

    final groupIds = <String>{};
    void validateGroup(String id, List<String> members) {
      if (id.isEmpty ||
          !groupIds.add(id) ||
          members.isEmpty ||
          members.toSet().length != members.length ||
          members.any((id) => !byId.containsKey(id))) {
        throw ArgumentError('Invalid group identity or event references: $id');
      }
      var previous = -1;
      for (final member in members) {
        final index = events.indexWhere((e) => e.id == member);
        if (index <= previous) {
          throw ArgumentError('Group members must follow event order.');
        }
        previous = index;
      }
    }

    for (final group in phraseGroups) {
      validateGroup(group.id, group.eventIds);
    }
    final ratios = <String, MusicalTime>{};
    for (final group in tupletGroups) {
      validateGroup(group.id, group.eventIds);
      TimedMusicalEvent? previous;
      for (final id in group.eventIds) {
        final event = byId[id]!;
        if (ratios.containsKey(id) ||
            (previous != null &&
                (event.layerId != previous.layerId ||
                    event.onset != previous.end))) {
          throw ArgumentError(
            'Overlapping, nested, or noncontiguous tuplets are unsupported.',
          );
        }
        ratios[id] = group.scale;
        previous = event;
      }
    }
    for (final event in events) {
      if (event.duration !=
          event.writtenDuration * (ratios[event.id] ?? MusicalTime(1))) {
        throw ArgumentError(
          'Event duration disagrees with explicit tuplet timing: ${event.id}',
        );
      }
    }
  }
}
