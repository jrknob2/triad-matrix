import 'dart:async';
import 'dart:convert';

import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/serial_led_controller.dart';
import 'package:drumcabulary/features/practice/pattern_audio_service.dart';
import 'package:drumcabulary/features/practice/pattern_led_playback_output.dart';
import 'package:drumcabulary/features/practice/pattern_play_along_input_feedback_output.dart';
import 'package:drumcabulary/features/practice/sticking_cue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatternLedPlaybackOutput', () {
    test('enabled playback sends cue frames from playback cues', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.triggerCue(_cue(DrumVoiceV1.snare));
      harness.output.triggerCue(_cue(DrumVoiceV1.kick));
      harness.output.triggerCue(_cue(DrumVoiceV1.hihat));

      expect(harness.platform.lastConnection.writes, <String>[
        _flashFrame('CUE,SNARE,R'),
        _flashFrame('CUE,KICK,R'),
        _flashFrame('CUE,HIHAT,R'),
      ]);
    });

    test('simultaneous playback voices share one frame in order', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.triggerCueGroup(<PatternAudioCueV1>[
        _cue(DrumVoiceV1.kick),
        _cue(DrumVoiceV1.hihat, sticking: StickingCue.right),
        _cue(DrumVoiceV1.snare, sticking: StickingCue.left),
      ]);

      expect(harness.platform.lastConnection.writes, <String>[
        _flashFrame('CUE,KICK,R', 'CUE,HIHAT,R', 'CUE,SNARE,L'),
      ]);
    });

    test('playback serializes ghost, accent, and flam strokes', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output
        ..triggerCue(_cue(DrumVoiceV1.snare, sticking: StickingCue.ghostRight))
        ..triggerCue(_cue(DrumVoiceV1.snare, sticking: StickingCue.accentRight))
        ..triggerCue(
          _cue(DrumVoiceV1.snare, sticking: StickingCue.ghostLeftRight),
        )
        ..triggerCue(
          _cue(DrumVoiceV1.snare, sticking: StickingCue.ghostRightLeft),
        );

      expect(harness.platform.lastConnection.writes, <String>[
        _flashFrame('CUE,SNARE,(R)'),
        _flashFrame('CUE,SNARE,^R'),
        _flashFrame('CUE,SNARE,(L)R'),
        _flashFrame('CUE,SNARE,(R)L'),
      ]);
    });

    test('disabled playback sends nothing', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected(
        enabled: false,
      );

      harness.output.triggerCue(_cue(DrumVoiceV1.snare));

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test('disconnected serial does not interrupt playback output', () {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);
      final PatternLedPlaybackOutput output = PatternLedPlaybackOutput(
        controller: controller,
      );

      output.triggerCue(_cue(DrumVoiceV1.snare));

      expect(platform.connections, isEmpty);
    });

    test(
      'tom, cymbal, and simultaneous voices preserve command order',
      () async {
        final _PlaybackLedHarness harness =
            await _PlaybackLedHarness.connected();

        harness.output
          ..triggerCue(_cue(DrumVoiceV1.rackTom))
          ..triggerCue(_cue(DrumVoiceV1.tom2))
          ..triggerCue(_cue(DrumVoiceV1.floorTom))
          ..triggerCue(_cue(DrumVoiceV1.crash))
          ..triggerCue(_cue(DrumVoiceV1.ride));

        expect(harness.platform.lastConnection.writes, <String>[
          _flashFrame('CUE,TOM1,R'),
          _flashFrame('CUE,TOM2,R'),
          _flashFrame('CUE,FLOORTOM,R'),
          _flashFrame('CUE,CRASH,R'),
          _flashFrame('CUE,RIDE,R'),
        ]);
      },
    );

    test('open hi-hat playback serializes as OHH', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.triggerCue(
        _cue(DrumVoiceV1.openHiHat, sticking: StickingCue.right),
      );

      expect(harness.platform.lastConnection.writes, <String>[
        _flashFrame('CUE,OHH,R'),
      ]);
    });

    test('play along uses lead time and fade-in frames', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected(
        presentation: PatternLedPlaybackPresentation.playAlong,
      );

      expect(harness.output.leadTime, const Duration(milliseconds: 250));

      harness.output.triggerCue(_cue(DrumVoiceV1.snare));
      expect(harness.platform.lastConnection.writes, isEmpty);

      harness.output.triggerLeadCueGroup(<PatternAudioCueV1>[
        _cue(DrumVoiceV1.kick),
        _cue(DrumVoiceV1.hihat, sticking: StickingCue.right),
      ]);

      expect(harness.platform.lastConnection.writes, <String>[
        _fadeInFrame('CUE,KICK,R', 'CUE,HIHAT,R'),
      ]);
    });

    test('playback stop sends CLEAR', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.stop();

      expect(harness.platform.lastConnection.writes, <String>['CLEAR\n']);
    });
  });

  group('PatternAudioService cue grouping', () {
    test('groups simultaneous offsets for playback outputs', () {
      final List<List<PatternAudioCueV1>> groups =
          PatternAudioService.cueGroupsForTesting(
            PatternAudioPlanV1(
              cues: <PatternAudioCueV1>[
                _cue(DrumVoiceV1.kick),
                _cue(DrumVoiceV1.hihat),
                _cue(
                  DrumVoiceV1.snare,
                  offset: const Duration(milliseconds: 1),
                ),
              ],
              cycleDuration: const Duration(milliseconds: 2),
            ),
          );

      expect(groups.map((List<PatternAudioCueV1> group) => group.length), <int>[
        2,
        1,
      ]);
    });

    test('play along lead delay is scheduled before the target beat', () {
      expect(
        PatternAudioService.playAlongLeadDelayForTesting(
          cueOffset: const Duration(milliseconds: 700),
          phase: Duration.zero,
          cycleDuration: const Duration(seconds: 1),
          leadTime: const Duration(milliseconds: 250),
        ),
        const Duration(milliseconds: 450),
      );
    });

    test('play along lead delay wraps for early next-cycle beats', () {
      expect(
        PatternAudioService.playAlongLeadDelayForTesting(
          cueOffset: const Duration(milliseconds: 100),
          phase: Duration.zero,
          cycleDuration: const Duration(seconds: 1),
          leadTime: const Duration(milliseconds: 250),
        ),
        const Duration(milliseconds: 850),
      );
    });

    test('late play along frames are skipped', () {
      expect(
        PatternAudioService.playAlongLeadDelayForTesting(
          cueOffset: const Duration(milliseconds: 500),
          phase: const Duration(milliseconds: 300),
          cycleDuration: const Duration(seconds: 1),
          leadTime: const Duration(milliseconds: 250),
        ),
        isNull,
      );
    });

    test('start gate uses the first upcoming cue group', () {
      final PatternAudioPlanV1 plan = PatternAudioPlanV1(
        cues: <PatternAudioCueV1>[
          _cue(DrumVoiceV1.kick, offset: Duration.zero),
          _cue(DrumVoiceV1.hihat, offset: Duration.zero),
          _cue(DrumVoiceV1.snare, offset: const Duration(milliseconds: 500)),
        ],
        cycleDuration: const Duration(seconds: 1),
      );

      final List<PatternAudioCueV1>? group =
          PatternAudioService.startGateCueGroupForTesting(
            plan: plan,
            phase: Duration.zero,
          );

      expect(group, isNotNull);
      expect(group!.map((PatternAudioCueV1 cue) => cue.voice), <DrumVoiceV1>[
        DrumVoiceV1.kick,
        DrumVoiceV1.hihat,
      ]);
    });

    test('playback phase after start gate skips the gated hit', () {
      final List<PatternAudioCueV1> cueGroup = <PatternAudioCueV1>[
        _cue(DrumVoiceV1.kick, offset: Duration.zero),
        _cue(DrumVoiceV1.hihat, offset: Duration.zero),
      ];

      expect(
        PatternAudioService.phaseAfterStartGateCueGroupForTesting(
          cueGroup: cueGroup,
          cycleDuration: const Duration(seconds: 1),
        ),
        const Duration(microseconds: 1),
      );
    });
  });

  group('PatternPlayAlongInputFeedbackOutput', () {
    test('wrong voice sends ERROR without waiting for playback', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();
      final _PlayAlongFeedbackHarness feedback =
          _PlayAlongFeedbackHarness.connected(harness);

      feedback.output.start(
        _plan(<PatternAudioCueV1>[_cue(DrumVoiceV1.snare)]),
      );
      feedback.output.triggerCueGroup(<PatternAudioCueV1>[
        _cue(DrumVoiceV1.snare),
      ]);
      feedback.input.add(_drum(DrumVoice.kick));

      expect(harness.platform.lastConnection.writes, <String>[
        'ERROR,KICK,R\n',
      ]);
    });

    test(
      'missing voice sends MISSING when the timing window expires',
      () async {
        final _PlaybackLedHarness harness =
            await _PlaybackLedHarness.connected();
        final _PlayAlongFeedbackHarness feedback =
            _PlayAlongFeedbackHarness.connected(harness);

        feedback.output.start(
          _plan(<PatternAudioCueV1>[_cue(DrumVoiceV1.snare)]),
        );
        feedback.output.triggerCueGroup(<PatternAudioCueV1>[
          _cue(DrumVoiceV1.snare, sticking: StickingCue.left),
        ]);
        feedback.timers.fireNext();

        expect(harness.platform.lastConnection.writes, <String>[
          'MISSING,SNARE,L\n',
        ]);
      },
    );

    test('correct hit suppresses missing feedback', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();
      final _PlayAlongFeedbackHarness feedback =
          _PlayAlongFeedbackHarness.connected(harness);

      feedback.output.start(
        _plan(<PatternAudioCueV1>[_cue(DrumVoiceV1.snare)]),
      );
      feedback.output.triggerCueGroup(<PatternAudioCueV1>[
        _cue(DrumVoiceV1.snare),
      ]);
      feedback.input.add(_drum(DrumVoice.snare));
      feedback.timers.fireNext();

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test('partial simultaneous hit reports only the missing voice', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();
      final _PlayAlongFeedbackHarness feedback =
          _PlayAlongFeedbackHarness.connected(harness);
      final List<PatternAudioCueV1> cueGroup = <PatternAudioCueV1>[
        _cue(DrumVoiceV1.kick),
        _cue(DrumVoiceV1.hihat),
      ];

      feedback.output.start(_plan(cueGroup));
      feedback.output.triggerCueGroup(cueGroup);
      feedback.input.add(_drum(DrumVoice.kick));
      feedback.timers.fireNext();

      expect(harness.platform.lastConnection.writes, <String>[
        'MISSING,HIHAT,R\n',
      ]);
    });

    test('lead window accepts a slightly early correct hit', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();
      final _PlayAlongFeedbackHarness feedback =
          _PlayAlongFeedbackHarness.connected(harness);
      final List<PatternAudioCueV1> cueGroup = <PatternAudioCueV1>[
        _cue(DrumVoiceV1.snare),
      ];

      feedback.output.start(_plan(cueGroup));
      feedback.output.triggerLeadCueGroup(cueGroup);
      feedback.input.add(_drum(DrumVoice.snare));
      feedback.output.triggerCueGroup(cueGroup);
      feedback.timers.fireNext();

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test(
      'start gate waits for a correct single voice before completing',
      () async {
        final _PlaybackLedHarness harness =
            await _PlaybackLedHarness.connected();
        final _PlayAlongFeedbackHarness feedback =
            _PlayAlongFeedbackHarness.connected(harness);

        feedback.output.start(
          _plan(<PatternAudioCueV1>[_cue(DrumVoiceV1.snare)]),
        );
        final Future<void> gate = feedback.output.waitForStartCueGroup(
          <PatternAudioCueV1>[_cue(DrumVoiceV1.snare)],
        );

        expect(await _futureCompleted(gate), isFalse);

        feedback.input.add(_drum(DrumVoice.snare));

        await gate;
        expect(harness.platform.lastConnection.writes, isEmpty);
      },
    );

    test(
      'wrong voice during start gate sends ERROR and keeps waiting',
      () async {
        final _PlaybackLedHarness harness =
            await _PlaybackLedHarness.connected();
        final _PlayAlongFeedbackHarness feedback =
            _PlayAlongFeedbackHarness.connected(harness);

        feedback.output.start(
          _plan(<PatternAudioCueV1>[_cue(DrumVoiceV1.snare)]),
        );
        final Future<void> gate = feedback.output.waitForStartCueGroup(
          <PatternAudioCueV1>[_cue(DrumVoiceV1.snare)],
        );

        feedback.input.add(_drum(DrumVoice.kick));

        expect(harness.platform.lastConnection.writes, <String>[
          'ERROR,KICK,R\n',
        ]);
        expect(await _futureCompleted(gate), isFalse);

        feedback.input.add(_drum(DrumVoice.snare));
        await gate;
      },
    );

    test('simultaneous start gate requires the complete group again', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();
      final _PlayAlongFeedbackHarness feedback =
          _PlayAlongFeedbackHarness.connected(harness);
      final List<PatternAudioCueV1> cueGroup = <PatternAudioCueV1>[
        _cue(DrumVoiceV1.kick),
        _cue(DrumVoiceV1.hihat),
      ];

      feedback.output.start(_plan(cueGroup));
      final Future<void> gate = feedback.output.waitForStartCueGroup(cueGroup);

      feedback.input.add(_drum(DrumVoice.kick));
      feedback.timers.fireNext();

      expect(harness.platform.lastConnection.writes, <String>[
        'MISSING,HIHAT,R\n',
      ]);
      expect(await _futureCompleted(gate), isFalse);

      feedback.input.add(_drum(DrumVoice.kick));
      feedback.input.add(_drum(DrumVoice.hiHatClosed));

      await gate;
    });

    test('stop completes an active start gate without feedback', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();
      final _PlayAlongFeedbackHarness feedback =
          _PlayAlongFeedbackHarness.connected(harness);

      feedback.output.start(
        _plan(<PatternAudioCueV1>[_cue(DrumVoiceV1.snare)]),
      );
      final Future<void> gate = feedback.output.waitForStartCueGroup(
        <PatternAudioCueV1>[_cue(DrumVoiceV1.snare)],
      );

      feedback.output.stop();

      await gate;
      expect(harness.platform.lastConnection.writes, isEmpty);
    });
  });
}

