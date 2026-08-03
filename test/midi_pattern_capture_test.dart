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

    test(
      'captures velocity accents and ghosts through the live entrypoint',
      () {
        final DateTime startedAt = DateTime(2026);
        final MidiPatternCaptureController controller =
            MidiPatternCaptureController(clock: () => startedAt);
        final RawMidiEvent raw = _rawMidiEvent(
          velocity: 120,
          timestamp: startedAt,
        );

        controller.record();
        controller
          ..captureMappedEvent(
            raw: raw,
            drum: DrumInputEvent(
              voice: DrumVoice.snare,
              midiNote: raw.note,
              velocity: raw.velocity,
              timestamp: raw.timestamp,
            ),
          )
          ..captureMappedEvent(
            raw: _rawMidiEvent(
              velocity: 24,
              timestamp: startedAt.add(const Duration(milliseconds: 80)),
            ),
            drum: DrumInputEvent(
              voice: DrumVoice.snare,
              midiNote: raw.note,
              velocity: 24,
              timestamp: startedAt.add(const Duration(milliseconds: 80)),
            ),
          )
          ..captureMappedEvent(
            raw: _rawMidiEvent(
              velocity: 28,
              timestamp: startedAt.add(const Duration(milliseconds: 160)),
            ),
            drum: DrumInputEvent(
              voice: DrumVoice.snare,
              midiNote: raw.note,
              velocity: 28,
              timestamp: startedAt.add(const Duration(milliseconds: 160)),
            ),
          );

        expect(controller.stop(), '[S:^R(L)(L)]');
      },
    );

    test('normal capture velocities do not invent sticking', () {
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
            velocity: 74,
            timestamp: startedAt.add(const Duration(milliseconds: 80)),
          ),
        );

      expect(controller.stop(), '[S] [S]');
    });

    test(
      'default velocity threshold boundaries classify accents and ghosts',
      () {
        final DateTime startedAt = DateTime(2026);
        final MidiPatternCaptureController controller =
            MidiPatternCaptureController(clock: () => startedAt);

        controller.record();
        controller
          ..capture(
            _diagnosticEvent(
              voice: DrumVoice.snare,
              velocity: 99,
              timestamp: startedAt,
            ),
          )
          ..capture(
            _diagnosticEvent(
              voice: DrumVoice.snare,
              velocity: 100,
              timestamp: startedAt.add(const Duration(milliseconds: 80)),
            ),
          )
          ..capture(
            _diagnosticEvent(
              voice: DrumVoice.snare,
              velocity: 64,
              timestamp: startedAt.add(const Duration(milliseconds: 160)),
            ),
          )
          ..capture(
            _diagnosticEvent(
              voice: DrumVoice.snare,
              velocity: 63,
              timestamp: startedAt.add(const Duration(milliseconds: 240)),
            ),
          );

        expect(controller.stop(), '[S] [S:^R] [S] [S:(L)]');
      },
    );

    test('kick capture does not invent hand sticking from velocity', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.kick,
            velocity: 127,
            timestamp: startedAt,
          ),
        )
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.kick,
            velocity: 10,
            timestamp: startedAt.add(const Duration(milliseconds: 80)),
          ),
        );

      expect(controller.stop(), '[K] [K]');
    });

    test('velocity thresholds are configurable', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(
            clock: () => startedAt,
            builder: const MidiPatternBuilder(
              config: MidiPatternCaptureConfig(
                ghostVelocityMaximum: 35,
                accentVelocityMinimum: 100,
              ),
            ),
          );

      controller.record();
      controller
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.snare,
            velocity: 99,
            timestamp: startedAt,
          ),
        )
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.snare,
            velocity: 100,
            timestamp: startedAt.add(const Duration(milliseconds: 80)),
          ),
        )
        ..capture(
          _diagnosticEvent(
            voice: DrumVoice.snare,
            velocity: 35,
            timestamp: startedAt.add(const Duration(milliseconds: 160)),
          ),
        );

      expect(controller.stop(), '[S] [S:^R(L)]');
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

    test('captured structured strokes serialize as one voice-first phrase', () {
      final String pattern = builder.buildPattern(<CapturedMidiHit>[
        _hit(
          DrumVoice.snare,
          velocity: 120,
          stroke: _stroke(
            DrumSheetStrokeHand.right,
            articulation: DrumSheetStrokeArticulation.accent,
          ),
        ),
        _hit(
          DrumVoice.snare,
          velocity: 24,
          offset: const Duration(milliseconds: 80),
          stroke: _stroke(
            DrumSheetStrokeHand.left,
            articulation: DrumSheetStrokeArticulation.ghost,
          ),
        ),
        _hit(
          DrumVoice.snare,
          velocity: 28,
          offset: const Duration(milliseconds: 160),
          stroke: _stroke(
            DrumSheetStrokeHand.left,
            articulation: DrumSheetStrokeArticulation.ghost,
          ),
        ),
      ]);

      expect(pattern, '[S:^R(L)(L)]');
      final List<DrumSheetNotationNote> notes = DrumSheetPatternParser.parse(
        pattern,
      );
      expect(notes, hasLength(3));
      expect(notes[0].accent, isTrue);
      expect(notes[1].ghost, isTrue);
      expect(notes[2].ghost, isTrue);
    });

    test('captured simultaneous structured voices serialize together', () {
      final String pattern = builder.buildPattern(<CapturedMidiHit>[
        _hit(
          DrumVoice.hiHatClosed,
          velocity: 80,
          stroke: _stroke(DrumSheetStrokeHand.right),
        ),
        _hit(
          DrumVoice.snare,
          velocity: 88,
          offset: const Duration(milliseconds: 8),
          stroke: _stroke(DrumSheetStrokeHand.left),
        ),
      ]);

      expect(pattern, '[HH:R S:L]');
      expect(() => DrumSheetPatternParser.parse(pattern), returnsNormally);
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

    test('default capture config frames one 4/4 measure in auto tempo', () {
      const MidiPatternCaptureConfig config = MidiPatternCaptureConfig();

      expect(config.timeSignature, '4/4');
      expect(config.measureCount, 1);
      expect(config.tempoMode, MidiPatternCaptureTempoMode.auto);
      expect(config.autoStopWhenRecognized, isTrue);
      expect(config.simultaneousWindow, const Duration(milliseconds: 30));
    });

    test('fixed tempo repeated cycles collapse to the recognized pattern', () {
      const MidiPatternBuilder fixedBuilder = MidiPatternBuilder(
        config: MidiPatternCaptureConfig(
          tempoMode: MidiPatternCaptureTempoMode.fixed,
          fixedBpm: 60,
          timeSignature: '4/4',
          measureCount: 1,
          autoStopWhenRecognized: false,
        ),
      );

      final CapturedPatternResult result = fixedBuilder.analyzePattern(
        _repeatedSixteenthPhrase(repetitions: 3),
      );

      expect(result.recognized, isTrue);
      expect(result.repetitionCount, 3);
      expect(result.pattern, '[S:^R(L)(L)]');
      expect(result.subdivision, DrumSheetNoteValue.sixteenth);
      expect(result.feel, DrumSheetFeel.straight);
    });

    test(
      'recognition tolerates one missing hit and one accidental extra hit',
      () {
        const MidiPatternBuilder fixedBuilder = MidiPatternBuilder(
          config: MidiPatternCaptureConfig(
            tempoMode: MidiPatternCaptureTempoMode.fixed,
            fixedBpm: 60,
            autoStopWhenRecognized: false,
          ),
        );
        final List<CapturedMidiHit> hits =
            _repeatedSixteenthPhrase(
              repetitions: 4,
              skipLastGhostInRepetition: 2,
            )..add(
              _hit(
                DrumVoice.kick,
                velocity: 90,
                offset: const Duration(milliseconds: 5100),
              ),
            );

        final CapturedPatternResult result = fixedBuilder.analyzePattern(hits);

        expect(result.recognized, isTrue);
        expect(result.pattern, '[S:^R(L)(L)]');
      },
    );
  });

  group('MidiPatternCaptureController recognition state', () {
    test('preserves raw MIDI events until capture is cleared', () {
      final DateTime startedAt = DateTime(2026);
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController(clock: () => startedAt);

      controller.record();
      controller.capture(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          messageType: MidiMessageType.noteOff,
          velocity: 64,
          timestamp: startedAt.add(const Duration(milliseconds: 12)),
        ),
      );

      expect(controller.rawEvents, hasLength(1));
      expect(controller.capturedHits, isEmpty);

      controller.clear();

      expect(controller.rawEvents, isEmpty);
    });

    test(
      'recognized fixed-cycle capture enters finishing cycle once',
      () async {
        final DateTime startedAt = DateTime(2026);
        int recognitionSignals = 0;
        final MidiPatternCaptureController controller =
            MidiPatternCaptureController(
              clock: () => startedAt,
              recognitionSignal: () async {
                recognitionSignals += 1;
              },
            );
        const MidiPatternCaptureConfig config = MidiPatternCaptureConfig(
          tempoMode: MidiPatternCaptureTempoMode.fixed,
          fixedBpm: 60,
          liveUpdateInterval: Duration(milliseconds: 1),
        );

        controller.record(config);
        for (final CapturedMidiHit hit in _repeatedSixteenthPhrase(
          repetitions: 3,
        )) {
          controller.capture(
            _diagnosticEvent(
              voice: hit.voice,
              velocity: hit.velocity,
              timestamp: startedAt.add(hit.offset),
            ),
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(controller.result?.recognized, isTrue);
        expect(controller.status, MidiPatternCaptureStatus.finishingCycle);
        expect(recognitionSignals, 1);

        controller.clear();
      },
    );
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

    testWidgets('recording is disabled when MIDI is disconnected', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController();

      await _pumpCaptureCard(
        tester,
        controller,
        midiStatus: MidiInputStatus.disconnected,
      );

      final FilledButton recordButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Record'),
      );
      expect(recordButton.onPressed, isNull);
      expect(find.text('Connect MIDI input'), findsNothing);
    });

    testWidgets('device status chips are not duplicated in capture', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          MidiPatternCaptureController();

      await _pumpCaptureCard(
        tester,
        controller,
        midiStatus: MidiInputStatus.connected,
      );

      expect(find.text('MIDI connected'), findsNothing);
      expect(find.text('LED controller'), findsNothing);
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

    testWidgets('Create Exercise emits the current valid notation', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          _controllerWithStoppedPattern('[S]');
      final List<String> createdPatterns = <String>[];

      await _pumpCaptureCard(
        tester,
        controller,
        onCreateExercise: createdPatterns.add,
      );
      await tester.enterText(find.byType(TextField), '[K]');
      await tester.pump(const Duration(milliseconds: 250));

      final FilledButton createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create Exercise'),
      );
      createButton.onPressed!();
      await tester.pump();

      expect(createdPatterns, <String>['[K]']);
    });

    testWidgets('invalid notation blocks Create Exercise handoff', (
      WidgetTester tester,
    ) async {
      final MidiPatternCaptureController controller =
          _controllerWithStoppedPattern('[S]');
      final List<String> createdPatterns = <String>[];

      await _pumpCaptureCard(
        tester,
        controller,
        onCreateExercise: createdPatterns.add,
      );
      await tester.enterText(find.byType(TextField), '[');
      await tester.pump(const Duration(milliseconds: 250));

      final FilledButton createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create Exercise'),
      );
      expect(createButton.onPressed, isNull);
      expect(createdPatterns, isEmpty);
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
  DrumSheetStrokeDescriptor? stroke,
}) {
  return CapturedMidiHit(
    voice: voice,
    velocity: velocity,
    offset: offset,
    stroke: stroke,
  );
}

