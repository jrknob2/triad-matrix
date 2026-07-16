import '../../core/practice/practice_domain_v1.dart';
import '../midi/drum_voice_led_command_mapper.dart';
import '../midi/midi_input_models.dart';
import '../midi/serial_led_controller.dart';
import 'pattern_audio_service.dart';

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
    final String? command = mapper.commandFor(_midiVoiceFor(cue.voice));
    if (command == null) return;
    controller.sendCommand(command);
  }

  DrumVoice _midiVoiceFor(DrumVoiceV1 voice) {
    return switch (voice) {
      DrumVoiceV1.snare => DrumVoice.snare,
      DrumVoiceV1.rackTom => DrumVoice.tom1,
      DrumVoiceV1.tom2 => DrumVoice.tom2,
      DrumVoiceV1.floorTom => DrumVoice.floorTom,
      DrumVoiceV1.hihat => DrumVoice.hiHatClosed,
      DrumVoiceV1.crash => DrumVoice.crash,
      DrumVoiceV1.ride => DrumVoice.ride,
      DrumVoiceV1.kick => DrumVoice.kick,
    };
  }
}
