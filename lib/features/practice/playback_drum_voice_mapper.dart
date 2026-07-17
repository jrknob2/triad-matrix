import '../../core/practice/practice_domain_v1.dart';
import '../midi/midi_input_models.dart';

DrumVoice midiDrumVoiceForPlaybackVoice(DrumVoiceV1 voice) {
  return switch (voice) {
    DrumVoiceV1.snare => DrumVoice.snare,
    DrumVoiceV1.rackTom => DrumVoice.tom1,
    DrumVoiceV1.tom2 => DrumVoice.tom2,
    DrumVoiceV1.floorTom => DrumVoice.floorTom,
    DrumVoiceV1.hihat => DrumVoice.hiHatClosed,
    DrumVoiceV1.openHiHat => DrumVoice.hiHatOpen,
    DrumVoiceV1.crash => DrumVoice.crash,
    DrumVoiceV1.ride => DrumVoice.ride,
    DrumVoiceV1.kick => DrumVoice.kick,
  };
}

DrumVoice canonicalGuidedPracticeVoice(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.hiHatPedal => DrumVoice.hiHatClosed,
    _ => voice,
  };
}
