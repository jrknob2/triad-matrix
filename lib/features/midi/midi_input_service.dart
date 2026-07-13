import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart' as midi;

import 'midi_input_models.dart';
import 'raw_midi_message_parser.dart';

class MidiInputService extends ChangeNotifier {
  final midi.MidiCommand _midiCommand;
  final StreamController<RawMidiEvent> _eventController =
      StreamController<RawMidiEvent>.broadcast();
  final Map<String, midi.MidiDevice> _platformDevicesById =
      <String, midi.MidiDevice>{};
  final Map<String, RawMidiMessageParser> _parsersByDeviceId =
      <String, RawMidiMessageParser>{};

  StreamSubscription<midi.MidiPacket>? _packetSubscription;
  StreamSubscription<midi.MidiSetupChange>? _setupSubscription;
  StreamSubscription<midi.MidiConnectionState>? _deviceStateSubscription;

  List<MidiInputDevice> _devices = const <MidiInputDevice>[];
  MidiInputDevice? _selectedDevice;
  midi.MidiDevice? _selectedPlatformDevice;
  MidiInputStatus _status = MidiInputStatus.disconnected;
  String? _lastError;
  bool _started = false;
  bool _disposed = false;

  MidiInputService({midi.MidiCommand? midiCommand})
    : _midiCommand = midiCommand ?? midi.MidiCommand();

  Stream<RawMidiEvent> get events => _eventController.stream;
  List<MidiInputDevice> get devices => _devices;
  MidiInputDevice? get selectedDevice => _selectedDevice;
  MidiInputStatus get status => _status;
  String? get lastError => _lastError;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _midiCommand.configureBleTransport(null);
    _midiCommand.configureTransportPolicy(
      const midi.MidiTransportPolicy(
        excludedTransports: <midi.MidiTransport>{midi.MidiTransport.ble},
      ),
    );

    _setupSubscription = _midiCommand.onMidiSetupChanged?.listen(
      (_) => unawaited(scanDevices()),
      onError: _handleStreamError,
    );
    _packetSubscription = _midiCommand.onMidiPacketReceived?.listen(
      _handlePacket,
      onError: _handleStreamError,
    );

