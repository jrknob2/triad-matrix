import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../midi/drum_kit_mapper.dart';
import '../midi/led_frame_command_encoder.dart';
import '../midi/midi_input_models.dart';
import '../midi/midi_input_service.dart';
import '../midi/serial_led_controller.dart';
import '../midi/shared_midi_input_service.dart';
import '../midi/shared_serial_led_controller.dart';
import '../practice/sticking_cue.dart';

class HardwareMidiSettingsScreen extends StatefulWidget {
  const HardwareMidiSettingsScreen({super.key});

  @override
  State<HardwareMidiSettingsScreen> createState() =>
      _HardwareMidiSettingsScreenState();
}

class _HardwareMidiSettingsScreenState
    extends State<HardwareMidiSettingsScreen> {
  static const Duration _testInputTimeout = Duration(seconds: 5);

  late final MidiInputService _midiService = SharedMidiInputService.instance;
  late final SerialLedController _ledController =
      SharedSerialLedController.instance;
  final DrumKitMapper _drumKitMapper = const DrumKitMapper();

  StreamSubscription<RawMidiEvent>? _testInputSubscription;
  String? _testInputMessage;
  bool _testingInput = false;
  bool _testingLeds = false;

  @override
  void initState() {
    super.initState();
    _midiService.addListener(_handleHardwareChanged);
    _ledController.addListener(_handleHardwareChanged);
    unawaited(_midiService.start());
    unawaited(_ledController.refreshPorts());
  }

  @override
  void dispose() {
    _testInputSubscription?.cancel();
    _midiService.removeListener(_handleHardwareChanged);
    _ledController.removeListener(_handleHardwareChanged);
    super.dispose();
  }

  void _handleHardwareChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hardware & MIDI')),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            _MidiInputPanel(
              service: _midiService,
              testingInput: _testingInput,
              testMessage: _testInputMessage,
              onRefresh: () => unawaited(_midiService.scanDevices()),
              onSelect: _selectMidiDevice,
              onConnect: _connectSelectedMidiDevice,
              onDisconnect: () => unawaited(_midiService.disconnect()),
              onTest: _testMidiInput,
            ),
            const SizedBox(height: 12),
            _LedControllerPanel(
              controller: _ledController,
              testingLeds: _testingLeds,
              onRefresh: () => unawaited(_ledController.refreshPorts()),
              onSelect: _ledController.selectPort,
              onConnect: () => unawaited(_ledController.connect()),
              onDisconnect: () => unawaited(_ledController.disconnect()),
              onTest: _testLeds,
            ),
          ],
        ),
      ),
    );
  }

  void _selectMidiDevice(String? id) {
    if (id == null) return;
    for (final MidiInputDevice device in _midiService.devices) {
      if (device.id == id) {
        unawaited(_midiService.connectToDevice(device));
        return;
      }
    }
  }

  Future<void> _connectSelectedMidiDevice() async {
    final MidiInputDevice? device = _midiService.selectedDevice;
    if (device == null) {
      setState(() {
        _testInputMessage = 'Select a MIDI input before connecting.';
      });
      return;
    }
    await _midiService.connectToDevice(device);
  }

  Future<void> _testMidiInput() async {
    await _testInputSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _testingInput = true;
      _testInputMessage = 'Listening for one MIDI hit...';
    });

    final Completer<void> completer = Completer<void>();
    Timer? timeout;
    timeout = Timer(_testInputTimeout, () {
      if (!completer.isCompleted) completer.complete();
      if (!mounted) return;
      setState(() {
        _testingInput = false;
        _testInputMessage = 'No MIDI hit received.';
      });
      unawaited(_testInputSubscription?.cancel());
      _testInputSubscription = null;
    });

    _testInputSubscription = _midiService.events.listen((RawMidiEvent raw) {
      if (raw.messageType != MidiMessageType.noteOn || raw.velocity <= 0) {
        return;
      }
      timeout?.cancel();
      if (!completer.isCompleted) completer.complete();
      final DrumInputEvent mapped = _drumKitMapper.map(raw);
      if (mounted) {
        setState(() {
          _testingInput = false;
          _testInputMessage =
              'Received ${_voiceLabel(mapped.voice)} from ${raw.deviceName}.';
        });
      }
      unawaited(_testInputSubscription?.cancel());
      _testInputSubscription = null;
    });

    await completer.future;
  }

  Future<void> _testLeds() async {
    if (!_ledController.isConnected) return;
    setState(() => _testingLeds = true);
    _ledController.sendCueFrame(const <LedCue>[
      LedCue(DrumVoice.snare, sticking: StickingCue.right),
      LedCue(DrumVoice.kick, sticking: StickingCue.right),
      LedCue(DrumVoice.hiHatClosed, sticking: StickingCue.ghostLeft),
      LedCue(DrumVoice.crash, sticking: StickingCue.accentRight),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _ledController.sendCommand('CLEAR');
    if (mounted) setState(() => _testingLeds = false);
  }
}

class _MidiInputPanel extends StatelessWidget {
  final MidiInputService service;
  final bool testingInput;
  final String? testMessage;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelect;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onTest;

  const _MidiInputPanel({
    required this.service,
    required this.testingInput,
    required this.testMessage,
    required this.onRefresh,
    required this.onSelect,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final bool connected = service.status == MidiInputStatus.connected;
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DrumSectionTitle(text: 'MIDI Input'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: service.selectedDevice?.id,
            decoration: const InputDecoration(
              labelText: 'Device',
              border: OutlineInputBorder(),
            ),
            items: service.devices
                .map(
                  (MidiInputDevice device) => DropdownMenuItem<String>(
                    value: device.id,
                    child: Text('${device.name} | ${device.type}'),
                  ),
                )
                .toList(growable: false),
            onChanged: connected ? null : onSelect,
          ),
          const SizedBox(height: 10),
          _StatusText(
            label: _midiStatusLabel(service.status),
            error: service.lastError,
          ),
          if (testMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              testMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
              FilledButton(
                onPressed: connected ? onDisconnect : onConnect,
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
              OutlinedButton(
                onPressed: connected && !testingInput ? onTest : null,
                child: Text(testingInput ? 'Listening...' : 'Test Input'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedControllerPanel extends StatelessWidget {
  final SerialLedController controller;
  final bool testingLeds;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelect;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onTest;

  const _LedControllerPanel({
    required this.controller,
    required this.testingLeds,
    required this.onRefresh,
    required this.onSelect,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final bool connected = controller.isConnected;
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DrumSectionTitle(text: 'LED Controller'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: controller.selectedPort?.path,
            decoration: const InputDecoration(
              labelText: 'Serial Device',
              border: OutlineInputBorder(),
            ),
            items: controller.ports
                .map(
                  (SerialLedPort port) => DropdownMenuItem<String>(
                    value: port.path,
                    child: Text(port.displayName),
                  ),
                )
                .toList(growable: false),
            onChanged: connected ? null : onSelect,
          ),
          const SizedBox(height: 10),
          _StatusText(
            label: _serialStatusLabel(controller.status),
            error: controller.lastError,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
              FilledButton(
                onPressed: connected ? onDisconnect : onConnect,
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
              OutlinedButton(
                onPressed: connected && !testingLeds ? onTest : null,
                child: Text(testingLeds ? 'Testing...' : 'Test LEDs'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final String label;
  final String? error;

  const _StatusText({required this.label, required this.error});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: textTheme.bodyMedium),
        if (error != null && error!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            error!,
            style: textTheme.bodySmall?.copyWith(
              color: DrumcabularyTheme.edgeOrange,
            ),
          ),
        ],
      ],
    );
  }
}

String _midiStatusLabel(MidiInputStatus status) {
  return switch (status) {
    MidiInputStatus.scanning => 'Scanning',
    MidiInputStatus.noDevicesFound => 'No MIDI input devices found',
    MidiInputStatus.disconnected => 'Disconnected',
    MidiInputStatus.connecting => 'Connecting',
    MidiInputStatus.connected => 'Connected',
    MidiInputStatus.connectionError => 'Connection error',
  };
}

String _serialStatusLabel(SerialLedConnectionStatus status) {
  return switch (status) {
    SerialLedConnectionStatus.disconnected => 'Disconnected',
    SerialLedConnectionStatus.connecting => 'Connecting',
    SerialLedConnectionStatus.connected => 'Connected',
    SerialLedConnectionStatus.connectionError => 'Connection error',
    SerialLedConnectionStatus.deviceRemoved => 'Device removed',
  };
}

String _voiceLabel(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.snare => 'snare',
    DrumVoice.kick => 'kick',
    DrumVoice.hiHatClosed => 'closed hi-hat',
    DrumVoice.hiHatOpen => 'open hi-hat',
    DrumVoice.hiHatPedal => 'hi-hat pedal',
    DrumVoice.tom1 => 'tom 1',
    DrumVoice.tom2 => 'tom 2',
    DrumVoice.floorTom => 'floor tom',
    DrumVoice.crash => 'crash',
    DrumVoice.ride => 'ride',
    DrumVoice.unknown => 'unknown note',
  };
}
