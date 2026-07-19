import '../practice/sticking_cue.dart';
import 'drum_voice_led_command_mapper.dart';
import 'led_controller_protocol.dart';
import 'midi_input_models.dart';

class LedCue {
  final DrumVoice voice;
  final StickingCue? sticking;

  const LedCue(this.voice, {this.sticking});
}

class LedFrameCommandEncoder {
  final DrumVoiceLedCommandMapper mapper;
  final StickingCue defaultSticking;

  const LedFrameCommandEncoder({
    this.mapper = const DrumVoiceLedCommandMapper(),
    this.defaultSticking = StickingCue.right,
  });

  String? encodeCueFrame(
    Iterable<LedCue> cues, {
    required LedFrameAnimation animation,
  }) {
    final List<String> lines = <String>['FRAME_BEGIN', animation.commandLine];
    for (final LedCue cue in cues) {
      final String? name = mapper.cueVoiceNameFor(cue.voice);
      if (name == null) continue;
      final StickingCue sticking = _resolvedSticking(cue);
      if (!_hasValidProtocolValue(sticking)) continue;
      lines.add('CUE,$name,${sticking.protocolValue}');
    }
    if (lines.length == 2) return null;
    lines.add('FRAME_END');
    return '${lines.join('\n')}\n';
  }

  String? encodeSolidFrame(
    Iterable<LedCue> cues, {
    int retriggerMs = LedControllerProtocolDefaults.guidedSolidRetriggerMs,
  }) {
    return encodeCueFrame(
      cues,
      animation: LedFrameAnimation.solid(retriggerMs),
    );
  }

  String? encodeFlashFrame(
    Iterable<LedCue> cues, {
    int decayMs = LedControllerProtocolDefaults.hearItFlashDecayMs,
  }) {
    return encodeCueFrame(cues, animation: LedFrameAnimation.flash(decayMs));
  }

  String? encodeFadeInFrame(
    Iterable<LedCue> cues, {
    int leadMs = LedControllerProtocolDefaults.playAlongLeadMs,
    int decayMs = LedControllerProtocolDefaults.playAlongDecayMs,
  }) {
    return encodeCueFrame(
      cues,
      animation: LedFrameAnimation.fadeIn(leadMs: leadMs, decayMs: decayMs),
    );
  }

  String? feedbackCommand(String action, LedCue cue) {
    final String? name = mapper.cueVoiceNameFor(cue.voice);
    if (name == null) return null;
    final StickingCue sticking = _resolvedSticking(cue);
    if (!_hasValidProtocolValue(sticking)) return null;
    return '$action,$name,${sticking.protocolValue}\n';
  }

  StickingCue _resolvedSticking(LedCue cue) {
    return cue.sticking ?? defaultSticking;
  }

  bool _hasValidProtocolValue(StickingCue sticking) {
    return sticking.protocolValue.isNotEmpty;
  }
}
