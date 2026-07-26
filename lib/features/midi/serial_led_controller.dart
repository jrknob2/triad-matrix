import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'led_frame_command_encoder.dart';
import 'led_controller_protocol.dart';

enum SerialLedConnectionStatus {
  disconnected,
  connecting,
  connected,
  connectionError,
  deviceRemoved,
}

@immutable
class SerialLedSettings {
  final int baudRate;
  final int dataBits;
  final int parity;
  final int stopBits;
  final int flowControl;

  const SerialLedSettings({
    this.baudRate = 115200,
    this.dataBits = 8,
    this.parity = SerialPortParity.none,
    this.stopBits = 1,
    this.flowControl = SerialPortFlowControl.none,
  });
}

@immutable
class SerialLedPort {
  final String path;
  final String? description;
  final String? manufacturer;
  final String? productName;
  final String? serialNumber;
  final int? vendorId;
  final int? productId;

  const SerialLedPort({
    required this.path,
    this.description,
    this.manufacturer,
    this.productName,
    this.serialNumber,
    this.vendorId,
    this.productId,
  });

  String get displayName {
    final List<String> parts = <String>[
      if (_hasValue(description)) description!,
      if (_hasValue(productName) && productName != description) productName!,
      path,
    ];
    return parts.join(' | ');
  }

  static bool _hasValue(String? value) => value != null && value.isNotEmpty;
}

abstract class SerialLedPlatform {
  List<SerialLedPort> listPorts();
  SerialLedConnection openPort(SerialLedPort port, SerialLedSettings settings);
}

abstract class SerialLedConnection {
  bool get isOpen;
  Stream<Uint8List> get input;
  int write(Uint8List bytes);
  void close();
}

class LibserialportLedPlatform implements SerialLedPlatform {
  const LibserialportLedPlatform();

  @override
  List<SerialLedPort> listPorts() {
    final List<SerialLedPort> ports = <SerialLedPort>[];
    for (final String path in _availablePortPaths()) {
      SerialPort? port;
      try {
        port = SerialPort(path);
        ports.add(
          SerialLedPort(
            path: path,
            description: _readPortMetadata(() => port!.description),
            manufacturer: _readPortMetadata(() => port!.manufacturer),
            productName: _readPortMetadata(() => port!.productName),
            serialNumber: _readPortMetadata(() => port!.serialNumber),
            vendorId: _readPortMetadata(() => port!.vendorId),
            productId: _readPortMetadata(() => port!.productId),
          ),
        );
      } catch (_) {
        ports.add(SerialLedPort(path: path));
      } finally {
        try {
          port?.dispose();
        } catch (_) {
          // A transient port should not fail the whole refresh.
        }
      }
    }
    ports.sort(_comparePorts);
    return ports;
  }

  @override
  SerialLedConnection openPort(SerialLedPort port, SerialLedSettings settings) {
    final SerialPort serialPort = SerialPort(port.path);
    SerialPortConfig? config;
    bool configOwnedByPort = false;
    try {
      if (!serialPort.openReadWrite()) {
        throw SerialLedException(_lastSerialError(port.path));
      }
      config = SerialPortConfig()
        ..baudRate = settings.baudRate
        ..bits = settings.dataBits
        ..parity = settings.parity
        ..stopBits = settings.stopBits
        ..setFlowControl(settings.flowControl);
      configOwnedByPort = true;
      serialPort.config = config;
      return _LibserialportLedConnection(serialPort);
    } catch (error) {
      if (!configOwnedByPort) {
        config?.dispose();
      }
      if (serialPort.isOpen) {
        serialPort.close();
      }
      serialPort.dispose();
      throw SerialLedException(_connectionErrorMessage(port.path, error));
    }
  }

  static int _comparePorts(SerialLedPort left, SerialLedPort right) {
    final bool leftUsbModem = left.path.contains('/dev/cu.usbmodem');
    final bool rightUsbModem = right.path.contains('/dev/cu.usbmodem');
    if (leftUsbModem != rightUsbModem) {
      return leftUsbModem ? -1 : 1;
    }
    return left.path.compareTo(right.path);
  }

  static List<String> _availablePortPaths() {
    try {
      return SerialPort.availablePorts;
    } catch (error) {
      final List<String> fallbackPorts = _macOSSerialDevicePaths();
      if (fallbackPorts.isNotEmpty) return fallbackPorts;
      throw SerialLedException('Could not enumerate serial ports. $error');
    }
  }