    await scanDevices();
  }

  Future<void> scanDevices() async {
    if (_disposed) return;
    _setStatus(MidiInputStatus.scanning);

    try {
      final List<midi.MidiDevice> platformDevices =
          await _midiCommand.devices ?? <midi.MidiDevice>[];
      if (_disposed) return;

      _platformDevicesById
        ..clear()
        ..addEntries(
          platformDevices.map(
            (device) => MapEntry<String, midi.MidiDevice>(device.id, device),
          ),
        );
      _devices = platformDevices.map(_snapshotDevice).toList(growable: false);

      final String? selectedId = _selectedDevice?.id;
      if (selectedId != null) {
        _selectedPlatformDevice = _platformDevicesById[selectedId];
        if (_selectedPlatformDevice == null) {
          await _deviceStateSubscription?.cancel();
          _deviceStateSubscription = null;
          _selectedDevice = null;
          _parsersByDeviceId.remove(selectedId);
        } else {
          _selectedDevice = _snapshotDevice(_selectedPlatformDevice!);
        }
      }

      if (_devices.isEmpty) {
        _setStatus(MidiInputStatus.noDevicesFound);
      } else if (_selectedPlatformDevice?.connected == true) {
        _setStatus(MidiInputStatus.connected);
      } else {
        _setStatus(MidiInputStatus.disconnected);
      }
    } catch (error) {
      _setStatus(
        MidiInputStatus.connectionError,
        error: 'Device scan failed: $error',
      );
    }
  }

  Future<void> connectToDevice(MidiInputDevice device) async {
    final midi.MidiDevice? platformDevice = _platformDevicesById[device.id];
    if (platformDevice == null) {
      _setStatus(
        MidiInputStatus.connectionError,
        error: 'Device is no longer available: ${device.name}',
      );
      return;
    }

    _selectedDevice = device;
    _selectedPlatformDevice = platformDevice;
    _setStatus(MidiInputStatus.connecting);

    try {
      await _deviceStateSubscription?.cancel();
      _deviceStateSubscription = platformDevice.onConnectionStateChanged.listen(
        _handleDeviceConnectionState,
      );
      await _midiCommand.connectToDevice(platformDevice);
      _selectedDevice = _snapshotDevice(platformDevice);
      _setStatus(MidiInputStatus.connected);
    } catch (error) {
      _setStatus(
        MidiInputStatus.connectionError,
        error: 'Connection failed for ${device.name}: $error',
      );
    }
  }

  Future<void> disconnect() async {
    final midi.MidiDevice? platformDevice = _selectedPlatformDevice;
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    if (platformDevice != null) {
      try {
        _midiCommand.disconnectDevice(platformDevice);
      } catch (error) {
        _setStatus(
          MidiInputStatus.connectionError,
          error: 'Disconnect failed for ${platformDevice.name}: $error',
        );
        return;
      }
    }

    _selectedDevice = null;
    _selectedPlatformDevice = null;
    _setStatus(
      _devices.isEmpty
          ? MidiInputStatus.noDevicesFound
          : MidiInputStatus.disconnected,
    );
  }

  void _handlePacket(midi.MidiPacket packet) {
    if (_disposed) return;
    final midi.MidiDevice packetDevice = packet.device;
    final String deviceId = packetDevice.id.isNotEmpty
        ? packetDevice.id
        : (_selectedDevice?.id ?? 'unknown');
    final String deviceName = packetDevice.name.isNotEmpty
        ? packetDevice.name
        : (_selectedDevice?.name ?? 'Unknown MIDI device');
    final RawMidiMessageParser parser = _parsersByDeviceId.putIfAbsent(
      deviceId,
      RawMidiMessageParser.new,
    );

    final List<RawMidiEvent> parsedEvents = parser.parsePacket(
      data: packet.data,
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: DateTime.now(),
    );
    for (final RawMidiEvent event in parsedEvents) {
      _eventController.add(event);
    }
  }

  void _handleDeviceConnectionState(midi.MidiConnectionState state) {
    if (_disposed) return;
    final midi.MidiDevice? platformDevice = _selectedPlatformDevice;
    if (platformDevice != null) {
      _selectedDevice = _snapshotDevice(platformDevice);
    }

    switch (state) {
      case midi.MidiConnectionState.connecting:
      case midi.MidiConnectionState.disconnecting:
        break;
      case midi.MidiConnectionState.connected:
        _setStatus(MidiInputStatus.connected);
        break;
      case midi.MidiConnectionState.disconnected:
        _setStatus(
          _devices.isEmpty
              ? MidiInputStatus.noDevicesFound
              : MidiInputStatus.disconnected,
        );
        break;
    }
  }

  void _handleStreamError(Object error) {
    _setStatus(
      MidiInputStatus.connectionError,
      error: 'MIDI stream error: $error',
    );
  }

  MidiInputDevice _snapshotDevice(midi.MidiDevice device) {
    return MidiInputDevice(
      id: device.id,
      name: device.name.isEmpty ? 'Unnamed MIDI device' : device.name,
      type: device.type.name,
      connected: device.connected,
    );
  }

  void _setStatus(MidiInputStatus status, {String? error}) {
    if (_disposed) return;
    _status = status;
    _lastError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final midi.MidiDevice? platformDevice = _selectedPlatformDevice;
    if (platformDevice != null) {
      try {
        _midiCommand.disconnectDevice(platformDevice);
      } catch (_) {
        // Disposal is best effort. Active connection errors are surfaced during
        // explicit connect/disconnect calls.
      }
    }
    final StreamSubscription<midi.MidiPacket>? packetSubscription =
        _packetSubscription;
    final StreamSubscription<midi.MidiSetupChange>? setupSubscription =
        _setupSubscription;
    final StreamSubscription<midi.MidiConnectionState>?
    deviceStateSubscription = _deviceStateSubscription;
    if (packetSubscription != null) {
      unawaited(packetSubscription.cancel());
    }
    if (setupSubscription != null) {
      unawaited(setupSubscription.cancel());
    }
    if (deviceStateSubscription != null) {
      unawaited(deviceStateSubscription.cancel());
    }
    _eventController.close();
    _midiCommand.dispose();
    super.dispose();
  }
}
