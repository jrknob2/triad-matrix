import 'dart:convert';
import 'dart:typed_data';

import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/midi/serial_led_controller.dart';
import 'package:drumcabulary/features/practice/pattern_audio_service.dart';
import 'package:drumcabulary/features/practice/pattern_led_playback_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatternLedPlaybackOutput', () {
    test('enabled playback sends commands from playback cues', () async {
      final _PlaybackLedHarness harness = await _PlaybackLedHarness.connected();

      harness.output.triggerCue(_cue(DrumVoiceV1.snare));
      harness.output.triggerCue(_cue(DrumVoiceV1.kick));
      harness.output.triggerCue(_cue(DrumVoiceV1.hihat));

      expect(harness.platform.lastConnection.writes, <String>[
        'SNARE\n',
        'KICK\n',
        'HIHAT\n',
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
          'TOM1\n',
          'TOM2\n',
          'FLOORTOM\n',
          'CRASH\n',
          'RIDE\n',
        ]);
      },
    );
  });
}

PatternAudioCueV1 _cue(DrumVoiceV1 voice) {
  return PatternAudioCueV1(
    tokenIndex: 0,
    offset: Duration.zero,
    sample: PatternAudioSampleV1.snare,
    voice: voice,
    volume: 1,
  );
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
