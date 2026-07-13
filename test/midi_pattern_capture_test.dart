import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/midi_pattern_capture.dart';
import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MidiPatternCaptureController', () {
    test('Record clears the previous capture and generated pattern', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          velocity: 72,
          timestamp: startedAt,
        ),
      );
      expect(controller.stop(), 'R');

      controller.record();

      expect(controller.generatedPattern, isEmpty);
      expect(controller.capturedHits, isEmpty);
      expect(controller.isRecording, true);
    });

    test('Note Off events are ignored', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          messageType: MidiMessageType.noteOff,
          velocity: 90,
          timestamp: startedAt,
        ),
      );

      expect(controller.stop(), isEmpty);
    });

    test('Note On velocity 0 events are ignored', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          velocity: 0,
          timestamp: startedAt,
        ),
      );

      expect(controller.stop(), isEmpty);
    });

    test('a new recording replaces the previous one', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          velocity: 72,
          timestamp: startedAt,
        ),
      );
      expect(controller.stop(), 'R');

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.kick,
          velocity: 72,
          timestamp: startedAt,
        ),
      );

      expect(controller.stop(), 'K');
    });
  });

  group('MidiPatternBuilder', () {
    const MidiPatternBuilder builder = MidiPatternBuilder();

    test('normal hit classification', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 72),
        ]),
        'R',
      );
    });

    test('ghost-note classification', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 24),
        ]),
        '(R)',
      );
    });

    test('accent classification', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 112),
        ]),
        '^R',
      );
    });

    test('simultaneous voices are grouped', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 72),
          _hit(
            DrumVoice.kick,
            velocity: 72,
            offset: const Duration(milliseconds: 10),
          ),
        ]),
        '[RK]',
      );
    });

    test('more than two simultaneous voices can be grouped', () {
      final String pattern = builder.buildPattern(<CapturedMidiHit>[
        _hit(DrumVoice.crash, velocity: 72),
        _hit(
          DrumVoice.snare,
          velocity: 72,
          offset: const Duration(milliseconds: 8),
        ),
        _hit(
          DrumVoice.kick,
          velocity: 72,
          offset: const Duration(milliseconds: 12),
        ),
      ]);

      expect(pattern, '[XRK]');
      expect(() => DrumSheetPatternParser.parse(pattern), returnsNormally);
    });

    test('Stop generates a pattern string accepted by the existing parser', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.hiHatClosed,
            velocity: 72,
            timestamp: startedAt,
          ),
        )
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.snare,
            velocity: 112,
            timestamp: startedAt.add(const Duration(milliseconds: 120)),
          ),
        )
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.kick,
            velocity: 72,
            timestamp: startedAt.add(const Duration(milliseconds: 125)),
          ),
        );

      final String pattern = controller.stop();

      expect(pattern, isNotEmpty);
      expect(() => DrumSheetPatternParser.parse(pattern), returnsNormally);
    });

    test('rendering uses the existing default authoring context', () {
      final String pattern = builder.buildPattern(<CapturedMidiHit>[
        _hit(DrumVoice.hiHatClosed, velocity: 72),
        _hit(
          DrumVoice.snare,
          velocity: 72,
          offset: const Duration(milliseconds: 120),
        ),
      ]);

      final DrumSheetNotationDocument document =
          DrumSheetNotationDocument.fromPattern(pattern);

      expect(document.subdivision, DrumSheetNoteValue.eighth);
      expect(document.feel, DrumSheetFeel.straight);
      expect(document.timeSignature, '4/4');
    });
  });
}

CapturedMidiHit _hit(
  DrumVoice voice, {
  required int velocity,
  Duration offset = Duration.zero,
}) {
  return CapturedMidiHit(voice: voice, velocity: velocity, offset: offset);
}

MidiDiagnosticEvent _diagnosticEvent({
  required DrumVoice voice,
  required int velocity,
  required DateTime timestamp,
  MidiMessageType messageType = MidiMessageType.noteOn,
}) {
  final RawMidiEvent raw = RawMidiEvent(
    deviceId: 'edrum-id',
    deviceName: 'edrum',
    messageType: messageType,
    channel: 10,
    note: 38,
    velocity: velocity,
    timestamp: timestamp,
  );
  return MidiDiagnosticEvent(
    raw: raw,
    drum: DrumInputEvent(
      voice: voice,
      midiNote: raw.note,
      velocity: velocity,
      timestamp: timestamp,
    ),
  );
}
