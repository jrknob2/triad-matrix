import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/guided_practice/guided_practice_controller.dart';
import 'package:drumcabulary/features/guided_practice/guided_practice_sequence_builder.dart';
import 'package:drumcabulary/features/midi/led_frame_command_encoder.dart';
import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/serial_led_controller.dart';
import 'package:drumcabulary/features/practice/sticking_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuidedPracticeController', () {
    test('Starting Guided Practice sends one frame and no CLEAR', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      expect(harness.controller.start(), true);

      expect(harness.writes, <String>[_frame('CUE,SNARE,R')]);
    });

    test('Starting cues the first expected voice', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      harness.controller.start();

      expect(harness.writes, <String>[_frame('CUE,SNARE,R')]);
    });

    test('Starting cues every voice in a simultaneous event', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          _event(DrumVoice.kick, DrumVoice.hiHatClosed),
        ],
      );

      harness.controller.start();

      expect(harness.writes, <String>[_frame('CUE,KICK,R', 'CUE,HIHAT,R')]);
    });

    test('Starting includes optional sticking in the cue frame', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
            LedCue(DrumVoice.kick),
            LedCue(DrumVoice.hiHatClosed, sticking: StickingCue.right),
          ]),
        ],
      );

      harness.controller.start();

      expect(harness.writes, <String>[_frame('CUE,KICK,R', 'CUE,HIHAT,R')]);
    });

    test('Starting serializes ghost, accent, and flam stroke cues', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
            LedCue(DrumVoice.snare, sticking: StickingCue.ghostRight),
          ]),
          GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
            LedCue(DrumVoice.snare, sticking: StickingCue.accentRight),
          ]),
          GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
            LedCue(DrumVoice.snare, sticking: StickingCue.ghostLeftRight),
          ]),
          GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
            LedCue(DrumVoice.snare, sticking: StickingCue.ghostRightLeft),
          ]),
        ],
      );

      harness.controller.start();
      harness.hit(DrumVoice.snare);
      harness.hit(DrumVoice.snare);
      harness.hit(DrumVoice.snare);

      expect(harness.writes, <String>[
        _frame('CUE,SNARE,(R)'),
        _frame('CUE,SNARE,^R'),
        _frame('CUE,SNARE,(L)R'),
        _frame('CUE,SNARE,(R)L'),
      ]);
    });

    test('Correct single voice advances immediately', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          _event(DrumVoice.snare),
          _event(DrumVoice.kick),
        ],
      );

      harness.controller.start();
      harness.hit(DrumVoice.snare);

      expect(harness.controller.state.currentIndex, 1);
      expect(harness.writes, <String>[
        _frame('CUE,SNARE,R'),
        _frame('CUE,KICK,R'),
      ]);
    });

    test('Wrong single voice sends ERROR and does not advance', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          GuidedPracticeExpectedEvent(
            <DrumVoice>[DrumVoice.snare],
            selectedIndexes: <int>{4},
          ),
        ],
      );

      harness.controller.start();
      harness.hit(DrumVoice.kick);

      expect(harness.controller.state.currentIndex, 0);
      expect(harness.controller.state.currentEvent?.selectedIndexes, <int>{4});
      expect(harness.writes.last, 'ERROR,KICK,R\n');
      expect(harness.writes.first, _frame('CUE,SNARE,R'));
    });

    test('Unknown voice does not advance', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      harness.controller.start();
      harness.hit(DrumVoice.unknown);

      expect(harness.controller.state.currentIndex, 0);
      expect(harness.writes, <String>[_frame('CUE,SNARE,R')]);
    });

    test(
      'First correct voice in a simultaneous event starts the timer',
      () async {
        final _FakeTimerFactory timerFactory = _FakeTimerFactory();
        final _GuidedHarness harness = await _GuidedHarness.connected(
          events: <GuidedPracticeExpectedEvent>[
            _event(DrumVoice.kick, DrumVoice.hiHatClosed),
          ],
          timerFactory: timerFactory.call,
        );

        harness.controller.start();
        harness.hit(DrumVoice.kick);

        expect(
          timerFactory.durations.single,
          const Duration(milliseconds: 150),
        );
        expect(timerFactory.timers.single.isActive, true);
      },
    );

    test('All simultaneous voices inside the window advance', () async {
      final _FakeTimerFactory timerFactory = _FakeTimerFactory();
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          _event(DrumVoice.kick, DrumVoice.hiHatClosed),
          _event(DrumVoice.snare),
        ],
        timerFactory: timerFactory.call,
      );

      harness.controller.start();
      harness.hit(DrumVoice.kick);
      harness.hit(DrumVoice.hiHatClosed);

      expect(harness.controller.state.currentIndex, 1);
      expect(timerFactory.timers.single.isActive, false);
      expect(harness.writes.sublist(1), <String>[_frame('CUE,SNARE,R')]);
    });

    test('Simultaneous voices may arrive in any order', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          _event(DrumVoice.kick, DrumVoice.hiHatClosed),
          _event(DrumVoice.snare),
        ],
      );

      harness.controller.start();
      harness.hit(DrumVoice.hiHatClosed);
      harness.hit(DrumVoice.kick);

      expect(harness.controller.state.currentIndex, 1);
    });

    test(
      'Hi-hat MIDI variants satisfy closed hi-hat expected events',
      () async {
        final _GuidedHarness harness = await _GuidedHarness.connected(
          events: <GuidedPracticeExpectedEvent>[
            _event(DrumVoice.kick, DrumVoice.hiHatClosed),
            _event(DrumVoice.snare),
          ],
        );

        harness.controller.start();
        harness.hit(DrumVoice.hiHatOpen);
        harness.hit(DrumVoice.kick);

        expect(harness.controller.state.currentIndex, 1);
        expect(harness.writes.sublist(1), <String>[_frame('CUE,SNARE,R')]);
      },
    );

    test(
      'Open hi-hat cues keep their voice while matching hi-hat input',
      () async {
        final _GuidedHarness harness = await _GuidedHarness.connected(
          events: <GuidedPracticeExpectedEvent>[
            GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
              LedCue(DrumVoice.hiHatOpen),
            ]),
            _event(DrumVoice.snare),
          ],
        );

        harness.controller.start();
        harness.hit(DrumVoice.hiHatClosed);

        expect(harness.controller.expectedEvents.first.voices, <DrumVoice>[
          DrumVoice.hiHatOpen,
        ]);
        expect(harness.controller.state.currentIndex, 1);
        expect(harness.writes, <String>[
          _frame('CUE,OHH,R'),
          _frame('CUE,SNARE,R'),
        ]);
      },
    );

    test(
      'Duplicate expected voice hits do not falsely complete a group',
      () async {
        final _FakeTimerFactory timerFactory = _FakeTimerFactory();
        final _GuidedHarness harness = await _GuidedHarness.connected(
          events: <GuidedPracticeExpectedEvent>[
            _event(DrumVoice.kick, DrumVoice.hiHatClosed),
          ],
          timerFactory: timerFactory.call,
        );

        harness.controller.start();
        harness.hit(DrumVoice.kick);
        harness.hit(DrumVoice.kick);
        timerFactory.fireLast();

        expect(harness.controller.state.currentIndex, 0);
        expect(harness.writes.last, 'MISSING,HIHAT,R\n');
      },
    );

    test('Missing expected voices send MISSING after 150 ms', () async {
      final _FakeTimerFactory timerFactory = _FakeTimerFactory();
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          GuidedPracticeExpectedEvent(
            <DrumVoice>[DrumVoice.kick, DrumVoice.hiHatClosed],
            selectedIndexes: <int>{0},
          ),
        ],
        timerFactory: timerFactory.call,
      );

      harness.controller.start();
      harness.hit(DrumVoice.kick);
      timerFactory.fireLast();

      expect(harness.writes.last, 'MISSING,HIHAT,R\n');
      expect(harness.controller.state.receivedVoices, isEmpty);
      expect(harness.controller.state.currentEvent?.selectedIndexes, <int>{0});
    });

    test('Missing feedback includes expected sticking', () async {
      final _FakeTimerFactory timerFactory = _FakeTimerFactory();
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          GuidedPracticeExpectedEvent.fromCues(const <LedCue>[
            LedCue(DrumVoice.kick),
            LedCue(DrumVoice.hiHatClosed, sticking: StickingCue.left),
          ]),
        ],
        timerFactory: timerFactory.call,
      );

      harness.controller.start();
      harness.hit(DrumVoice.kick);
      timerFactory.fireLast();

      expect(harness.writes.last, 'MISSING,HIHAT,L\n');
      expect(harness.writes.first, _frame('CUE,KICK,R', 'CUE,HIHAT,L'));
    });

    test(
      'A failed simultaneous attempt requires the complete group again',
      () async {
        final _FakeTimerFactory timerFactory = _FakeTimerFactory();
        final _GuidedHarness harness = await _GuidedHarness.connected(
          events: <GuidedPracticeExpectedEvent>[
            _event(DrumVoice.kick, DrumVoice.hiHatClosed),
            _event(DrumVoice.snare),
          ],
          timerFactory: timerFactory.call,
        );

        harness.controller.start();
        harness.hit(DrumVoice.kick);
        timerFactory.fireLast();
        harness.hit(DrumVoice.hiHatClosed);
        timerFactory.fireLast();

        expect(harness.controller.state.currentIndex, 0);
        expect(harness.writes.last, 'MISSING,KICK,R\n');

        harness.hit(DrumVoice.kick);
        harness.hit(DrumVoice.hiHatClosed);

        expect(harness.controller.state.currentIndex, 1);
      },
    );

    test(
      'Extra voices send ERROR and do not extend the active timer',
      () async {
        final _FakeTimerFactory timerFactory = _FakeTimerFactory();
        final _GuidedHarness harness = await _GuidedHarness.connected(
          events: <GuidedPracticeExpectedEvent>[
            _event(DrumVoice.kick, DrumVoice.hiHatClosed),
          ],
          timerFactory: timerFactory.call,
        );

        harness.controller.start();
        harness.hit(DrumVoice.kick);
        harness.hit(DrumVoice.snare);

        expect(harness.writes.last, 'ERROR,SNARE,R\n');
        expect(timerFactory.timers.length, 1);

        timerFactory.fireLast();
        expect(harness.writes.last, 'MISSING,HIHAT,R\n');
      },
    );

    test('Advancing sends one replacement frame', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[
          _event(DrumVoice.snare),
          _event(DrumVoice.kick),
        ],
      );

      harness.controller.start();
      harness.hit(DrumVoice.snare);

      expect(harness.writes.sublist(1), <String>[_frame('CUE,KICK,R')]);
    });

    test('Final event loops to the first event and keeps running', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      harness.controller.start();
      harness.hit(DrumVoice.snare);

      expect(harness.controller.state.status, GuidedPracticeStatus.running);
      expect(harness.controller.state.currentIndex, 0);
      expect(harness.writes, <String>[
        _frame('CUE,SNARE,R'),
        _frame('CUE,SNARE,R'),
      ]);
    });

    test('Manual Stop sends CLEAR', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      harness.controller.start();
      harness.controller.stop();

      expect(harness.controller.state.status, GuidedPracticeStatus.stopped);
      expect(harness.writes.last, 'CLEAR\n');
    });

    test('Disposal cancels timers and MIDI subscriptions', () async {
      var cancelCount = 0;
      final StreamController<DrumInputEvent> input =
          StreamController<DrumInputEvent>.broadcast(
            sync: true,
            onCancel: () => cancelCount += 1,
          );
      final _FakeTimerFactory timerFactory = _FakeTimerFactory();
      final _GuidedHarness harness = await _GuidedHarness.connected(
        input: input,
        events: <GuidedPracticeExpectedEvent>[
          _event(DrumVoice.kick, DrumVoice.hiHatClosed),
        ],
        timerFactory: timerFactory.call,
      );

      harness.controller.start();
      harness.hit(DrumVoice.kick);
      harness.controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(timerFactory.timers.single.isActive, false);
      expect(cancelCount, 1);
      expect(harness.writes.last, 'CLEAR\n');
    });

    test('MIDI disconnect stops the session safely', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      harness.controller.start();
      harness.controller.handleMidiDisconnected();

      expect(harness.controller.state.status, GuidedPracticeStatus.error);
      expect(harness.writes.last, 'CLEAR\n');
    });

    test('Serial disconnect stops the session safely', () async {
      final _GuidedHarness harness = await _GuidedHarness.connected(
        events: <GuidedPracticeExpectedEvent>[_event(DrumVoice.snare)],
      );

      harness.controller.start();
      harness.platform.lastConnection.close();
      harness.controller.handleSerialDisconnected();

      expect(harness.controller.state.status, GuidedPracticeStatus.error);
    });
  });

  group('GuidedPracticeSequenceBuilder', () {
    const GuidedPracticeSequenceBuilder builder =
        GuidedPracticeSequenceBuilder();

    test('Multi-stroke phrases become sequential input steps', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        _exercise(pattern: '[S:RL][K]'),
      );

      expect(
        events
            .map((GuidedPracticeExpectedEvent event) => event.voices)
            .toList(),
        <List<DrumVoice>>[
          <DrumVoice>[DrumVoice.snare],
          <DrumVoice>[DrumVoice.snare],
          <DrumVoice>[DrumVoice.kick],
        ],
      );
      expect(
        events
            .map((GuidedPracticeExpectedEvent event) => event.selectedIndexes)
            .toList(),
        <Set<int>>[
          <int>{0},
          <int>{1},
          <int>{2},
        ],
      );
    });

    test('Ghost and accent markings resolve to underlying DrumVoice', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        _exercise(pattern: '[S:(R)] [S:^R]'),
      );

      expect(
        events
            .map((GuidedPracticeExpectedEvent event) => event.voices)
            .toList(),
        <List<DrumVoice>>[
          <DrumVoice>[DrumVoice.snare],
          <DrumVoice>[DrumVoice.snare],
        ],
      );
      expect(events[0].cues.single.sticking, StickingCue.ghostRight);
      expect(events[1].cues.single.sticking, StickingCue.accentRight);
    });

    test('Simultaneous notation becomes one expected voice group', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        _exercise(pattern: '[HH K]'),
      );

      expect(events.single.voices.toSet(), <DrumVoice>{
        DrumVoice.hiHatClosed,
        DrumVoice.kick,
      });
      expect(events.single.selectedIndexes, <int>{0});
    });

    test('Open hi-hat remains identifiable in expected voice groups', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        _exercise(pattern: '[OHH:R K]'),
      );

      expect(events.single.voices.toSet(), <DrumVoice>{
        DrumVoice.hiHatOpen,
        DrumVoice.kick,
      });
      expect(
        events.single.cueForVoice(DrumVoice.hiHatOpen)?.sticking,
        StickingCue.right,
      );
      expect(events.single.cueForVoice(DrumVoice.kick)?.sticking, isNull);
    });

    test('Authored sticking is carried into expected cues', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        _exercise(pattern: '[HH:R K] [T1:L]'),
      );

      expect(events[0].cues, hasLength(2));
      expect(
        events[0].cueForVoice(DrumVoice.hiHatClosed)?.sticking,
        StickingCue.right,
      );
      expect(events[0].cueForVoice(DrumVoice.kick)?.sticking, isNull);
      expect(events[1].cueForVoice(DrumVoice.tom1)?.sticking, StickingCue.left);
    });

    test('Combined semantic sticking labels convert to cue strokes', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        _exercise(pattern: '[S] [S] [S]', sticking: 'LR (R)L (L)R'),
      );

      expect(events[0].cues.single.sticking, StickingCue.leftRight);
      expect(events[1].cues.single.sticking, StickingCue.ghostRightLeft);
      expect(events[2].cues.single.sticking, StickingCue.ghostLeftRight);
      expect(events[0].cues.single.sticking?.protocolValue, 'LR');
      expect(events[1].cues.single.sticking?.protocolValue, '(R)L');
      expect(events[2].cues.single.sticking?.protocolValue, '(L)R');
    });

    test('Sectioned notation records the owning section for highlights', () {
      final List<GuidedPracticeExpectedEvent> events = builder.buildForExercise(
        LessonExercise(
          id: 'sectioned',
          title: 'Sectioned',
          why: 'Why',
          what: 'What',
          how: 'How',
          notation: const ExerciseNotation(
            sections: <ExerciseNotationSection>[
              ExerciseNotationSection(pattern: '[S]'),
              ExerciseNotationSection(pattern: '[K]'),
            ],
          ),
        ),
      );

      expect(events[0].sectionIndex, 0);
      expect(events[0].selectedIndexes, <int>{0});
      expect(events[1].sectionIndex, 1);
      expect(events[1].selectedIndexes, <int>{0});
    });
  });
}

