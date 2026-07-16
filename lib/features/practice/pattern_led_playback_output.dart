import '../midi/drum_voice_led_command_mapper.dart';
import '../midi/serial_led_controller.dart';
import 'pattern_audio_service.dart';
import 'playback_drum_voice_mapper.dart';

typedef PatternLedPlaybackEnabled = bool Function();

bool _enabledByDefault() => true;

class PatternLedPlaybackOutput implements PatternPlaybackCueOutputV1 {
  final SerialLedController controller;
  final DrumVoiceLedCommandMapper mapper;
  final PatternLedPlaybackEnabled isEnabled;

  const PatternLedPlaybackOutput({
    required this.controller,
    this.mapper = const DrumVoiceLedCommandMapper(),
    this.isEnabled = _enabledByDefault,
  });

  @override
  void triggerCue(PatternAudioCueV1 cue) {
    if (!isEnabled() || !controller.isConnected) return;
    final String? command = mapper.commandFor(
      midiDrumVoiceForPlaybackVoice(cue.voice),
    );
    if (command == null) return;
    controller.sendCommand(command);
  }
}
