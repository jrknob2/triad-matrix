import 'midi_input_models.dart';

class DrumKitNoteMap {
  final String id;
  final String name;
  final Map<int, DrumVoice> notes;

  const DrumKitNoteMap({
    required this.id,
    required this.name,
    required this.notes,
  });

  static const DrumKitNoteMap generalMidiDefaults = DrumKitNoteMap(
    id: 'general-midi-starter',
    name: 'General MIDI starter map',
    notes: <int, DrumVoice>{
      36: DrumVoice.kick,
      38: DrumVoice.snare,
      40: DrumVoice.snare,
      42: DrumVoice.hiHatClosed,
      44: DrumVoice.hiHatPedal,
      46: DrumVoice.hiHatOpen,
      43: DrumVoice.floorTom,
      45: DrumVoice.tom2,
      47: DrumVoice.tom2,
      48: DrumVoice.tom1,
      49: DrumVoice.crash,
      51: DrumVoice.ride,
    },
  );
}

class DrumKitMapper {
  final DrumKitNoteMap noteMap;

  const DrumKitMapper({this.noteMap = DrumKitNoteMap.generalMidiDefaults});

  DrumInputEvent map(RawMidiEvent event) {
    return DrumInputEvent(
      voice: noteMap.notes[event.note] ?? DrumVoice.unknown,
      midiNote: event.note,
      velocity: event.velocity,
      timestamp: event.timestamp,
    );
  }
}
