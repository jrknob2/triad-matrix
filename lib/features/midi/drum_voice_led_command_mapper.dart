import 'midi_input_models.dart';

class DrumVoiceLedCommandMapper {
  const DrumVoiceLedCommandMapper();

  static const String snareCommand = 'SNARE\n';

  String? voiceNameFor(DrumVoice voice) {
    return switch (voice) {
      DrumVoice.snare => 'SNARE',
      DrumVoice.kick => 'KICK',
      DrumVoice.hiHatClosed ||
      DrumVoice.hiHatOpen ||
      DrumVoice.hiHatPedal => 'HIHAT',
      DrumVoice.tom1 => 'TOM1',
      DrumVoice.tom2 => 'TOM2',
      DrumVoice.floorTom => 'FLOORTOM',
      DrumVoice.crash => 'CRASH',
      DrumVoice.ride => 'RIDE',
      DrumVoice.unknown => null,
    };
  }

  String? cueVoiceNameFor(DrumVoice voice) {
    return switch (voice) {
      DrumVoice.snare => 'SNARE',
      DrumVoice.kick => 'KICK',
      DrumVoice.hiHatClosed || DrumVoice.hiHatPedal => 'HIHAT',
      DrumVoice.hiHatOpen => 'OHH',
      DrumVoice.tom1 => 'TOM1',
      DrumVoice.tom2 => 'TOM2',
      DrumVoice.floorTom => 'FLOORTOM',
      DrumVoice.crash => 'CRASH',
      DrumVoice.ride => 'RIDE',
      DrumVoice.unknown => null,
    };
  }

  String? commandFor(DrumVoice voice) {
    final String? name = voiceNameFor(voice);
    return name == null ? null : '$name\n';
  }
}
