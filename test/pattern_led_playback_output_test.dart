import 'dart:convert';
import 'dart:typed_data';

import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/midi/serial_led_controller.dart';
import 'package:drumcabulary/features/practice/pattern_audio_service.dart';
import 'package:drumcabulary/features/practice/pattern_led_playback_output.dart';
import 'package:drumcabulary/features/practice/sticking_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatternLedPlaybackOutput', () {
    test('enabled playback sends cue frames from playback cues', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.triggerCue(_cue(DrumVoiceV1.snare));
      harness.output.triggerCue(_cue(DrumVoiceV1.kick));
      harness.output.triggerCue(_cue(DrumVoiceV1.hihat));

      expect(harness.platform.lastConnection.writes, <String>[
        _frame('CUE,SNARE'),
        _frame('CUE,KICK'),
        _frame('CUE,HIHAT'),
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
        _frame('CUE,KICK', 'CUE,HIHAT,R', 'CUE,SNARE,L'),
      ]);
    });

    test('playback serializes ghost, accent, and flam strokes', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output
        ..triggerCue(_cue(DrumVoiceV1.snare, sticking: StickingCue.ghostRight))
        ..triggerCue(_cue(DrumVoiceV1.snare, sticking: StickingCue.accentRight))
        ..triggerCue(_cue(DrumVoiceV1.snare, sticking: StickingCue.flamRight))
        ..triggerCue(_cue(DrumVoiceV1.snare, sticking: StickingCue.flamLeft));

      expect(harness.platform.lastConnection.writes, <String>[
        _frame('CUE,SNARE,(R)'),
        _frame('CUE,SNARE,^R'),
        _frame('CUE,SNARE,(L)R'),
        _frame('CUE,SNARE,(R)L'),
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
          _frame('CUE,TOM1'),
          _frame('CUE,TOM2'),
          _frame('CUE,FLOORTOM'),
          _frame('CUE,CRASH'),
          _frame('CUE,RIDE'),
        ]);
      },
    );

    test('open hi-hat playback maps to the physical hi-hat LED', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.triggerCue(
        _cue(DrumVoiceV1.openHiHat, sticking: StickingCue.right),
      );

      expect(harness.platform.lastConnection.writes, <String>[
        _frame('CUE,HIHAT,R'),
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

String _frame(String firstCue, [String? secondCue, String? thirdCue]) {
  return <String>[
    'FRAME_BEGIN',
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

  static Future<_PlaybackLedHarness> connected({bool enabled = true}) async {
    final _FakeSerialPlatform platform = _FakeSerialPlatform();
    final SerialLedController controller = SerialLedController(
      platform: platform,
    );
    addTearDown(controller.dispose);
    await controller.refreshPorts();
    controller.selectPort(_FakeSerialPlatform.esp32.path);
    await controller.connect();
    final PatternLedPlaybackOutput output = PatternLedPlaybackOutput(
      controller: controller,
      isEnabled: () => enabled,
    );
    return _PlaybackLedHarness(
      platform: platform,
      controller: controller,
      output: output,
    );
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
