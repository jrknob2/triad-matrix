import 'package:drumcabulary/features/midi/midi_diagnostic_screen.dart';
import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/midi_pattern_capture.dart';
import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_webview_platform.dart';

void main() {
  setUp(installFakeWebViewPlatform);

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

    test('Record clears the previous tempo estimate', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.snare,
            velocity: 72,
            timestamp: startedAt,
          ),
        )
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.snare,
            velocity: 72,
            timestamp: startedAt.add(const Duration(milliseconds: 250)),
          ),
        );
      controller.stop();
      expect(controller.tempoEstimate?.roundedBpm, 120);

      controller.record();

      expect(controller.tempoEstimate, isNull);
    });

    test('Stop estimates BPM from a short captured pattern', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      for (int index = 0; index < 4; index += 1) {
        controller.capture(
          _diagnosticEvent(
            voice: DrumVoice.hiHatClosed,
            velocity: 72,
            timestamp: startedAt.add(Duration(milliseconds: index * 250)),
          ),
        );
      }
      controller.stop();

      expect(controller.tempoEstimate?.roundedBpm, 120);
      expect(controller.tempoEstimate?.intervalCount, 3);
    });

    test(
      'live MIDI capture updates the generated string before Stop',
      () async {
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

        expect(controller.generatedPattern, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 130));

        expect(controller.isRecording, true);
        expect(controller.generatedPattern, 'R');
      },
    );

    test('Stop performs a final authoritative conversion and render', () async {
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

      expect(controller.generatedPattern, isEmpty);
      expect(controller.stop(), 'R');
      expect(controller.isRecording, false);

      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(controller.generatedPattern, 'R');
    });

    test(
      'rapid MIDI events are not lost while rendering is debounced',
      () async {
        final DateTime startedAt = DateTime(2026);
        final MidiPatternCaptureController controller =
            MidiPatternCaptureController(clock: () => startedAt);

        controller.record();
        for (int index = 0; index < 24; index += 1) {
          controller.capture(
            _diagnosticEvent(
              voice: DrumVoice.snare,
              velocity: 72,
              timestamp: startedAt.add(Duration(milliseconds: index * 40)),
            ),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 130));

        expect(
          DrumSheetPatternParser.parse(controller.generatedPattern),
          hasLength(24),
        );
      },
    );
  });

  group('MidiPatternBuilder', () {
    const MidiPatternBuilder builder = MidiPatternBuilder();

    test('velocity 1-10 maps to ghost', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 1),
          _hit(
            DrumVoice.snare,
            velocity: 10,
            offset: const Duration(milliseconds: 40),
          ),
        ]),
        '(R) (R)',
      );
    });

    test('velocity 11-119 maps to normal', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 11),
          _hit(
            DrumVoice.snare,
            velocity: 119,
            offset: const Duration(milliseconds: 40),
          ),
        ]),
        'R R',
      );
    });

    test('velocity 120-127 maps to accent', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 120),
          _hit(
            DrumVoice.snare,
            velocity: 127,
            offset: const Duration(milliseconds: 40),
          ),
        ]),
        '^R ^R',
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

    test('generated musical events are separated by spaces', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 72),
          _hit(
            DrumVoice.kick,
            velocity: 72,
            offset: const Duration(milliseconds: 8),
          ),
          _hit(
            DrumVoice.snare,
            velocity: 72,
            offset: const Duration(milliseconds: 80),
          ),
          _hit(
            DrumVoice.kick,
            velocity: 72,
            offset: const Duration(milliseconds: 88),
          ),
        ]),
        '[RK] [RK]',
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

    test(
      'simultaneous voices retain independent expression classification',
      () {
        final String pattern = builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 10),
          _hit(
            DrumVoice.kick,
            velocity: 120,
            offset: const Duration(milliseconds: 8),
          ),
        ]);

        expect(pattern, '[(R)^K]');
        expect(() => DrumSheetPatternParser.parse(pattern), returnsNormally);
      },
    );

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
            velocity: 120,
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

    test('estimates BPM from recent eighth-note onset intervals', () {
      final MidiTempoEstimate? estimate = builder
          .estimateTempo(<CapturedMidiHit>[
            _hit(DrumVoice.hiHatClosed, velocity: 72),
            _hit(
              DrumVoice.hiHatClosed,
              velocity: 72,
              offset: const Duration(milliseconds: 250),
            ),
            _hit(
              DrumVoice.hiHatClosed,
              velocity: 72,
              offset: const Duration(milliseconds: 500),
            ),
          ]);

      expect(estimate?.roundedBpm, 120);
      expect(estimate?.intervalCount, 2);
      expect(estimate?.averageOnsetInterval, const Duration(milliseconds: 250));
    });

    test('estimates BPM without counting simultaneous hits as intervals', () {
      final MidiTempoEstimate? estimate = builder
          .estimateTempo(<CapturedMidiHit>[
            _hit(DrumVoice.snare, velocity: 72),
            _hit(
              DrumVoice.kick,
              velocity: 72,
              offset: const Duration(milliseconds: 10),
            ),
            _hit(
              DrumVoice.snare,
              velocity: 72,
              offset: const Duration(milliseconds: 250),
            ),
          ]);

      expect(estimate?.roundedBpm, 120);
      expect(estimate?.intervalCount, 1);
    });

    test('tempo estimate uses the configured rolling interval count', () {
      const MidiPatternBuilder rollingBuilder = MidiPatternBuilder(
        config: MidiPatternCaptureConfig(tempoIntervalSampleCount: 2),
      );

      final MidiTempoEstimate? estimate = rollingBuilder
          .estimateTempo(<CapturedMidiHit>[
            _hit(DrumVoice.snare, velocity: 72),
            _hit(
              DrumVoice.snare,
              velocity: 72,
              offset: const Duration(milliseconds: 500),
            ),
            _hit(
              DrumVoice.snare,
              velocity: 72,
              offset: const Duration(milliseconds: 750),
            ),
            _hit(
              DrumVoice.snare,
              velocity: 72,
              offset: const Duration(milliseconds: 1000),
            ),
          ]);

      expect(estimate?.roundedBpm, 120);
      expect(estimate?.intervalCount, 2);
      expect(estimate?.averageOnsetInterval, const Duration(milliseconds: 250));
    });
  });

  group('MidiPatternCaptureCard', () {
    testWidgets('pattern string is editable when not recording', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController();

      await _pumpCaptureCard(tester, controller);

      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, false);
      expect(find.text('Estimated BPM --'), findsOneWidget);
    });

    testWidgets('pattern string is not editable while recording', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController()..record();

      await _pumpCaptureCard(tester, controller);

      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, true);
    });

    testWidgets('a valid manual edit updates the rendered preview', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          _controllerWithStoppedPattern('R');

      await _pumpCaptureCard(tester, controller);
      await tester.enterText(find.byType(TextField), 'K');
      await tester.pump(const Duration(milliseconds: 250));

      final DrumSheetNotationDisplay display = tester.widget(
        find.byType(DrumSheetNotationDisplay),
      );
      expect(display.document.flattenedNotes.single.voices, <DrumSheetVoice>[
        DrumSheetVoice.kick,
      ]);
    });

    testWidgets(
      'an invalid manual edit preserves text and last valid preview',
      (WidgetTester tester) async {
        final MidiPatternCaptureController controller =
            _controllerWithStoppedPattern('R');

        await _pumpCaptureCard(tester, controller);
        await tester.enterText(find.byType(TextField), '[');
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '[',
        );
        expect(find.text('Unclosed bracket group.'), findsOneWidget);

        final DrumSheetNotationDisplay display = tester.widget(
          find.byType(DrumSheetNotationDisplay),
        );
        expect(display.document.flattenedNotes.single.sticking, 'R');
      },
    );

    testWidgets(
      'Starting Record clears prior text, preview, and validation error',
      (WidgetTester tester) async {
        final MidiPatternCaptureController controller =
            _controllerWithStoppedPattern('R');

        await _pumpCaptureCard(tester, controller);
        await tester.enterText(find.byType(TextField), '[');
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('Unclosed bracket group.'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Record'));
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        expect(find.text('Unclosed bracket group.'), findsNothing);
        final DrumSheetNotationDisplay display = tester.widget(
          find.byType(DrumSheetNotationDisplay),
        );
        expect(display.document.flattenedNotes, isEmpty);
      },
    );

    testWidgets('live MIDI capture updates preview before Stop', (
      WidgetTester tester,
    ) async {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt)..record();

      await _pumpCaptureCard(tester, controller);
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          velocity: 72,
          timestamp: startedAt,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'R',
      );
      expect(find.byType(DrumSheetNotationDisplay), findsOneWidget);
    });

    testWidgets('live MIDI capture updates estimated BPM before Stop', (
      WidgetTester tester,
    ) async {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt)..record();

      await _pumpCaptureCard(tester, controller);
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
            voice: DrumVoice.hiHatClosed,
            velocity: 72,
            timestamp: startedAt.add(const Duration(milliseconds: 250)),
          ),
        );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Estimated BPM 120'), findsOneWidget);
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

MidiPatternCaptureController _controllerWithStoppedPattern(String pattern) {
  final DateTime startedAt = DateTime(2026);
  final MidiPatternCaptureController controller = MidiPatternCaptureController(
    clock: () => startedAt,
  );
  controller.record();
  for (int index = 0; index < pattern.length; index += 1) {
    final String token = pattern[index].toUpperCase();
    final DrumVoice voice = token == 'K' ? DrumVoice.kick : DrumVoice.snare;
    controller.capture(
      _diagnosticEvent(
        voice: voice,
        velocity: 72,
        timestamp: startedAt.add(Duration(milliseconds: index * 40)),
      ),
    );
  }
  controller.stop();
  return controller;
}

Future<void> _pumpCaptureCard(
  WidgetTester tester,
  MidiPatternCaptureController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: <Widget>[MidiPatternCaptureCard(controller: controller)],
        ),
      ),
    ),
  );
  await tester.pump();
}