  static List<String> _macOSSerialDevicePaths() {
    if (!io.Platform.isMacOS) return const <String>[];
    try {
      return io.Directory('/dev')
          .listSync(followLinks: false)
          .map((io.FileSystemEntity entity) => entity.path)
          .where((String path) => path.startsWith('/dev/cu.'))
          .toList();
    } catch (_) {
      return const <String>[];
    }
  }

  static T? _readPortMetadata<T>(T? Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
  }

  static String _lastSerialError(String path) {
    final Object? error = SerialPort.lastError;
    return error == null ? 'Unable to open $path.' : '$error';
  }

  static String _connectionErrorMessage(String path, Object error) {
    return 'Could not open $path at 115200 baud. Close Arduino Serial Monitor '
        'or any other app using the port, then reconnect. $error';
  }
}

class _LibserialportLedConnection implements SerialLedConnection {
  final SerialPort _port;
  late final SerialPortReader _reader;

  _LibserialportLedConnection(this._port) {
    _reader = SerialPortReader(_port);
  }

  @override
  bool get isOpen => _port.isOpen;

  @override
  Stream<Uint8List> get input => _reader.stream;

  @override
  int write(Uint8List bytes) => _port.write(bytes);

  @override
  void close() {
    _reader.close();
    if (_port.isOpen) {
      _port.close();
    }
    _port.dispose();
  }
}

class SerialLedController extends ChangeNotifier {
  static const Duration _deviceMonitorInterval = Duration(seconds: 2);

  final SerialLedPlatform _platform;
  final LedFrameCommandEncoder _frameEncoder;
  final SerialLedSettings settings;

  List<SerialLedPort> _ports = const <SerialLedPort>[];
  SerialLedPort? _selectedPort;
  SerialLedConnection? _connection;
  StreamSubscription<Uint8List>? _responseSubscription;
  String _responseBuffer = '';
  SerialLedConnectionStatus _status = SerialLedConnectionStatus.disconnected;
  String? _lastError;
  Map<LedControllerVoice, LedOrientation> _orientations =
      const <LedControllerVoice, LedOrientation>{};
  Set<LedControllerVoice> _pendingOrientations = const <LedControllerVoice>{};
  String? _controllerSettingsError;
  Timer? _deviceMonitorTimer;
  bool _disposed = false;

  SerialLedController({
    SerialLedPlatform platform = const LibserialportLedPlatform(),
    LedFrameCommandEncoder frameEncoder = const LedFrameCommandEncoder(),
    this.settings = const SerialLedSettings(),
  }) : _platform = platform,
       _frameEncoder = frameEncoder;

  List<SerialLedPort> get ports => List.unmodifiable(_ports);
  SerialLedPort? get selectedPort => _selectedPort;
  SerialLedConnectionStatus get status => _status;
  String? get lastError => _lastError;
  Map<LedControllerVoice, LedOrientation> get orientations =>
      Map<LedControllerVoice, LedOrientation>.unmodifiable(_orientations);
  Set<LedControllerVoice> get pendingOrientations =>
      Set<LedControllerVoice>.unmodifiable(_pendingOrientations);
  String? get controllerSettingsError => _controllerSettingsError;
  bool get isConnected =>
      _status == SerialLedConnectionStatus.connected &&
      (_connection?.isOpen ?? false);

  Future<void> refreshPorts() async {
    if (_disposed) return;
    final bool wasConnected = isConnected;
    try {
      final List<SerialLedPort> nextPorts = _platform.listPorts();
      if (_disposed) return;
      _ports = nextPorts;
      final SerialLedPort? selected = _selectedPort;
      if (selected != null &&
          !_ports.any((port) => port.path == selected.path)) {
        if (isConnected) {
          _markDeviceRemoved();
          return;
        } else {
          _selectedPort = null;
        }
      }
      if (_status == SerialLedConnectionStatus.connectionError ||
          _status == SerialLedConnectionStatus.deviceRemoved) {
        _status = SerialLedConnectionStatus.disconnected;
      }
      _lastError = null;
      notifyListeners();
    } catch (error) {
      if (wasConnected && !_disposed) {
        _lastError =
            'Serial port refresh failed: $error. Keeping the current LED connection active.';
        notifyListeners();
        return;
      }
      _setStatus(
        SerialLedConnectionStatus.connectionError,
        error: 'Serial port refresh failed: $error',
      );
    }
  }

  void selectPort(String? path) {
    if (_disposed || isConnected) return;
    _selectedPort = path == null ? null : _portForPath(path);
    _lastError = null;
    notifyListeners();
  }

  Future<void> selectPortAndConnect(String? path) async {
    if (_disposed || isConnected) return;
    selectPort(path);
    if (_selectedPort == null) return;
    await connect();
  }

