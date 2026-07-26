import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../midi/drum_kit_mapper.dart';
import '../midi/led_controller_protocol.dart';
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

Future<void> showHardwareConnectionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const HardwareConnectionDialog(),
  );
}

class HardwareConnectionDialog extends StatefulWidget {
  const HardwareConnectionDialog({super.key});

  @override
  State<HardwareConnectionDialog> createState() =>
      _HardwareConnectionDialogState();
}

class _HardwareConnectionDialogState extends State<HardwareConnectionDialog> {
  late final MidiInputService _midiService = SharedMidiInputService.instance;
  late final SerialLedController _ledController =
      SharedSerialLedController.instance;
  bool _hardwareUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _midiService.addListener(_handleHardwareChanged);
    _ledController.addListener(_handleHardwareChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_midiService.start());
      unawaited(_ledController.refreshPorts());
    });
  }

  @override
  void dispose() {
    _midiService.removeListener(_handleHardwareChanged);
    _ledController.removeListener(_handleHardwareChanged);
    super.dispose();
  }

  void _handleHardwareChanged() {
    if (!mounted || _hardwareUpdateScheduled) return;
    _hardwareUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hardwareUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DrumcabularyTheme.edgeSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: DrumcabularyTheme.edgeBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Devices',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: DrumcabularyTheme.edgeTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _QuickMidiInputPanel(
                service: _midiService,
                onRefresh: () => unawaited(_midiService.scanDevices()),
                onSelect: _selectMidiDevice,
                onConnect: _connectSelectedMidiDevice,
                onDisconnect: () => unawaited(_midiService.disconnect()),
              ),
              const SizedBox(height: 12),
              _QuickLedControllerPanel(
                controller: _ledController,
                onRefresh: () => unawaited(_ledController.refreshPorts()),
                onSelect: _selectLedPort,
                onConnect: () => unawaited(_ledController.connect()),
                onDisconnect: () => unawaited(_ledController.disconnect()),
              ),
            ],
          ),
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

  void _connectSelectedMidiDevice() {
    final MidiInputDevice? device = _midiService.selectedDevice;
    if (device == null) return;
    unawaited(_midiService.connectToDevice(device));
  }

  void _selectLedPort(String? path) {
    if (path == null) return;
    unawaited(_ledController.selectPortAndConnect(path));
  }
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
  bool _hardwareUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _midiService.addListener(_handleHardwareChanged);
    _ledController.addListener(_handleHardwareChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_midiService.start());
      unawaited(_ledController.refreshPorts());
      if (_ledController.isConnected) {
        _ledController.requestOrientations();
      }
    });
  }

  @override
  void dispose() {
    _testInputSubscription?.cancel();
    _midiService.removeListener(_handleHardwareChanged);
    _ledController.removeListener(_handleHardwareChanged);
    super.dispose();
  }

  void _handleHardwareChanged() {
    if (!mounted || _hardwareUpdateScheduled) return;
    _hardwareUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hardwareUpdateScheduled = false;
      if (mounted) setState(() {});
    });
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
              onSelect: _selectLedPort,
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

  void _selectLedPort(String? path) {
    if (path == null) return;
    unawaited(_ledController.selectPortAndConnect(path));
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
    _ledController.sendFlashFrame(const <LedCue>[
      LedCue(DrumVoice.snare, sticking: StickingCue.right),
      LedCue(DrumVoice.kick, sticking: StickingCue.right),
      LedCue(DrumVoice.hiHatClosed, sticking: StickingCue.ghostLeft),
      LedCue(DrumVoice.crash, sticking: StickingCue.accentRight),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _ledController.sendCommand(ledClearCommand);
    if (mounted) setState(() => _testingLeds = false);
  }
}

class _QuickMidiInputPanel extends StatelessWidget {
  final MidiInputService service;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelect;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _QuickMidiInputPanel({
    required this.service,
    required this.onRefresh,
    required this.onSelect,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final bool connected = service.status == MidiInputStatus.connected;
    final String? selectedDeviceId = _selectedMidiDeviceId(service);
    return DrumPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DrumSectionTitle(text: 'MIDI Kit'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey<String?>(
              'quick-midi-${selectedDeviceId ?? 'none'}-${service.devices.length}',
            ),
            initialValue: selectedDeviceId,
            decoration: const InputDecoration(
              labelText: 'Device',
              border: OutlineInputBorder(),
            ),
            items: service.devices
                .map(
                  (MidiInputDevice device) => DropdownMenuItem<String>(
                    value: device.id,
                    child: Text(device.name),
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
                onPressed: connected || service.selectedDevice != null
                    ? connected
                          ? onDisconnect
                          : onConnect
                    : null,
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLedControllerPanel extends StatelessWidget {
  final SerialLedController controller;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelect;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _QuickLedControllerPanel({
    required this.controller,
    required this.onRefresh,
    required this.onSelect,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final bool connected = controller.isConnected;
    final String? selectedPortPath = _selectedLedPortPath(controller);
    return DrumPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DrumSectionTitle(text: 'LED Controller'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey<String?>(
              'quick-led-${selectedPortPath ?? 'none'}-${controller.ports.length}',
            ),
            initialValue: selectedPortPath,
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
            error: controller.controllerSettingsError ?? controller.lastError,
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
                onPressed: connected || controller.selectedPort != null
                    ? connected
                          ? onDisconnect
                          : onConnect
                    : null,
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        ],
      ),
    );
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
            error: controller.controllerSettingsError ?? controller.lastError,
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
          if (connected) ...<Widget>[
            const SizedBox(height: 16),
            _LedOrientationSettings(controller: controller),
          ],
        ],
      ),
    );
  }
}

class _LedOrientationSettings extends StatelessWidget {
  final SerialLedController controller;

  const _LedOrientationSettings({required this.controller});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'LED Orientation',
          style: textTheme.labelLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set which end of each physical stick has the DI connector.',
          style: textTheme.bodySmall?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (final LedControllerVoice voice in LedControllerVoice.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(child: Text(voice.displayName)),
                if (controller.pendingOrientations.contains(voice))
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                DropdownButton<LedOrientation>(
                  value: controller.orientations[voice],
                  hint: const Text('Unknown'),
                  items: LedOrientation.values
                      .map(
                        (LedOrientation orientation) =>
                            DropdownMenuItem<LedOrientation>(
                              value: orientation,
                              child: Text(orientation.protocolName),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (LedOrientation? orientation) {
                    if (orientation == null) return;
                    controller.setOrientation(voice, orientation);
                  },
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => controller.requestOrientations(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Orientation'),
            ),
            OutlinedButton.icon(
              onPressed: () => controller.resetOrientations(),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset Orientation'),
            ),
          ],
        ),
      ],
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

String? _selectedMidiDeviceId(MidiInputService service) {
  final String? selectedId = service.selectedDevice?.id;
  if (selectedId == null) return null;
  return service.devices.any(
        (MidiInputDevice device) => device.id == selectedId,
      )
      ? selectedId
      : null;
}

String? _selectedLedPortPath(SerialLedController controller) {
  final String? selectedPath = controller.selectedPort?.path;
  if (selectedPath == null) return null;
  return controller.ports.any((SerialLedPort port) => port.path == selectedPath)
      ? selectedPath
      : null;
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
