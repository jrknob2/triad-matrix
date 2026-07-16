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

  const LedFrameCommandEncoder({
    this.mapper = const DrumVoiceLedCommandMapper(),
  });

  String? encodeCueFrame(Iterable<LedCue> cues) {
    final List<String> lines = <String>['FRAME_BEGIN'];
    for (final LedCue cue in cues) {
      final String? name = mapper.voiceNameFor(cue.voice);
      if (name == null) continue;
      final StickingCue? sticking = cue.sticking;
      lines.add(
        sticking == null ? 'CUE,$name' : 'CUE,$name,${sticking.protocolValue}',
      );
    }
    if (lines.length == 1) return null;
    lines.add('FRAME_END');
    return '${lines.join('\n')}\n';
  }

  String? feedbackCommand(String action, LedCue cue) {
    final String? name = mapper.voiceNameFor(cue.voice);
    if (name == null) return null;
    final StickingCue? sticking = cue.sticking;
    return sticking == null
        ? '$action,$name\n'
        : '$action,$name,${sticking.protocolValue}\n';
  }
}