PatternAudioCueV1 _cue(
  DrumVoiceV1 voice, {
  StickingCue? sticking,
  Duration offset = Duration.zero,
}) {
  return PatternAudioCueV1(
    tokenIndex: 0,
    offset: offset,
    sample: PatternAudioSampleV1.snare,
    voice: voice,
    sticking: sticking,
    volume: 1,
  );
}

PatternAudioPlanV1 _plan(List<PatternAudioCueV1> cues) {
  return PatternAudioPlanV1(
    cues: cues,
    cycleDuration: const Duration(seconds: 1),
  );
}

DrumInputEvent _drum(DrumVoice voice) {
  return DrumInputEvent(
    voice: voice,
    midiNote: 38,
    velocity: 96,
    timestamp: DateTime(2026),
  );
}

Future<bool> _futureCompleted(Future<void> future) async {
  bool completed = false;
  unawaited(future.then((_) => completed = true));
  await Future<void>.delayed(Duration.zero);
  return completed;
}

String _flashFrame(String firstCue, [String? secondCue, String? thirdCue]) {
  return _frame('ANIMATION,FLASH,220', firstCue, secondCue, thirdCue);
}

String _fadeInFrame(String firstCue, [String? secondCue, String? thirdCue]) {
  return _frame('ANIMATION,FADE_IN,250,180', firstCue, secondCue, thirdCue);
}

