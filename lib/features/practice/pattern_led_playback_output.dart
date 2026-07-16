import '../midi/led_frame_command_encoder.dart';
import '../midi/serial_led_controller.dart';
import 'pattern_audio_service.dart';
import 'playback_drum_voice_mapper.dart';

typedef PatternLedPlaybackEnabled = bool Function();

bool _enabledByDefault() => true;

class PatternLedPlaybackOutput implements PatternPlaybackCueOutputV1 {
  final SerialLedController controller;
  final PatternLedPlaybackEnabled isEnabled;

  const PatternLedPlaybackOutput({
    required this.controller,
    this.isEnabled = _enabledByDefault,
  });

  @override
  void triggerCue(PatternAudioCueV1 cue) {
    triggerCueGroup(<PatternAudioCueV1>[cue]);
  }

  @override
  void triggerCueGroup(List<PatternAudioCueV1> cues) {
    if (!isEnabled() || !controller.isConnected) return;
    controller.sendCueFrame(<LedCue>[
      for (final PatternAudioCueV1 cue in cues)
        LedCue(
          midiDrumVoiceForPlaybackVoice(cue.voice),
          sticking: cue.sticking,
        ),
    ]);
  }

  @override
  void stop() {
    if (!isEnabled() || !controller.isConnected) return;
    controller.sendCommand('CLEAR\n');
  }
}
