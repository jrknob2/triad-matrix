import 'dart:typed_data';

import 'package:flutter_midi_command/flutter_midi_command_messages.dart';

import 'midi_input_models.dart';

class RawMidiMessageParser {
  final MidiMessageParser _parser = MidiMessageParser();

  List<RawMidiEvent> parsePacket({
    required List<int> data,
    required String deviceId,
    required String deviceName,
    required DateTime timestamp,
  }) {
    final messages = _parser.parse(
      Uint8List.fromList(data),
      flushPendingNrpn: false,
    );
    return messages
        .map(
          (message) => _eventFromMessage(
            message,
            deviceId: deviceId,
            deviceName: deviceName,
            timestamp: timestamp,
          ),
        )
        .whereType<RawMidiEvent>()
        .toList(growable: false);
  }

  void reset() {
    _parser.reset();
  }

  RawMidiEvent? _eventFromMessage(
    MidiMessage message, {
    required String deviceId,
    required String deviceName,
    required DateTime timestamp,
  }) {
    if (message is NoteOnMessage) {
      return RawMidiEvent(
        deviceId: deviceId,
        deviceName: deviceName,
        messageType: MidiMessageType.noteOn,
        channel: message.channel + 1,
        note: message.note,
        velocity: message.velocity,
        timestamp: timestamp,
      );
    }
    if (message is NoteOffMessage) {
      return RawMidiEvent(
        deviceId: deviceId,
        deviceName: deviceName,
        messageType: MidiMessageType.noteOff,
        channel: message.channel + 1,
        note: message.note,
        velocity: message.velocity,
        timestamp: timestamp,
      );
    }
    if (message is CCMessage) {
      return RawMidiEvent(
        deviceId: deviceId,
        deviceName: deviceName,
        messageType: MidiMessageType.controlChange,
        channel: message.channel + 1,
        note: message.controller,
        velocity: message.value,
        timestamp: timestamp,
      );
    }
    return RawMidiEvent(
      deviceId: deviceId,
      deviceName: deviceName,
      messageType: MidiMessageType.other,
      channel: _channelFromRawData(message.data),
      note: _dataByte(message.data, 1),
      velocity: _dataByte(message.data, 2),
      timestamp: timestamp,
    );
  }

  int _channelFromRawData(Uint8List data) {
    if (data.isEmpty) return 0;
    final int status = data.first;
    if (status < 0x80 || status >= 0xF0) return 0;
    return (status & 0x0F) + 1;
  }

  int _dataByte(Uint8List data, int index) {
    if (index >= data.length) return -1;
    return data[index];
  }
}
