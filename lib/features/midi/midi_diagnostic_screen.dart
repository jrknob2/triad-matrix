import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import 'bounded_midi_event_log.dart';
import 'drum_kit_mapper.dart';
import 'midi_input_models.dart';
import 'midi_input_service.dart';

class MidiDiagnosticScreen extends StatefulWidget {
  const MidiDiagnosticScreen({super.key});

  @override
  State<MidiDiagnosticScreen> createState() => _MidiDiagnosticScreenState();
}

class _MidiDiagnosticScreenState extends State<MidiDiagnosticScreen> {
  late final MidiInputService _service;
  late final DrumKitMapper _mapper;
  late final BoundedMidiEventLog _eventLog;
  StreamSubscription<RawMidiEvent>? _eventSubscription;
  MidiDiagnosticEvent? _latestEvent;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _service = MidiInputService()..addListener(_handleServiceChanged);
    _mapper = const DrumKitMapper();
    _eventLog = BoundedMidiEventLog(maxEntries: 100);
    _eventSubscription = _service.events.listen(_handleRawMidiEvent);
    unawaited(_service.start());
  }

  @override
  void dispose() {
    _service.removeListener(_handleServiceChanged);
    unawaited(_eventSubscription?.cancel());
    _service.dispose();
    super.dispose();
  }

  void _handleServiceChanged() {
    if (!mounted) return;
    setState(() {
      if (_selectedDeviceId != null &&
          !_service.devices.any(
            (MidiInputDevice device) => device.id == _selectedDeviceId,
          )) {
        _selectedDeviceId = null;
      }
    });
  }

  void _handleRawMidiEvent(RawMidiEvent event) {
    final MidiDiagnosticEvent diagnosticEvent = MidiDiagnosticEvent(
      raw: event,
      drum: _mapper.map(event),
    );
    if (!mounted) return;
    setState(() {
      _latestEvent = diagnosticEvent;
      _eventLog.add(diagnosticEvent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MIDI Input Diagnostic')),
      body: DrumScreen(
        warm: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              const DrumEyebrow(text: 'DEVELOPER TOOL'),
              const SizedBox(height: 8),
              Text(
                'USB MIDI input path',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use this screen to verify that a drum module reaches Drumcabulary through macOS CoreMIDI.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DrumcabularyTheme.edgeTextSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              _ConnectionPanel(
                service: _service,
                selectedDeviceId: _selectedDeviceId,
                onDeviceSelected: (String? id) {
                  setState(() => _selectedDeviceId = id);
                },
                onScan: () => unawaited(_service.scanDevices()),
                onConnect: _connectSelectedDevice,
                onDisconnect: () => unawaited(_service.disconnect()),
              ),
              const SizedBox(height: 14),
              _LatestEventPanel(event: _latestEvent),
              const SizedBox(height: 14),
              _EventLogPanel(
                events: _eventLog.events,
                onClear: () {
                  setState(() {
                    _eventLog.clear();
                    _latestEvent = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              _NoteMapPanel(mapper: _mapper),
            ],
          ),
        ),
      ),
    );
  }

  void _connectSelectedDevice() {
    final MidiInputDevice? device = _selectedDevice();
    if (device == null) return;
    unawaited(_service.connectToDevice(device));
  }

  MidiInputDevice? _selectedDevice() {
    if (_selectedDeviceId != null) {
      for (final MidiInputDevice device in _service.devices) {
        if (device.id == _selectedDeviceId) return device;
      }
    }
    final Iterable<MidiInputDevice> lekatoCandidates = _service.devices.where(
      (MidiInputDevice device) => device.isLikelyLekato,
    );
    if (lekatoCandidates.isNotEmpty) return lekatoCandidates.first;
    if (_service.devices.isNotEmpty) return _service.devices.first;
    return null;
  }
}

class _ConnectionPanel extends StatelessWidget {
  final MidiInputService service;
  final String? selectedDeviceId;
  final ValueChanged<String?> onDeviceSelected;
  final VoidCallback onScan;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectionPanel({
    required this.service,
    required this.selectedDeviceId,
    required this.onDeviceSelected,
    required this.onScan,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDevices = service.devices.isNotEmpty;
    final bool connected = service.status == MidiInputStatus.connected;
    final bool connecting = service.status == MidiInputStatus.connecting;
    final String? dropdownValue = _dropdownValue();

    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Devices',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(status: service.status),
            ],
          ),
          const SizedBox(height: 14),
          if (service.status == MidiInputStatus.scanning)
            const LinearProgressIndicator(minHeight: 3),
          if (!hasDevices && service.status != MidiInputStatus.scanning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No MIDI input devices found.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DrumcabularyTheme.edgeTextSecondary,
                ),
              ),
            ),
          if (hasDevices)
            DropdownButtonFormField<String>(
              key: ValueKey<String?>(dropdownValue),
              initialValue: dropdownValue,
              dropdownColor: DrumcabularyTheme.edgeSurfaceSecondary,
              decoration: const InputDecoration(
                labelText: 'MIDI input device',
                border: OutlineInputBorder(),
              ),
              items: service.devices
                  .map(
                    (MidiInputDevice device) => DropdownMenuItem<String>(
                      value: device.id,
                      child: Text(_deviceLabel(device)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: connected || connecting ? null : onDeviceSelected,
            ),
          if (service.lastError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              service.lastError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 14),
          DrumActionRow(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: connecting ? null : onScan,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Rescan'),
              ),
              if (connected)
                FilledButton.icon(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect'),
                )
              else
                FilledButton.icon(
                  onPressed: hasDevices && !connecting ? onConnect : null,
                  icon: const Icon(Icons.usb_rounded),
                  label: Text(connecting ? 'Connecting' : 'Connect'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _dropdownValue() {
    if (selectedDeviceId != null &&
        service.devices.any(
          (MidiInputDevice device) => device.id == selectedDeviceId,
        )) {
      return selectedDeviceId;
    }
    final MidiInputDevice? selectedDevice = service.selectedDevice;
    if (selectedDevice != null &&
        service.devices.any(
          (MidiInputDevice device) => device.id == selectedDevice.id,
        )) {
      return selectedDevice.id;
    }
    final Iterable<MidiInputDevice> lekatoCandidates = service.devices.where(
      (MidiInputDevice device) => device.isLikelyLekato,
    );
    if (lekatoCandidates.isNotEmpty) return lekatoCandidates.first.id;
    if (service.devices.isNotEmpty) return service.devices.first.id;
    return null;
  }

  String _deviceLabel(MidiInputDevice device) {
    final String connection = device.connected ? 'connected' : 'available';
    final String lekato = device.isLikelyLekato ? ' - LEKATO edrum' : '';
    return '${device.name} ($connection, ${device.type})$lekato';
  }
}

class _StatusPill extends StatelessWidget {
  final MidiInputStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      MidiInputStatus.connected => DrumcabularyTheme.edgeOrange,
      MidiInputStatus.connecting ||
      MidiInputStatus.scanning => DrumcabularyTheme.edgeOrangePressed,
      MidiInputStatus.connectionError => Theme.of(context).colorScheme.error,
      MidiInputStatus.noDevicesFound ||
      MidiInputStatus.disconnected => DrumcabularyTheme.edgeSurfaceSecondary,
    };

    return DrumStatusPill(label: _statusLabel(status), color: color);
  }
}

class _LatestEventPanel extends StatelessWidget {
  final MidiDiagnosticEvent? event;

  const _LatestEventPanel({required this.event});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      tone: DrumPanelTone.warm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Latest event',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            event == null
                ? 'Strike a pad after connecting a MIDI input device.'
                : _formatEvent(event!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: event == null
                  ? DrumcabularyTheme.edgeTextSecondary
                  : DrumcabularyTheme.edgeTextPrimary,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLogPanel extends StatelessWidget {
  final List<MidiDiagnosticEvent> events;
  final VoidCallback onClear;

  const _EventLogPanel({required this.events, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final List<MidiDiagnosticEvent> displayEvents = events.reversed.toList(
      growable: false,
    );

    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Event log',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                onPressed: events.isEmpty ? null : onClear,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            Text(
              'No MIDI events received yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: displayEvents.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final MidiDiagnosticEvent event = displayEvents[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _formatEvent(event),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DrumcabularyTheme.edgeTextSecondary,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                        height: 1.25,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteMapPanel extends StatelessWidget {
  final DrumKitMapper mapper;

  const _NoteMapPanel({required this.mapper});

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<int, DrumVoice>> entries =
        mapper.noteMap.notes.entries.toList(growable: false)
          ..sort((MapEntry<int, DrumVoice> a, MapEntry<int, DrumVoice> b) {
            return a.key.compareTo(b.key);
          });

    return DrumPanel(
      tone: DrumPanelTone.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Note map',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${mapper.noteMap.name}. Unknown notes stay visible as unknown.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entries
                .map((MapEntry<int, DrumVoice> entry) {
                  return Chip(
                    label: Text('${entry.key} ${_voiceLabel(entry.value)}'),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

String _formatEvent(MidiDiagnosticEvent event) {
  final RawMidiEvent raw = event.raw;
  final String channel = raw.channel <= 0 ? '-' : raw.channel.toString();
  return '${_formatTimestamp(raw.timestamp)} | ${raw.deviceName} | '
      'Ch $channel | ${_messageTypeLabel(raw.messageType)} | '
      'Note ${raw.note} | Velocity ${raw.velocity} | '
      '${_voiceLabel(event.drum.voice)}';
}

String _formatTimestamp(DateTime timestamp) {
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${two(timestamp.hour)}:${two(timestamp.minute)}:'
      '${two(timestamp.second)}.${three(timestamp.millisecond)}';
}

String _messageTypeLabel(MidiMessageType messageType) {
  return switch (messageType) {
    MidiMessageType.noteOn => 'Note On',
    MidiMessageType.noteOff => 'Note Off',
    MidiMessageType.controlChange => 'Control Change',
    MidiMessageType.other => 'Other',
  };
}

String _statusLabel(MidiInputStatus status) {
  return switch (status) {
    MidiInputStatus.scanning => 'Scanning',
    MidiInputStatus.noDevicesFound => 'No Devices',
    MidiInputStatus.disconnected => 'Disconnected',
    MidiInputStatus.connecting => 'Connecting',
    MidiInputStatus.connected => 'Connected',
    MidiInputStatus.connectionError => 'Error',
  };
}

String _voiceLabel(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.snare => 'snare',
    DrumVoice.kick => 'kick',
    DrumVoice.hiHatClosed => 'hi-hat closed',
    DrumVoice.hiHatOpen => 'hi-hat open',
    DrumVoice.hiHatPedal => 'hi-hat pedal',
    DrumVoice.tom1 => 'tom 1',
    DrumVoice.tom2 => 'tom 2',
    DrumVoice.floorTom => 'floor tom',
    DrumVoice.crash => 'crash',
    DrumVoice.ride => 'ride',
    DrumVoice.unknown => 'unknown',
  };
}
