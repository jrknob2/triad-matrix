import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/music/canonical_musical_document.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';

TimedMusicalEvent event(
  String id,
  MusicalTime onset,
  MusicalTime duration, {
  MusicalTime? written,
  String layer = 'main',
  bool rest = false,
}) => TimedMusicalEvent(
  id: id,
  onset: onset,
  duration: duration,
  writtenDuration: written,
  layerId: layer,
  isRest: rest,
  strikes: rest ? [] : [InstrumentStrike(voice: DrumVoiceV1.snare)],
);

CanonicalMusicalDocument document(
  List<TimedMusicalEvent> events, {
  List<PhraseGroup> phrases = const [],
  List<TupletGroup> tuplets = const [],
  List<MusicalMeasure>? measures,
}) => CanonicalMusicalDocument(
  timeSignature: MusicalTimeSignature(4, 4),
  events: events,
  phraseGroups: phrases,
  tupletGroups: tuplets,
  measures:
      measures ??
      [
        MusicalMeasure(
          id: 'm0',
          onset: MusicalTime.zero,
          duration: events.map((e) => e.end).reduce((a, b) => a > b ? a : b),
          timeSignature: MusicalTimeSignature(4, 4),
          isIncomplete:
              events.map((e) => e.end).reduce((a, b) => a > b ? a : b) <
              MusicalTime(4),
        ),
      ],
);

