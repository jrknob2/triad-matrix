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
  List<MidiInputDevice> _discoveredDevices = const <MidiInputDevice>[];
  MidiInputDevice? _selectedDevice;
  midi.MidiDevice? _selectedPlatformDevice;
  MidiInputStatus _status = MidiInputStatus.disconnected;
  String? _lastError;
  int _rawPacketCount = 0;
  int _parsedEventCount = 0;
  String? _lastRawPacketHex;
  String? _lastRawPacketDeviceName;
  DateTime? _lastRawPacketAt;
  final List<String> _setupChangeLog = <String>[];
  final List<String> _pluginLog = <String>[];
  bool _started = false;
  bool _disposed = false;

  MidiInputService({midi.MidiCommand? midiCommand})
    : _midiCommand = midiCommand ?? midi.MidiCommand();

  Stream<RawMidiEvent> get events => _eventController.stream;
  List<MidiInputDevice> get devices => _devices;
  List<MidiInputDevice> get discoveredDevices => _discoveredDevices;
  MidiInputDevice? get selectedDevice => _selectedDevice;
  MidiInputStatus get status => _status;
  String? get lastError => _lastError;
  int get rawPacketCount => _rawPacketCount;
  int get parsedEventCount => _parsedEventCount;
  String? get lastRawPacketHex => _lastRawPacketHex;
  String? get lastRawPacketDeviceName => _lastRawPacketDeviceName;
  DateTime? get lastRawPacketAt => _lastRawPacketAt;
  List<String> get setupChangeLog => List.unmodifiable(_setupChangeLog);
  List<String> get pluginLog => List.unmodifiable(_pluginLog);

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _midiCommand.logHandler = _appendPluginLog;

    _midiCommand.configureBleTransport(null);
    _midiCommand.configureTransportPolicy(
      const midi.MidiTransportPolicy(
        excludedTransports: <midi.MidiTransport>{midi.MidiTransport.ble},
      ),
    );

    _setupSubscription = _midiCommand.onMidiSetupChanged?.listen(
      _handleSetupChange,
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
      _discoveredDevices = platformDevices
          .map(_snapshotDevice)
          .toList(growable: false);
      _devices =
          _discoveredDevices
              .where((device) => device.hasInputPorts)
              .toList(growable: false)
            ..sort(_compareDevices);

      final String? selectedId = _selectedDevice?.id;
      if (selectedId != null) {
        _selectedPlatformDevice =
            _devices.any((device) => device.id == selectedId)
            ? _platformDevicesById[selectedId]
            : null;
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
    if (platformDevice.inputPorts.isEmpty) {
      _setStatus(
        MidiInputStatus.connectionError,
        error: 'Device has no MIDI input ports: ${device.name}',
      );
      return;
    }

    _selectedDevice = device;
    _selectedPlatformDevice = platformDevice;
    _rawPacketCount = 0;
    _parsedEventCount = 0;
    _lastRawPacketHex = null;
    _lastRawPacketDeviceName = null;
    _lastRawPacketAt = null;
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
    _rawPacketCount += 1;
    _lastRawPacketHex = packet.data
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    _lastRawPacketDeviceName = deviceName;
    _lastRawPacketAt = DateTime.now();
    final RawMidiMessageParser parser = _parsersByDeviceId.putIfAbsent(
      deviceId,
      RawMidiMessageParser.new,
    );

    final List<RawMidiEvent> parsedEvents = parser.parsePacket(
      data: packet.data,
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: _lastRawPacketAt!,
    );
    _parsedEventCount += parsedEvents.length;
    for (final RawMidiEvent event in parsedEvents) {
      _eventController.add(event);
    }
    notifyListeners();
  }

  void _handleSetupChange(midi.MidiSetupChange change) {
    if (_disposed) return;
    final String label = '${_timeLabel(DateTime.now())} ${change.name}';
    _setupChangeLog.insert(0, label);
    if (_setupChangeLog.length > 8) {
      _setupChangeLog.removeLast();
    }
    notifyListeners();
    unawaited(scanDevices());
  }

  void _appendPluginLog(String message) {
    if (_disposed) return;
    _pluginLog.insert(0, '${_timeLabel(DateTime.now())} $message');
    if (_pluginLog.length > 10) {
      _pluginLog.removeLast();
    }
    notifyListeners();
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

  String _timeLabel(DateTime timestamp) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${two(timestamp.hour)}:${two(timestamp.minute)}:'
        '${two(timestamp.second)}.${three(timestamp.millisecond)}';
  }

  MidiInputDevice _snapshotDevice(midi.MidiDevice device) {
    return MidiInputDevice(
      id: device.id,
      name: device.name.isEmpty ? 'Unnamed MIDI device' : device.name,
      type: device.type.name,
      connected: device.connected,
      inputPortCount: device.inputPorts.length,
      outputPortCount: device.outputPorts.length,
    );
  }

  int _compareDevices(MidiInputDevice a, MidiInputDevice b) {
    if (a.isLikelyLekato != b.isLikelyLekato) {
      return a.isLikelyLekato ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
