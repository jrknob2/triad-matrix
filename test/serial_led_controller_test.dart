import 'dart:convert';
import 'dart:typed_data';

import 'package:drumcabulary/features/midi/drum_voice_led_command_mapper.dart';
import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/midi_led_forwarder.dart';
import 'package:drumcabulary/features/midi/serial_led_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DrumVoiceLedCommandMapper', () {
    const DrumVoiceLedCommandMapper mapper = DrumVoiceLedCommandMapper();

    test('snare maps to SNARE newline', () {
      expect(mapper.commandFor(DrumVoice.snare), 'SNARE\n');
    });

    test('kick maps to KICK newline', () {
      expect(mapper.commandFor(DrumVoice.kick), 'KICK\n');
    });

    test('closed, open, and pedal hi-hat map to HIHAT newline', () {
      expect(mapper.commandFor(DrumVoice.hiHatClosed), 'HIHAT\n');
      expect(mapper.commandFor(DrumVoice.hiHatOpen), 'HIHAT\n');
      expect(mapper.commandFor(DrumVoice.hiHatPedal), 'HIHAT\n');
    });

    test('tom voices map correctly', () {
      expect(mapper.commandFor(DrumVoice.tom1), 'TOM1\n');
      expect(mapper.commandFor(DrumVoice.tom2), 'TOM2\n');
      expect(mapper.commandFor(DrumVoice.floorTom), 'FLOORTOM\n');
    });

    test('crash and ride map correctly', () {
      expect(mapper.commandFor(DrumVoice.crash), 'CRASH\n');
      expect(mapper.commandFor(DrumVoice.ride), 'RIDE\n');
    });

    test('unknown voice returns no command', () {
      expect(mapper.commandFor(DrumVoice.unknown), isNull);
    });
  });

  group('SerialLedController', () {
    test('Test Flash command sends SNARE newline', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();
      controller.sendCommand(DrumVoiceLedCommandMapper.snareCommand);

      expect(platform.lastConnection.writes, <String>['SNARE\n']);
    });

    test('disposal closes the serial connection', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();
      controller.dispose();

      expect(platform.lastConnection.closed, true);
    });

    test('refresh marks a connected missing port as removed', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();
      platform.ports = const <SerialLedPort>[];
      await controller.refreshPorts();

      expect(controller.status, SerialLedConnectionStatus.deviceRemoved);
      expect(platform.lastConnection.closed, true);
    });

    test('refresh failure preserves an active serial connection', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();
      platform.listError = const SerialLedException(
        'Operation not permitted, errno = 1',
      );

      await controller.refreshPorts();
      controller.sendCommand(DrumVoiceLedCommandMapper.snareCommand);

      expect(controller.status, SerialLedConnectionStatus.connected);
      expect(controller.isConnected, true);
      expect(
        controller.lastError,
        contains('Keeping the current LED connection active'),
      );
      expect(platform.lastConnection.writes, <String>['SNARE\n']);
    });
  });

  group('MidiLedForwarder', () {
    test('Note Off is not forwarded', () async {
      final _ForwarderHarness harness = await _ForwarderHarness.connected();

      harness.forwarder.handle(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          messageType: MidiMessageType.noteOff,
          velocity: 90,
        ),
      );

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test('velocity-zero Note On is not forwarded', () async {
      final _ForwarderHarness harness = await _ForwarderHarness.connected();

      harness.forwarder.handle(
        _diagnosticEvent(
          voice: DrumVoice.snare,
          messageType: MidiMessageType.noteOn,
          velocity: 0,
        ),
      );

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test('normal Note On is forwarded when enabled and connected', () async {
      final _ForwarderHarness harness = await _ForwarderHarness.connected();

      harness.forwarder.handle(_diagnosticEvent(voice: DrumVoice.snare));

      expect(harness.platform.lastConnection.writes, <String>['SNARE\n']);
    });

    test('MIDI events are not forwarded when forwarding is disabled', () async {
      final _ForwarderHarness harness = await _ForwarderHarness.connected(
        enabled: false,
      );

      harness.forwarder.handle(_diagnosticEvent(voice: DrumVoice.snare));

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test('MIDI events are not forwarded when serial is disconnected', () {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      final MidiLedForwarder forwarder = MidiLedForwarder(
        controller: controller,
        enabled: true,
      );

      forwarder.handle(_diagnosticEvent(voice: DrumVoice.snare));

      expect(platform.connections, isEmpty);
    });

    test('unknown voices are not forwarded', () async {
      final _ForwarderHarness harness = await _ForwarderHarness.connected();

      harness.forwarder.handle(_diagnosticEvent(voice: DrumVoice.unknown));

      expect(harness.platform.lastConnection.writes, isEmpty);
    });

    test('simultaneous voices produce separate commands in order', () async {
      final _ForwarderHarness harness = await _ForwarderHarness.connected();
      final DateTime timestamp = DateTime(2026);

      harness.forwarder
        ..handle(_diagnosticEvent(voice: DrumVoice.snare, timestamp: timestamp))
        ..handle(_diagnosticEvent(voice: DrumVoice.kick, timestamp: timestamp))
        ..handle(
          _diagnosticEvent(voice: DrumVoice.hiHatClosed, timestamp: timestamp),
        );

      expect(harness.platform.lastConnection.writes, <String>[
        'SNARE\n',
        'KICK\n',
        'HIHAT\n',
      ]);
    });
  });
}

class _ForwarderHarness {
  final _FakeSerialPlatform platform;
  final SerialLedController controller;
  final MidiLedForwarder forwarder;

  _ForwarderHarness({
    required this.platform,
    required this.controller,
    required this.forwarder,
  });

  static Future<_ForwarderHarness> connected({bool enabled = true}) async {
    final _FakeSerialPlatform platform = _FakeSerialPlatform();
    final SerialLedController controller = SerialLedController(
      platform: platform,
    );
    addTearDown(controller.dispose);
    await controller.refreshPorts();
    controller.selectPort(_FakeSerialPlatform.esp32.path);
    await controller.connect();
    final MidiLedForwarder forwarder = MidiLedForwarder(
      controller: controller,
      enabled: enabled,
    );
    return _ForwarderHarness(
      platform: platform,
      controller: controller,
      forwarder: forwarder,
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

  List<SerialLedPort> ports = const <SerialLedPort>[esp32];
  Object? listError;
  final List<_FakeSerialConnection> connections = <_FakeSerialConnection>[];

  _FakeSerialConnection get lastConnection => connections.last;

  @override
  List<SerialLedPort> listPorts() {
    final Object? error = listError;
    if (error != null) throw error;
    return ports;
  }

  @override
  SerialLedConnection openPort(SerialLedPort port, SerialLedSettings settings) {
    expect(settings.baudRate, 115200);
    expect(settings.dataBits, 8);
    expect(settings.stopBits, 1);
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

MidiDiagnosticEvent _diagnosticEvent({
  required DrumVoice voice,
  MidiMessageType messageType = MidiMessageType.noteOn,
  int velocity = 90,
  DateTime? timestamp,
}) {
  final DateTime eventTime = timestamp ?? DateTime(2026);
  return MidiDiagnosticEvent(
    raw: RawMidiEvent(
      deviceId: 'edrum-id',
      deviceName: 'edrum',
      messageType: messageType,
      channel: 10,
      note: 38,
      velocity: velocity,
      timestamp: eventTime,
    ),
    drum: DrumInputEvent(
      voice: voice,
      midiNote: 38,
      velocity: velocity,
      timestamp: eventTime,
    ),
  );
}
