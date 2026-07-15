import 'package:drumcabulary/features/midi/bounded_midi_event_log.dart';
import 'package:drumcabulary/features/midi/drum_kit_mapper.dart';
import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/raw_midi_message_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawMidiMessageParser', () {
    test('parses Note On status bytes', () {
      final RawMidiMessageParser parser = RawMidiMessageParser();

      final RawMidiEvent event = parser
          .parsePacket(
            data: <int>[0x99, 38, 104],
            deviceId: 'edrum-id',
            deviceName: 'edrum',
            timestamp: DateTime(2026),
          )
          .single;

      expect(event.messageType, MidiMessageType.noteOn);
      expect(event.channel, 10);
      expect(event.note, 38);
      expect(event.velocity, 104);
      expect(event.deviceName, 'edrum');
    });

    test('parses Note Off status bytes', () {
      final RawMidiMessageParser parser = RawMidiMessageParser();

      final RawMidiEvent event = parser
          .parsePacket(
            data: <int>[0x89, 38, 0],
            deviceId: 'edrum-id',
            deviceName: 'edrum',
            timestamp: DateTime(2026),
          )
          .single;

      expect(event.messageType, MidiMessageType.noteOff);
      expect(event.channel, 10);
      expect(event.note, 38);
      expect(event.velocity, 0);
    });

    test('treats Note On with velocity 0 as Note Off', () {
      final RawMidiMessageParser parser = RawMidiMessageParser();

      final RawMidiEvent event = parser
          .parsePacket(
            data: <int>[0x99, 38, 0],
            deviceId: 'edrum-id',
            deviceName: 'edrum',
            timestamp: DateTime(2026),
          )
          .single;

      expect(event.messageType, MidiMessageType.noteOff);
      expect(event.channel, 10);
      expect(event.note, 38);
      expect(event.velocity, 0);
    });

    test('extracts one-based channel numbers', () {
      final RawMidiMessageParser parser = RawMidiMessageParser();

      final RawMidiEvent firstChannel = parser
          .parsePacket(
            data: <int>[0x90, 36, 90],
            deviceId: 'edrum-id',
            deviceName: 'edrum',
            timestamp: DateTime(2026),
          )
          .single;
      final RawMidiEvent sixteenthChannel = parser
          .parsePacket(
            data: <int>[0x9F, 36, 90],
            deviceId: 'edrum-id',
            deviceName: 'edrum',
            timestamp: DateTime(2026),
          )
          .single;

      expect(firstChannel.channel, 1);
      expect(sixteenthChannel.channel, 16);
    });

    test('extracts control change channel, controller, and value', () {
      final RawMidiMessageParser parser = RawMidiMessageParser();

      final RawMidiEvent event = parser
          .parsePacket(
            data: <int>[0xB9, 4, 64],
            deviceId: 'edrum-id',
            deviceName: 'edrum',
            timestamp: DateTime(2026),
          )
          .single;

      expect(event.messageType, MidiMessageType.controlChange);
      expect(event.channel, 10);
      expect(event.note, 4);
      expect(event.velocity, 64);
    });
  });

  group('DrumKitMapper', () {
    test('maps known General MIDI notes to drum voices', () {
      const DrumKitMapper mapper = DrumKitMapper();

      final DrumInputEvent drumEvent = mapper.map(
        _rawEvent(note: 38, velocity: 104),
      );

      expect(drumEvent.voice, DrumVoice.snare);
      expect(drumEvent.midiNote, 38);
      expect(drumEvent.velocity, 104);
    });

    test('maps LEKATO tom 2 note 45 to tom2', () {
      const DrumKitMapper mapper = DrumKitMapper();

      final DrumInputEvent drumEvent = mapper.map(
        _rawEvent(note: 45, velocity: 96),
      );

      expect(drumEvent.voice, DrumVoice.tom2);
      expect(drumEvent.midiNote, 45);
      expect(drumEvent.velocity, 96);
    });

    test('maps unknown notes to DrumVoice.unknown', () {
      const DrumKitMapper mapper = DrumKitMapper();

      final DrumInputEvent drumEvent = mapper.map(
        _rawEvent(note: 12, velocity: 90),
      );

      expect(drumEvent.voice, DrumVoice.unknown);
      expect(drumEvent.midiNote, 12);
    });
  });

  group('BoundedMidiEventLog', () {
    test('keeps only the configured maximum number of events', () {
      final BoundedMidiEventLog log = BoundedMidiEventLog(maxEntries: 3);
      const DrumKitMapper mapper = DrumKitMapper();

      for (int note = 36; note < 41; note += 1) {
        final RawMidiEvent raw = _rawEvent(note: note, velocity: 90);
        log.add(MidiDiagnosticEvent(raw: raw, drum: mapper.map(raw)));
      }

      expect(log.events, hasLength(3));
      expect(log.events.first.raw.note, 38);
      expect(log.events.last.raw.note, 40);
    });

    test('clears the current event log', () {
      final BoundedMidiEventLog log = BoundedMidiEventLog(maxEntries: 3);
      const DrumKitMapper mapper = DrumKitMapper();
      final RawMidiEvent raw = _rawEvent(note: 38, velocity: 90);
      log.add(MidiDiagnosticEvent(raw: raw, drum: mapper.map(raw)));

      log.clear();

      expect(log.events, isEmpty);
    });
  });
}

RawMidiEvent _rawEvent({required int note, required int velocity}) {
  return RawMidiEvent(
    deviceId: 'edrum-id',
    deviceName: 'edrum',
    messageType: MidiMessageType.noteOn,
    channel: 10,
    note: note,
    velocity: velocity,
    timestamp: DateTime(2026),
  );
}
