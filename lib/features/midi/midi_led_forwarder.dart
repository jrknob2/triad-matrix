import 'drum_voice_led_command_mapper.dart';
import 'midi_input_models.dart';
import 'serial_led_controller.dart';

class MidiLedForwarder {
  final SerialLedController controller;
  final DrumVoiceLedCommandMapper mapper;

  bool enabled;

  MidiLedForwarder({
    required this.controller,
    this.mapper = const DrumVoiceLedCommandMapper(),
    this.enabled = false,
  });

  void handle(MidiDiagnosticEvent event) {
    if (!enabled || !controller.isConnected) return;
    if (event.raw.messageType != MidiMessageType.noteOn) return;
    if (event.raw.velocity <= 0) return;

    final String? command = mapper.commandFor(event.drum.voice);
    if (command == null) return;
    controller.sendCommand(command);
  }
}
