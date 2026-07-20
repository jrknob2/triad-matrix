import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/midi_pattern_capture.dart';
import 'package:drumcabulary/features/midi/midi_pattern_capture_card.dart';
import 'package:drumcabulary/features/midi/midi_pattern_capture_panel.dart';
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
      expect(controller.stop(), '[S]');

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
      expect(controller.stop(), '[S]');

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.kick,
          velocity: 72,
          timestamp: startedAt,
        ),
      );

      expect(controller.stop(), '[K]');
    });

    test('captures mapped MIDI input without the diagnostic event wrapper', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);
      final RawMidiEvent raw = _rawMidiEvent(
        velocity: 72,
        timestamp: startedAt,
      );

      controller.record();
      controller.captureMappedEvent(
        raw: raw,
        drum: DrumInputEvent(
          voice: DrumVoice.hiHatOpen,
          midiNote: raw.note,
          velocity: raw.velocity,
          timestamp: raw.timestamp,
        ),
      );

      expect(controller.stop(), '[OHH]');
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
        expect(controller.generatedPattern, '[S]');
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
      expect(controller.stop(), '[S]');
      expect(controller.isRecording, false);

      await Future<void>.delayed(const Duration(milliseconds: 130));
      expect(controller.generatedPattern, '[S]');
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

    test('captured voices serialize without inferred sticking', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.snare, velocity: 1),
          _hit(
            DrumVoice.hiHatClosed,
            velocity: 127,
            offset: const Duration(milliseconds: 40),
          ),
        ]),
        '[S] [HH]',
      );
    });

    test('closed and open hi-hat serialize distinctly', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.hiHatClosed, velocity: 90),
          _hit(
            DrumVoice.hiHatOpen,
            velocity: 90,
            offset: const Duration(milliseconds: 40),
          ),
        ]),
        '[HH] [OHH]',
      );
    });

    test('kick and tom voices serialize as canonical voice roots', () {
      expect(
        builder.buildPattern(<CapturedMidiHit>[
          _hit(DrumVoice.kick, velocity: 120),
          _hit(
            DrumVoice.tom2,
            velocity: 127,
            offset: const Duration(milliseconds: 40),
          ),
        ]),
        '[K] [T2]',
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
        '[S K]',
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
        '[S K] [S K]',
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

      expect(pattern, '[CR S K]');
      expect(() => DrumSheetPatternParser.parse(pattern), returnsNormally);
    });

    test('simultaneous open hi-hat and kick serialize together', () {
      final String pattern = builder.buildPattern(<CapturedMidiHit>[
        _hit(DrumVoice.hiHatOpen, velocity: 10),
        _hit(
          DrumVoice.kick,
          velocity: 120,
          offset: const Duration(milliseconds: 8),
        ),
      ]);

      expect(pattern, '[OHH K]');
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
          _controllerWithStoppedPattern('[S]');

      await _pumpCaptureCard(tester, controller);
      await tester.enterText(find.byType(TextField), '[K]');
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
            _controllerWithStoppedPattern('[S]');

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
        expect(display.document.flattenedNotes.single.voices, <DrumSheetVoice>[
          DrumSheetVoice.snare,
        ]);
      },
    );

    testWidgets(
      'Starting Record clears prior text, preview, and validation error',
      (WidgetTester tester) async {
        final MidiPatternCaptureController controller =
            _controllerWithStoppedPattern('[S]');

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
        '[S]',
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

  group('MidiPatternCapturePanel', () {
    testWidgets('shows capture output without pattern editor actions', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          _controllerWithStoppedPattern('[S]');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MidiPatternCapturePanel(
              controller: controller,
              midiStatus: MidiInputStatus.connected,
              message: 'Capture ready.',
              onRecord: () {},
              onStop: () {},
              onClear: () {},
            ),
          ),
        ),
      );

      expect(find.text('MIDI Capture'), findsOneWidget);
      expect(find.text('[S]'), findsOneWidget);
      expect(find.text('Capture ready.'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Replace Pattern'), findsNothing);
      expect(find.text('Append'), findsNothing);
    });

    testWidgets('disables recording when MIDI is disconnected', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MidiPatternCapturePanel(
              controller: controller,
              midiStatus: MidiInputStatus.disconnected,
              message: null,
              onRecord: () {},
              onStop: () {},
              onClear: () {},
            ),
          ),
        ),
      );

      final FilledButton recordButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Record'),
      );
      expect(recordButton.onPressed, isNull);
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
  final RawMidiEvent raw = _rawMidiEvent(
    messageType: messageType,
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

RawMidiEvent _rawMidiEvent({
  required int velocity,
  required DateTime timestamp,
  MidiMessageType messageType = MidiMessageType.noteOn,
}) {
  return RawMidiEvent(
    deviceId: 'edrum-id',
    deviceName: 'edrum',
    messageType: messageType,
    channel: 10,
    note: 38,
    velocity: velocity,
    timestamp: timestamp,
  );
}

MidiPatternCaptureController _controllerWithStoppedPattern(String pattern) {
  final DateTime startedAt = DateTime(2026);
  final MidiPatternCaptureController controller = MidiPatternCaptureController(
    clock: () => startedAt,
  );
  controller.record();
  final DrumVoice voice = pattern.contains('K')
      ? DrumVoice.kick
      : DrumVoice.snare;
  controller.capture(
    _diagnosticEvent(voice: voice, velocity: 72, timestamp: startedAt),
  );
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