  Future<void> connect() async {
    if (_disposed || isConnected) return;
    final SerialLedPort? port = _selectedPort;
    if (port == null) {
      _setStatus(
        SerialLedConnectionStatus.connectionError,
        error: 'Select a serial port before connecting.',
      );
      return;
    }

    _setStatus(SerialLedConnectionStatus.connecting);
    try {
      _connection = _platform.openPort(port, settings);
      if (_disposed) {
        _closeConnection();
        return;
      }
      _listenToControllerResponses(_connection!);
      _setStatus(SerialLedConnectionStatus.connected);
      _startDeviceMonitor();
      requestOrientations();
    } catch (error) {
      _closeConnection();
      _setStatus(SerialLedConnectionStatus.connectionError, error: '$error');
    }
  }

  Future<void> disconnect() async {
    if (_disposed) return;
    _stopDeviceMonitor();
    _closeConnection();
    _setStatus(SerialLedConnectionStatus.disconnected);
  }

  void sendCommand(String command) {
    final String normalized = command.endsWith('\n') ? command : '$command\n';
    if (_isCueFrame(normalized)) {
      _logLedFrame(normalized);
    }
    _sendPayload(normalized);
  }

  void sendCueFrame(
    Iterable<LedCue> cues, {
    required LedFrameAnimation animation,
  }) {
    final String? frame = _frameEncoder.encodeCueFrame(
      cues,
      animation: animation,
    );
    _sendEncodedFrame(frame);
  }

  void sendSolidFrame(
    Iterable<LedCue> cues, {
    int retriggerMs = LedControllerProtocolDefaults.guidedSolidRetriggerMs,
  }) {
    _sendEncodedFrame(
      _frameEncoder.encodeSolidFrame(cues, retriggerMs: retriggerMs),
    );
  }

  void sendFlashFrame(
    Iterable<LedCue> cues, {
    int decayMs = LedControllerProtocolDefaults.hearItFlashDecayMs,
  }) {
    _sendEncodedFrame(_frameEncoder.encodeFlashFrame(cues, decayMs: decayMs));
  }

  void sendFadeInFrame(
    Iterable<LedCue> cues, {
    int leadMs = LedControllerProtocolDefaults.playAlongLeadMs,
    int decayMs = LedControllerProtocolDefaults.playAlongDecayMs,
  }) {
    _sendEncodedFrame(
      _frameEncoder.encodeFadeInFrame(cues, leadMs: leadMs, decayMs: decayMs),
    );
  }

  void _sendEncodedFrame(String? frame) {
    if (frame == null) {
      if (kDebugMode) {
        debugPrint('LED frame skipped: no valid cue commands.');
      }
      return;
    }
    _logLedFrame(frame);
    _sendPayload(frame);
  }

  void requestOrientations({LedControllerVoice? voice}) {
    if (_disposed || !isConnected) return;
    _controllerSettingsError = null;
    sendCommand(buildGetOrientationCommand(voice));
  }

  void setOrientation(LedControllerVoice voice, LedOrientation orientation) {
    if (_disposed || !isConnected) return;
    _controllerSettingsError = null;
    _pendingOrientations = <LedControllerVoice>{..._pendingOrientations, voice};
    notifyListeners();
    sendCommand(buildSetOrientationCommand(voice, orientation));
    if (!isConnected) {
      _pendingOrientations = <LedControllerVoice>{..._pendingOrientations}
        ..remove(voice);
      notifyListeners();
    }
  }

  void resetOrientations({LedControllerVoice? voice}) {
    if (_disposed || !isConnected) return;
    _controllerSettingsError = null;
    _pendingOrientations = voice == null
        ? LedControllerVoice.values.toSet()
        : <LedControllerVoice>{..._pendingOrientations, voice};
    notifyListeners();
    sendCommand(buildResetOrientationCommand(voice));
    if (!isConnected) {
      _pendingOrientations = <LedControllerVoice>{};
      notifyListeners();
    }
  }

  void _sendPayload(String payload) {
    if (!isConnected) return;
    final SerialLedConnection connection = _connection!;
    final Uint8List bytes = Uint8List.fromList(utf8.encode(payload));

    try {
      final int written = connection.write(bytes);
      if (written != bytes.length) {
        throw SerialLedException(
          'Only wrote $written of ${bytes.length} bytes.',
        );
      }
    } catch (error) {
      _closeConnection();
      _setStatus(
        SerialLedConnectionStatus.connectionError,
        error: 'Serial write failed: $error',
      );
    }
  }

  void _logLedFrame(String frame) {
    if (!kDebugMode) return;
    debugPrint('LED frame:\n${frame.trimRight()}');
  }

