import 'midi_input_models.dart';

class DrumVoiceLedCommandMapper {
  const DrumVoiceLedCommandMapper();

  static const String snareCommand = 'SNARE\n';

  String? commandFor(DrumVoice voice) {
    return switch (voice) {
      DrumVoice.snare => snareCommand,
      DrumVoice.kick => 'KICK\n',
      DrumVoice.hiHatClosed ||
      DrumVoice.hiHatOpen ||
      DrumVoice.hiHatPedal => 'HIHAT\n',
      DrumVoice.tom1 => 'TOM1\n',
      DrumVoice.tom2 => 'TOM2\n',
      DrumVoice.floorTom => 'FLOORTOM\n',
      DrumVoice.crash => 'CRASH\n',
      DrumVoice.ride => 'RIDE\n',
      DrumVoice.unknown => null,
    };
  }
}