void main() {
  test('measure boundaries reject crossing events and short active layers', () {
    final measures = [
      for (var i = 0; i < 2; i++)
        MusicalMeasure(
          id: 'm$i',
          onset: MusicalTime(i * 4),
          duration: MusicalTime(4),
          timeSignature: MusicalTimeSignature(4, 4),
        ),
    ];
    expect(
      () => document([
        event('a', MusicalTime.zero, MusicalTime(5)),
        event('b', MusicalTime(5), MusicalTime(3)),
      ], measures: measures),
      throwsArgumentError,
    );
    expect(
      () => document([
        event('a', MusicalTime.zero, MusicalTime(4), layer: 'a'),
        event('b', MusicalTime.zero, MusicalTime(1), layer: 'b'),
      ]),
      throwsArgumentError,
    );
  });

  test(
    'group identity, ordered membership and tuplet overlap are validated',
    () {
      final events = [
        for (var i = 0; i < 3; i++)
          event(
            'e$i',
            MusicalTime(i, 3),
            MusicalTime(1, 3),
            written: MusicalTime(1, 2),
          ),
      ];
      final tuplet = TupletGroup(
        id: 't',
        eventIds: ['e0', 'e1', 'e2'],
        actual: 3,
        normal: 2,
      );
      for (final members in [
        <String>[],
        ['e0', 'e0'],
        ['e1', 'e0'],
      ]) {
        expect(
          () => document(
            events,
            tuplets: [tuplet],
            phrases: [PhraseGroup(id: 'p', eventIds: members)],
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => document(
          events,
          tuplets: [tuplet],
          phrases: [
            PhraseGroup(id: 't', eventIds: ['e0']),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => document(
          events,
          tuplets: [
            tuplet,
            TupletGroup(
              id: 't2',
              eventIds: ['e0'],
              actual: 3,
              normal: 2,
              isIncomplete: true,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => TupletGroup(id: 'bad', eventIds: ['e0'], actual: 0, normal: 2),
        throwsArgumentError,
      );
    },
  );

  test('unsupported schemas are rejected explicitly', () {
    final original = document([event('e', MusicalTime.zero, MusicalTime(1))]);
    expect(
      () => CanonicalMusicalDocument(
        schemaVersion: 2,
        timeSignature: original.timeSignature,
        events: original.events,
        measures: original.measures,
      ),
      throwsArgumentError,
    );
  });

  test('rational arithmetic normalizes, compares and never rounds', () {
    expect(MusicalTime(2, 6), MusicalTime(1, 3));
    expect(MusicalTime(1, 3) + MusicalTime(1, 6), MusicalTime(1, 2));
    expect(MusicalTime(1, 3) * MusicalTime(3), MusicalTime(1));
    expect(MusicalTime(1) / MusicalTime(5), MusicalTime(1, 5));
    expect(MusicalTime(1) - MusicalTime(3, 4), MusicalTime(1, 4));
    expect(MusicalTime(-1, -3), MusicalTime(1, 3));
    expect(MusicalTime(1, 3) > MusicalTime(1, 4), isTrue);
    final huge = BigInt.parse('10000000000000000000000000000000000000001');
    expect(
      MusicalTime.fromBigInts(huge, BigInt.one) + MusicalTime(1),
      MusicalTime.fromBigInts(huge + BigInt.one, BigInt.one),
    );
    expect(() => MusicalTime(1, 0), throwsArgumentError);
    expect(() => MusicalTime(1) / MusicalTime.zero, throwsArgumentError);
  });

  for (final count in [4, 8, 16]) {
    test('$count ordinary notes fill 4/4 exactly', () {
      final duration = MusicalTime(4, count);
      final doc = document([
        for (var i = 0; i < count; i++)
          event('e$i', duration * MusicalTime(i), duration),
      ]);
      expect(doc.events.last.end, MusicalTime(4));
      expect(doc.measures.single.isIncomplete, isFalse);
    });
  }

  test('phrase size five never creates a tuplet', () {
    final events = [
      for (var i = 0; i < 5; i++)
        event('e$i', MusicalTime(i, 4), MusicalTime(1, 4)),
    ];
    final plain = document(events);
    final grouped = document(
      events,
      phrases: [
        PhraseGroup(
          id: 'p',
          eventIds: events.map((e) => e.id).toList(),
          label: '5',
        ),
      ],
    );
    expect(
      grouped.events.map((e) => e.duration),
      plain.events.map((e) => e.duration),
    );
    expect(grouped.events.last.end, MusicalTime(5, 4));
    expect(grouped.tupletGroups, isEmpty);
  });

  test('5:4 sixteenth quintuplet has exact one-beat duration', () {
    final group = TupletGroup(
      id: 't',
      eventIds: [for (var i = 0; i < 5; i++) 'e$i'],
      actual: 5,
      normal: 4,
    );
    final duration = group.scaleDuration(MusicalTime(1, 4));
    expect(duration, MusicalTime(1, 5));
    final doc = document(
      [
        for (var i = 0; i < 5; i++)
          event(
            'e$i',
            duration * MusicalTime(i),
            duration,
            written: MusicalTime(1, 4),
          ),
      ],
      tuplets: [group],
    );
    expect(doc.events.last.end, MusicalTime(1));
    expect(
      () => document(
        [
          for (var i = 0; i < 5; i++)
            event('e$i', MusicalTime(i, 4), MusicalTime(1, 4)),
        ],
        tuplets: [group],
      ),
      throwsArgumentError,
    );
  });

  test('phrase groups cross beats and measures without affecting time', () {
    final events = [
      for (var i = 0; i < 8; i++) event('e$i', MusicalTime(i), MusicalTime(1)),
    ];
    final doc = document(
      events,
      phrases: [
        PhraseGroup(id: 'p', eventIds: ['e2', 'e3', 'e4', 'e5'], label: '4'),
      ],
      measures: [
        for (var i = 0; i < 2; i++)
          MusicalMeasure(
            id: 'm$i',
            onset: MusicalTime(i * 4),
            duration: MusicalTime(4),
            timeSignature: MusicalTimeSignature(4, 4),
          ),
      ],
    );
    expect(doc.events.last.end, MusicalTime(8));
    expect(doc.phraseGroups.single.eventIds, ['e2', 'e3', 'e4', 'e5']);
  });

  test('events have deterministic ordering by onset, layer, then ID', () {
    final a = event('a', MusicalTime.zero, MusicalTime(1), layer: 'a');
    final b = event('b', MusicalTime.zero, MusicalTime(1), layer: 'b');
    expect(document([b, a]).events.map((e) => e.id), ['a', 'b']);
    expect(document([a, b]).events.map((e) => e.id), ['a', 'b']);
  });

  test(
    'invalid event time and rest/strike combinations fail in release too',
    () {
      expect(
        () => event('e', MusicalTime.zero, MusicalTime.zero),
        throwsArgumentError,
      );
      expect(
        () => event('e', MusicalTime.zero, MusicalTime(-1)),
        throwsArgumentError,
      );
      expect(
        () => event('e', MusicalTime(-1), MusicalTime(1)),
        throwsArgumentError,
      );
      expect(
        () => TimedMusicalEvent(
          id: 'e',
          onset: MusicalTime.zero,
          duration: MusicalTime(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => TimedMusicalEvent(
          id: 'e',
          onset: MusicalTime.zero,
          duration: MusicalTime(1),
          isRest: true,
          strikes: [InstrumentStrike(voice: DrumVoiceV1.kick)],
        ),
        throwsArgumentError,
      );
    },
  );

  test('duplicate IDs, dangling groups, implicit gaps and overlaps fail', () {
    final first = event('e', MusicalTime.zero, MusicalTime(1));
    expect(
      () => document([first, event('e', MusicalTime(1), MusicalTime(1))]),
      throwsArgumentError,
    );
    expect(
      () => document(
        [first],
        phrases: [
          PhraseGroup(id: 'p', eventIds: ['missing']),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => document([first, event('b', MusicalTime(2), MusicalTime(1))]),
      throwsArgumentError,
    );
    expect(
      () => document([first, event('b', MusicalTime(1, 2), MusicalTime(1))]),
      throwsArgumentError,
    );
    expect(
      () => document([
        event(
          'a',
          MusicalTime.zero,
          MusicalTime(1, 3),
          written: MusicalTime(1, 2),
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('incomplete measures must be explicit and overflow is rejected', () {
    expect(
      () => MusicalMeasure(
        id: 'm',
        onset: MusicalTime.zero,
        duration: MusicalTime(1),
        timeSignature: MusicalTimeSignature(4, 4),
      ),
      throwsArgumentError,
    );
    expect(
      () => MusicalMeasure(
        id: 'm',
        onset: MusicalTime.zero,
        duration: MusicalTime(5),
        timeSignature: MusicalTimeSignature(4, 4),
        isIncomplete: true,
      ),
      throwsArgumentError,
    );
    expect(() => MusicalTimeSignature(4, 3), throwsArgumentError);
    expect(
      document([
        event('e', MusicalTime.zero, MusicalTime(1)),
      ]).measures.single.isIncomplete,
      isTrue,
    );
  });

  test('collections and extension metadata are defensively immutable', () {
    final metadata = <String, String>{'test:technique': 'rimshot'};
    final strike = InstrumentStrike(
      voice: DrumVoiceV1.snare,
      articulationMetadata: metadata,
    );
    metadata.clear();
    expect(strike.articulationMetadata['test:technique'], 'rimshot');
    expect(() => strike.articulationMetadata.clear(), throwsUnsupportedError);
    final strikes = [strike];
    final e = TimedMusicalEvent(
      id: 'e',
      onset: MusicalTime.zero,
      duration: MusicalTime(1),
      strikes: strikes,
    );
    strikes.clear();
    expect(e.strikes, hasLength(1));
    final events = [e];
    final members = ['e'];
    final phrase = PhraseGroup(id: 'p', eventIds: members);
    final doc = document(events, phrases: [phrase]);
    events.clear();
    members.clear();
    expect(doc.events, hasLength(1));
    expect(phrase.eventIds, ['e']);
    expect(() => doc.events.clear(), throwsUnsupportedError);
    expect(() => phrase.eventIds.clear(), throwsUnsupportedError);
    expect(() => doc.measures.clear(), throwsUnsupportedError);
  });
}