  bool _isCueFrame(String payload) {
    return payload.startsWith('FRAME_BEGIN\n') &&
        payload.contains('\nANIMATION,') &&
        payload.contains('\nFRAME_END\n');
  }

  void _listenToControllerResponses(SerialLedConnection connection) {
    unawaited(_responseSubscription?.cancel());
    _responseBuffer = '';
    _responseSubscription = connection.input.listen(
      _handleControllerBytes,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('LED controller read failed: $error\n$stackTrace');
        }
      },
      cancelOnError: false,
    );
  }

  void _handleControllerBytes(Uint8List bytes) {
    if (_disposed) return;
    _responseBuffer += utf8.decode(bytes, allowMalformed: true);
    while (true) {
      final int newline = _responseBuffer.indexOf('\n');
      if (newline < 0) return;
      final String line = _responseBuffer.substring(0, newline).trim();
      _responseBuffer = _responseBuffer.substring(newline + 1);
      if (line.isEmpty) continue;
      _handleControllerResponse(parseLedControllerResponse(line));
    }
  }

  void _handleControllerResponse(LedControllerResponse response) {
    switch (response) {
      case LedAnimationAckResponse():
        if (kDebugMode) {
          final String phase = response.frameCommitted
              ? 'frame committed'
              : 'animation accepted';
          debugPrint(
            'LED controller $phase: ${response.animation.commandLine}',
          );
        }
      case LedOrientationValueResponse():
        _orientations = <LedControllerVoice, LedOrientation>{
          ..._orientations,
          response.voice: response.orientation,
        };
        _pendingOrientations = <LedControllerVoice>{..._pendingOrientations}
          ..remove(response.voice);
        _controllerSettingsError = null;
        notifyListeners();
      case LedOrientationResetResponse():
        if (response.all) {
          _orientations = const <LedControllerVoice, LedOrientation>{};
          _pendingOrientations = const <LedControllerVoice>{};
        } else {
          _orientations = <LedControllerVoice, LedOrientation>{..._orientations}
            ..remove(response.voice);
          _pendingOrientations = <LedControllerVoice>{..._pendingOrientations}
            ..remove(response.voice);
        }
        _controllerSettingsError = null;
        notifyListeners();
        requestOrientations(voice: response.voice);
      case LedControllerErrorResponse():
        _controllerSettingsError = response.detail.isEmpty
            ? 'Controller error: ${response.code}'
            : 'Controller error: ${response.code}: ${response.detail}';
        if (kDebugMode) {
          debugPrint(_controllerSettingsError);
        }
        notifyListeners();
      case LedControllerUnknownResponse():
        if (kDebugMode) {
          debugPrint('LED controller response: ${response.line}');
        }
    }
  }

  void _startDeviceMonitor() {
    _stopDeviceMonitor();
    _deviceMonitorTimer = Timer.periodic(_deviceMonitorInterval, (_) {
      if (_disposed || !isConnected) return;
      final SerialLedPort? selected = _selectedPort;
      if (selected == null) return;
      try {
        final bool stillPresent = _platform.listPorts().any(
          (SerialLedPort port) => port.path == selected.path,
        );
        if (!stillPresent) {
          _markDeviceRemoved();
        }
      } catch (_) {
        // Active writes surface serial errors. Monitoring stays best effort so
        // it cannot break MIDI input or pattern capture.
      }
    });
  }

  void _stopDeviceMonitor() {
    _deviceMonitorTimer?.cancel();
    _deviceMonitorTimer = null;
  }

  void _markDeviceRemoved() {
    _stopDeviceMonitor();
    _closeConnection();
    _setStatus(
      SerialLedConnectionStatus.deviceRemoved,
      error:
          'Serial device removed. Reconnect the ESP32, refresh, and connect again.',
    );
  }

  SerialLedPort? _portForPath(String path) {
    for (final SerialLedPort port in _ports) {
      if (port.path == path) return port;
    }
    return null;
  }

  void _closeConnection() {
    unawaited(_responseSubscription?.cancel());
    _responseSubscription = null;
    _responseBuffer = '';
    _pendingOrientations = const <LedControllerVoice>{};
    final SerialLedConnection? connection = _connection;
    _connection = null;
    if (connection == null) return;
    try {
      connection.close();
    } catch (_) {
      // Explicit connection errors are surfaced during connect and write.
    }
  }

  void _setStatus(SerialLedConnectionStatus status, {String? error}) {
    if (_disposed) return;
    _status = status;
    _lastError = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopDeviceMonitor();
    _closeConnection();
    super.dispose();
  }
}

class SerialLedException implements Exception {
  final String message;

  const SerialLedException(this.message);

  @override
  String toString() => message;
}