List<CapturedMidiHit> _repeatedSixteenthPhrase({
  required int repetitions,
  int? skipLastGhostInRepetition,
}) {
  const Duration cycle = Duration(milliseconds: 4000);
  final List<CapturedMidiHit> hits = <CapturedMidiHit>[];
  for (int repetition = 0; repetition < repetitions; repetition += 1) {
    final Duration base = Duration(
      microseconds: cycle.inMicroseconds * repetition,
    );
    hits.add(
      _hit(
        DrumVoice.snare,
        velocity: 120,
        offset: base,
        stroke: _stroke(
          DrumSheetStrokeHand.right,
          articulation: DrumSheetStrokeArticulation.accent,
        ),
      ),
    );
    hits.add(
      _hit(
        DrumVoice.snare,
        velocity: 28,
        offset: base + const Duration(milliseconds: 250),
        stroke: _stroke(
          DrumSheetStrokeHand.left,
          articulation: DrumSheetStrokeArticulation.ghost,
        ),
      ),
    );
    if (skipLastGhostInRepetition == repetition) continue;
    hits.add(
      _hit(
        DrumVoice.snare,
        velocity: 30,
        offset: base + const Duration(milliseconds: 500),
        stroke: _stroke(
          DrumSheetStrokeHand.left,
          articulation: DrumSheetStrokeArticulation.ghost,
        ),
      ),
    );
  }
  return hits;
}

DrumSheetStrokeDescriptor _stroke(
  DrumSheetStrokeHand hand, {
  DrumSheetStrokeArticulation articulation = DrumSheetStrokeArticulation.normal,
}) {
  return DrumSheetStrokeDescriptor(hand: hand, articulation: articulation);
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
  MidiPatternCaptureController controller, {
  MidiInputStatus? midiStatus,
  ValueChanged<String>? onCreateExercise,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: <Widget>[
            MidiPatternCaptureCard(
              controller: controller,
              midiStatus: midiStatus,
              onCreateExercise: onCreateExercise,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}