String _frame(
  String animation,
  String firstCue, [
  String? secondCue,
  String? thirdCue,
]) {
  return <String>[
    'FRAME_BEGIN',
    animation,
    firstCue,
    if (secondCue != null) secondCue,
    if (thirdCue != null) thirdCue,
    'FRAME_END',
    '',
  ].join('\n');
}

class _PlaybackLedHarness {
  final _FakeSerialPlatform platform;
  final SerialLedController controller;
  final PatternLedPlaybackOutput output;

  const _PlaybackLedHarness({
    required this.platform,
    required this.controller,
    required this.output,
  });

  static Future<_PlaybackLedHarness> connected({
    bool enabled = true,
    PatternLedPlaybackPresentation presentation =
        PatternLedPlaybackPresentation.hearIt,
  }) async {
    final _FakeSerialPlatform platform = _FakeSerialPlatform();
    final SerialLedController controller = SerialLedController(
      platform: platform,
    );
    addTearDown(controller.dispose);
    await controller.refreshPorts();
    controller.selectPort(_FakeSerialPlatform.esp32.path);
    await controller.connect();
    platform.lastConnection.writes.clear();
    final PatternLedPlaybackOutput output = PatternLedPlaybackOutput(
      controller: controller,
      isEnabled: () => enabled,
      presentation: presentation,
    );
    return _PlaybackLedHarness(
      platform: platform,
      controller: controller,
      output: output,
    );
  }
}