String _frame(String firstCue, [String? secondCue]) {
  return <String>[
    'FRAME_BEGIN',
    firstCue,
    if (secondCue != null) secondCue,
    'FRAME_END',
    '',
  ].join('\n');
}

GuidedPracticeExpectedEvent _event(DrumVoice first, [DrumVoice? second]) {
  return GuidedPracticeExpectedEvent(<DrumVoice>[
    first,
    if (second != null) second,
  ]);
}

LessonExercise _exercise({required String pattern, String? sticking}) {
  return LessonExercise(
    id: 'exercise',
    title: 'Exercise',
    why: 'Why',
    what: 'What',
    how: 'How',
    notation: ExerciseNotation(
      sections: <ExerciseNotationSection>[
        ExerciseNotationSection(pattern: pattern, sticking: sticking),
      ],
    ),
  );
}

class _GuidedHarness {
  final StreamController<DrumInputEvent> input;
  final _FakeSerialPlatform platform;
  final SerialLedController ledController;
  final GuidedPracticeController controller;

  _GuidedHarness({
    required this.input,
    required this.platform,
    required this.ledController,
    required this.controller,
  });

  List<String> get writes => platform.lastConnection.writes;

  static Future<_GuidedHarness> connected({
    required List<GuidedPracticeExpectedEvent> events,
    StreamController<DrumInputEvent>? input,
    GuidedPracticeTimerFactory? timerFactory,
  }) async {
    final StreamController<DrumInputEvent> inputController =
        input ?? StreamController<DrumInputEvent>.broadcast(sync: true);
    final _FakeSerialPlatform platform = _FakeSerialPlatform();
    final SerialLedController ledController = SerialLedController(
      platform: platform,
    );
    addTearDown(ledController.dispose);
    addTearDown(inputController.close);
    await ledController.refreshPorts();
    ledController.selectPort(_FakeSerialPlatform.esp32.path);
    await ledController.connect();
    final GuidedPracticeController controller = GuidedPracticeController(
      expectedEvents: events,
      drumEvents: inputController.stream,
      ledController: ledController,
      timerFactory: timerFactory,
    );
    addTearDown(controller.dispose);
    return _GuidedHarness(
      input: inputController,
      platform: platform,
      ledController: ledController,
      controller: controller,
    );
  }

