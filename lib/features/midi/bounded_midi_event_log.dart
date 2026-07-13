import 'midi_input_models.dart';

class BoundedMidiEventLog {
  final int maxEntries;
  final List<MidiDiagnosticEvent> _events = <MidiDiagnosticEvent>[];

  BoundedMidiEventLog({this.maxEntries = 100}) {
    if (maxEntries <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive.');
    }
  }

  List<MidiDiagnosticEvent> get events => List.unmodifiable(_events);

  void add(MidiDiagnosticEvent event) {
    _events.add(event);
    while (_events.length > maxEntries) {
      _events.removeAt(0);
    }
  }

  void clear() {
    _events.clear();
  }
}