class _PlayAlongFeedbackHarness {
  final StreamController<DrumInputEvent> input;
  final _FakePlayAlongTimerFactory timers;
  final PatternPlayAlongInputFeedbackOutput output;

  _PlayAlongFeedbackHarness._({
    required this.input,
    required this.timers,
    required this.output,
  });

  factory _PlayAlongFeedbackHarness.connected(_PlaybackLedHarness harness) {
    final StreamController<DrumInputEvent> input =
        StreamController<DrumInputEvent>.broadcast(sync: true);
    final _FakePlayAlongTimerFactory timers = _FakePlayAlongTimerFactory();
    final PatternPlayAlongInputFeedbackOutput output =
        PatternPlayAlongInputFeedbackOutput(
          drumEvents: input.stream,
          controller: harness.controller,
          timerFactory: timers.create,
        );
    addTearDown(() {
      output.stop();
      input.close();
    });
    return _PlayAlongFeedbackHarness._(
      input: input,
      timers: timers,
      output: output,
    );
  }
}

class _FakePlayAlongTimerFactory {
  final List<_FakePlayAlongTimer> timers = <_FakePlayAlongTimer>[];

  PlayAlongFeedbackTimer create(Duration duration, VoidCallback callback) {
    final _FakePlayAlongTimer timer = _FakePlayAlongTimer(callback);
    timers.add(timer);
    return timer;
  }

  void fireNext() {
    final _FakePlayAlongTimer timer = timers.removeAt(0);
    timer.fire();
  }
}

class _FakePlayAlongTimer implements PlayAlongFeedbackTimer {
  final VoidCallback callback;
  bool _active = true;

  _FakePlayAlongTimer(this.callback);

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
  final StreamController<Uint8List> _inputController =
      StreamController<Uint8List>.broadcast();
  bool closed = false;

  @override
  bool get isOpen => !closed;

  @override
  Stream<Uint8List> get input => _inputController.stream;

  @override
  int write(Uint8List bytes) {
    writes.add(utf8.decode(bytes));
    return bytes.length;
  }

  @override
  void close() {
    closed = true;
    _inputController.close();
  }
}