  void hit(DrumVoice voice, {int velocity = 96}) {
    input.add(
      DrumInputEvent(
        voice: voice,
        midiNote: 0,
        velocity: velocity,
        timestamp: DateTime(2026),
      ),
    );
  }
}

class _FakeTimerFactory {
  final List<Duration> durations = <Duration>[];
  final List<_FakeGuidedTimer> timers = <_FakeGuidedTimer>[];

  GuidedPracticeWindowTimer call(Duration duration, void Function() callback) {
    durations.add(duration);
    final _FakeGuidedTimer timer = _FakeGuidedTimer(callback);
    timers.add(timer);
    return timer;
  }

  void fireLast() {
    timers.last.fire();
  }
}

class _FakeGuidedTimer implements GuidedPracticeWindowTimer {
  final void Function() callback;
  bool _active = true;

  _FakeGuidedTimer(this.callback);

  @override
  bool get isActive => _active;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

class _FakeSerialPlatform implements SerialLedPlatform {
  static const SerialLedPort esp32 = SerialLedPort(
    path: '/dev/cu.usbmodem101',
    description: 'ESP32-S3 USB JTAG/serial debug unit',
    manufacturer: 'Espressif',
    productName: 'ESP32-S3',
  );

  final List<_FakeSerialConnection> connections = <_FakeSerialConnection>[];

  _FakeSerialConnection get lastConnection => connections.last;

  @override
  List<SerialLedPort> listPorts() => const <SerialLedPort>[esp32];

  @override
  SerialLedConnection openPort(SerialLedPort port, SerialLedSettings settings) {
    final _FakeSerialConnection connection = _FakeSerialConnection();
    connections.add(connection);
    return connection;
  }
}

class _FakeSerialConnection implements SerialLedConnection {
  final List<String> writes = <String>[];
  bool closed = false;

  @override
  bool get isOpen => !closed;

  @override
  int write(Uint8List bytes) {
    writes.add(utf8.decode(bytes));
    return bytes.length;
  }

  @override
  void close() {
    closed = true;
  }
}
