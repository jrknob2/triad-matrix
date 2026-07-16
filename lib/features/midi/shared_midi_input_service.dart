import 'package:flutter/foundation.dart';

import 'midi_input_service.dart';

class SharedMidiInputService {
  static MidiInputService? _instance;

  SharedMidiInputService._();

  static MidiInputService get instance {
    return _instance ??= MidiInputService();
  }

  @visibleForTesting
  static void setInstanceForTesting(MidiInputService service) {
    _instance?.dispose();
    _instance = service;
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
