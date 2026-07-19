import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drumcabulary/features/midi/drum_voice_led_command_mapper.dart';
import 'package:drumcabulary/features/midi/led_controller_protocol.dart';
import 'package:drumcabulary/features/midi/led_frame_command_encoder.dart';
import 'package:drumcabulary/features/midi/midi_input_models.dart';
import 'package:drumcabulary/features/midi/midi_led_forwarder.dart';
import 'package:drumcabulary/features/midi/serial_led_controller.dart';
import 'package:drumcabulary/features/practice/sticking_cue.dart';
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

    test('frame cue voice names distinguish open hi-hat', () {
      expect(mapper.cueVoiceNameFor(DrumVoice.hiHatClosed), 'HIHAT');
      expect(mapper.cueVoiceNameFor(DrumVoice.hiHatOpen), 'OHH');
      expect(mapper.cueVoiceNameFor(DrumVoice.hiHatPedal), 'HIHAT');
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
    test('sticking text conversion supports semantic stroke sequences', () {
      expect(stickingCueFromText('(L)'), StickingCue.ghostLeft);
      expect(stickingCueFromText('(R)'), StickingCue.ghostRight);
      expect(stickingCueFromText('^L'), StickingCue.accentLeft);
      expect(stickingCueFromText('^R'), StickingCue.accentRight);
      expect(stickingCueFromText('LR'), StickingCue.leftRight);
      expect(stickingCueFromText('L', ghost: true), StickingCue.ghostLeft);
      expect(stickingCueFromText('R', ghost: true), StickingCue.ghostRight);
      expect(
        stickingCueFromText('(R)L', flam: true),
        StickingCue.ghostRightLeft,
      );
      expect(
        stickingCueFromText('(L)R', flam: true),
        StickingCue.ghostLeftRight,
      );
      expect(stickingCueFromText('(L)^R')?.protocolValue, '(L)^R');
      expect(stickingCueFromText('(R)^L')?.protocolValue, '(R)^L');
    });

    test('stroke serializer is deterministic', () {
      expect(StickingCue.right.protocolValue, 'R');
      expect(StickingCue.left.protocolValue, 'L');
      expect(StickingCue.ghostRight.protocolValue, '(R)');
      expect(StickingCue.ghostLeft.protocolValue, '(L)');
      expect(StickingCue.accentRight.protocolValue, '^R');
      expect(StickingCue.accentLeft.protocolValue, '^L');
      expect(
        StickingCue.fromStrokes(const <LedStroke>[
          LedStroke(
            hand: LedStrokeHand.left,
            articulation: LedStrokeArticulation.ghost,
          ),
          LedStroke(hand: LedStrokeHand.right),
        ]).protocolValue,
        '(L)R',
      );
      expect(
        StickingCue.fromStrokes(const <LedStroke>[
          LedStroke(
            hand: LedStrokeHand.right,
            articulation: LedStrokeArticulation.ghost,
          ),
          LedStroke(hand: LedStrokeHand.left),
        ]).protocolValue,
        '(R)L',
      );
      expect(
        StickingCue.fromStrokes(const <LedStroke>[
          LedStroke(
            hand: LedStrokeHand.left,
            articulation: LedStrokeArticulation.ghost,
          ),
          LedStroke(
            hand: LedStrokeHand.right,
            articulation: LedStrokeArticulation.accent,
          ),
        ]).protocolValue,
        '(L)^R',
      );
      expect(
        StickingCue.fromStrokes(const <LedStroke>[
          LedStroke(
            hand: LedStrokeHand.right,
            articulation: LedStrokeArticulation.ghost,
          ),
          LedStroke(
            hand: LedStrokeHand.left,
            articulation: LedStrokeArticulation.accent,
          ),
        ]).protocolValue,
        '(R)^L',
      );
    });

    test('single voice frame serializes with resolved sticking', () {
      const LedFrameCommandEncoder encoder = LedFrameCommandEncoder();

      expect(
        encoder.encodeSolidFrame(const <LedCue>[LedCue(DrumVoice.snare)]),
        'FRAME_BEGIN\nANIMATION,SOLID,55\nCUE,SNARE,R\nFRAME_END\n',
      );
    });

    test('sticking values serialize using semantic stroke tokens', () {
      const LedFrameCommandEncoder encoder = LedFrameCommandEncoder();

      final String? frame = encoder.encodeFlashFrame(const <LedCue>[
        LedCue(DrumVoice.snare, sticking: StickingCue.left),
        LedCue(DrumVoice.kick, sticking: StickingCue.right),
        LedCue(DrumVoice.tom1, sticking: StickingCue.leftRight),
        LedCue(DrumVoice.tom2, sticking: StickingCue.ghostRightLeft),
        LedCue(DrumVoice.floorTom, sticking: StickingCue.ghostLeftRight),
        LedCue(DrumVoice.crash, sticking: StickingCue.ghostLeft),
        LedCue(DrumVoice.ride, sticking: StickingCue.ghostRight),
        LedCue(DrumVoice.hiHatClosed, sticking: StickingCue.accentRight),
      ]);

      expect(
        frame,
        'FRAME_BEGIN\n'
        'ANIMATION,FLASH,220\n'
        'CUE,SNARE,L\n'
        'CUE,KICK,R\n'
        'CUE,TOM1,LR\n'
        'CUE,TOM2,(R)L\n'
        'CUE,FLOORTOM,(L)R\n'
        'CUE,CRASH,(L)\n'
        'CUE,RIDE,(R)\n'
        'CUE,HIHAT,^R\n'
        'FRAME_END\n',
      );
    });

    test('unsupported voices are skipped in frames', () {
      const LedFrameCommandEncoder encoder = LedFrameCommandEncoder();

      expect(
        encoder.encodeFadeInFrame(const <LedCue>[
          LedCue(DrumVoice.unknown),
          LedCue(DrumVoice.ride),
        ]),
        'FRAME_BEGIN\nANIMATION,FADE_IN,250,180\nCUE,RIDE,R\nFRAME_END\n',
      );
    });

    test('open hi-hat cue frames serialize as OHH', () {
      const LedFrameCommandEncoder encoder = LedFrameCommandEncoder();

      expect(
        encoder.encodeFlashFrame(const <LedCue>[
          LedCue(DrumVoice.hiHatClosed),
          LedCue(DrumVoice.hiHatOpen),
        ]),
        'FRAME_BEGIN\n'
        'ANIMATION,FLASH,220\n'
        'CUE,HIHAT,R\n'
        'CUE,OHH,R\n'
        'FRAME_END\n',
      );
    });

    test('non-snare voices can carry hand sticking', () {
      const LedFrameCommandEncoder encoder = LedFrameCommandEncoder();

      expect(
        encoder.encodeSolidFrame(const <LedCue>[
          LedCue(DrumVoice.tom1, sticking: StickingCue.left),
          LedCue(DrumVoice.ride, sticking: StickingCue.right),
        ]),
        'FRAME_BEGIN\nANIMATION,SOLID,55\nCUE,TOM1,L\nCUE,RIDE,R\nFRAME_END\n',
      );
    });

    test('animation and orientation responses parse', () {
      final LedControllerResponse animation = parseLedControllerResponse(
        'OK:ANIMATION:FADE_IN:250:180',
      );
      expect(animation, isA<LedAnimationAckResponse>());
      expect((animation as LedAnimationAckResponse).frameCommitted, false);
      expect(
        animation.animation,
        const LedFrameAnimation.fadeIn(leadMs: 250, decayMs: 180),
      );

      final LedControllerResponse frame = parseLedControllerResponse(
        'OK:FRAME_END:FLASH:220',
      );
      expect(frame, isA<LedAnimationAckResponse>());
      expect((frame as LedAnimationAckResponse).frameCommitted, true);
      expect(frame.animation, const LedFrameAnimation.flash(220));

      final LedControllerResponse orientation = parseLedControllerResponse(
        'OK:ORIENTATION:HIHAT:RIGHT',
      );
      expect(orientation, isA<LedOrientationValueResponse>());
      expect(
        (orientation as LedOrientationValueResponse).voice,
        LedControllerVoice.hiHat,
      );
      expect(orientation.orientation, LedOrientation.right);

      final LedControllerResponse error = parseLedControllerResponse(
        'ERROR:ANIMATION_REQUIRED',
      );
      expect(error, isA<LedControllerErrorResponse>());
      expect((error as LedControllerErrorResponse).code, 'ANIMATION_REQUIRED');
    });

    test('feedback command includes resolved sticking', () {
      const LedFrameCommandEncoder encoder = LedFrameCommandEncoder();

      expect(
        encoder.feedbackCommand(
          'MISSING',
          const LedCue(
            DrumVoice.hiHatClosed,
            sticking: StickingCue.ghostLeftRight,
          ),
        ),
        'MISSING,HIHAT,(L)R\n',
      );
      expect(
        encoder.feedbackCommand('ERROR', const LedCue(DrumVoice.snare)),
        'ERROR,SNARE,R\n',
      );
    });

    test('Test Flash command sends SNARE newline', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();
      platform.lastConnection.writes.clear();
      controller.sendCommand(DrumVoiceLedCommandMapper.snareCommand);

      expect(platform.lastConnection.writes, <String>['SNARE\n']);
    });

    test('cue frame writes the full frame as one payload', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();
      platform.lastConnection.writes.clear();
      controller.sendFlashFrame(const <LedCue>[
        LedCue(DrumVoice.kick),
        LedCue(DrumVoice.hiHatClosed, sticking: StickingCue.right),
      ]);

      expect(platform.lastConnection.writes, <String>[
        'FRAME_BEGIN\n'
            'ANIMATION,FLASH,220\n'
            'CUE,KICK,R\n'
            'CUE,HIHAT,R\n'
            'FRAME_END\n',
      ]);
    });

    test('connection requests and stores controller orientation', () async {
      final _FakeSerialPlatform platform = _FakeSerialPlatform();
      final SerialLedController controller = SerialLedController(
        platform: platform,
      );
      addTearDown(controller.dispose);

      await controller.refreshPorts();
      controller.selectPort(_FakeSerialPlatform.esp32.path);
      await controller.connect();

      expect(platform.lastConnection.writes, <String>[
        'SYS,GET,ORIENTATION,ALL\n',
      ]);

      platform.lastConnection.emitLine('ORIENTATION:SNARE:LEFT');
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.orientations[LedControllerVoice.snare],
        LedOrientation.left,
      );
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
      platform.lastConnection.writes.clear();
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

      platform.listError = null;
      await controller.refreshPorts();

      expect(controller.status, SerialLedConnectionStatus.connected);
      expect(controller.lastError, isNull);
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
    platform.lastConnection.writes.clear();
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
  final StreamController<Uint8List> _inputController =
      StreamController<Uint8List>.broadcast();
  bool closed = false;

  @override
  bool get isOpen => !closed;

  @override
  Stream<Uint8List> get input => _inputController.stream;

  void emitLine(String line) {
    _inputController.add(Uint8List.fromList(utf8.encode('$line\n')));
  }

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
