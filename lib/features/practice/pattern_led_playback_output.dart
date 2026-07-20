import '../midi/led_frame_command_encoder.dart';
import '../midi/led_controller_protocol.dart';
import '../midi/serial_led_controller.dart';
import 'pattern_audio_service.dart';
import 'playback_drum_voice_mapper.dart';

typedef PatternLedPlaybackEnabled = bool Function();

bool _enabledByDefault() => true;

enum PatternLedPlaybackPresentation { hearIt, playAlong }

class PatternLedPlaybackOutput implements PatternPlaybackCueOutputV1 {
  final SerialLedController controller;
  final PatternLedPlaybackEnabled isEnabled;
  final PatternLedPlaybackPresentation presentation;
  final Duration playAlongLeadTime;
  final int playAlongDecayMs;
  final int hearItDecayMs;

  const PatternLedPlaybackOutput({
    required this.controller,
    this.isEnabled = _enabledByDefault,
    this.presentation = PatternLedPlaybackPresentation.hearIt,
    this.playAlongLeadTime = const Duration(
      milliseconds: LedControllerProtocolDefaults.playAlongLeadMs,
    ),
    this.playAlongDecayMs = LedControllerProtocolDefaults.playAlongDecayMs,
    this.hearItDecayMs = LedControllerProtocolDefaults.hearItFlashDecayMs,
  });

  @override
  Duration get leadTime {
    if (!isEnabled() ||
        presentation != PatternLedPlaybackPresentation.playAlong) {
      return Duration.zero;
    }
    return playAlongLeadTime;
  }

  @override
  bool get gatesPlaybackStart => false;

  @override
  void start(PatternAudioPlanV1 plan, {Duration phase = Duration.zero}) {}

  @override
  Future<void> waitForStartCueGroup(List<PatternAudioCueV1> cues) async {}

  @override
  void triggerCue(PatternAudioCueV1 cue) {
    triggerCueGroup(<PatternAudioCueV1>[cue]);
  }

  @override
  void triggerCueGroup(List<PatternAudioCueV1> cues) {
    if (!isEnabled() || !controller.isConnected) return;
    if (presentation == PatternLedPlaybackPresentation.playAlong) return;
    controller.sendFlashFrame(_ledCuesFor(cues), decayMs: hearItDecayMs);
  }

  @override
  void triggerLeadCueGroup(List<PatternAudioCueV1> cues) {
    if (!isEnabled() ||
        !controller.isConnected ||
        presentation != PatternLedPlaybackPresentation.playAlong) {
      return;
    }
    controller.sendFadeInFrame(
      _ledCuesFor(cues),
      leadMs: playAlongLeadTime.inMilliseconds,
      decayMs: playAlongDecayMs,
    );
  }

  Iterable<LedCue> _ledCuesFor(List<PatternAudioCueV1> cues) {
    return <LedCue>[
      for (final PatternAudioCueV1 cue in cues)
        LedCue(
          midiDrumVoiceForPlaybackVoice(cue.voice),
          sticking: cue.sticking,
        ),
    ];
  }

  @override
  void stop() {
    if (!controller.isConnected) return;
    controller.sendCommand(ledClearCommand);
  }
}
