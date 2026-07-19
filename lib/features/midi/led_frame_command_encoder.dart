import '../practice/sticking_cue.dart';
import 'drum_voice_led_command_mapper.dart';
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

  String? encodeCueFrame(Iterable<LedCue> cues) {
    final List<String> lines = <String>['FRAME_BEGIN'];
    for (final LedCue cue in cues) {
      final String? name = mapper.cueVoiceNameFor(cue.voice);
      if (name == null) continue;
      final StickingCue sticking = _resolvedSticking(cue);
      if (!_hasValidProtocolValue(sticking)) continue;
      lines.add('CUE,$name,${sticking.protocolValue}');
    }
    if (lines.length == 1) return null;
    lines.add('FRAME_END');
    return '${lines.join('\n')}\n';
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
