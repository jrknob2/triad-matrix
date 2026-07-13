enum MidiMessageType { noteOn, noteOff, controlChange, other }

enum DrumVoice {
  snare,
  kick,
  hiHatClosed,
  hiHatOpen,
  hiHatPedal,
  tom1,
  tom2,
  floorTom,
  crash,
  ride,
  unknown,
}

enum MidiInputStatus {
  scanning,
  noDevicesFound,
  disconnected,
  connecting,
  connected,
  connectionError,
}

class MidiInputDevice {
  final String id;
  final String name;
  final String type;
  final bool connected;

  const MidiInputDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.connected,
  });

  bool get isLikelyLekato => name.toLowerCase().contains('edrum');
}

class RawMidiEvent {
  final String deviceId;
  final String deviceName;
  final MidiMessageType messageType;
  final int channel;
  final int note;
  final int velocity;
  final DateTime timestamp;

  const RawMidiEvent({
    required this.deviceId,
    required this.deviceName,
    required this.messageType,
    required this.channel,
    required this.note,
    required this.velocity,
    required this.timestamp,
  });
}

class DrumInputEvent {
  final DrumVoice voice;
  final int midiNote;
  final int velocity;
  final DateTime timestamp;

  const DrumInputEvent({
    required this.voice,
    required this.midiNote,
    required this.velocity,
    required this.timestamp,
  });
}

class MidiDiagnosticEvent {
  final RawMidiEvent raw;
  final DrumInputEvent drum;

  const MidiDiagnosticEvent({required this.raw, required this.drum});
}
