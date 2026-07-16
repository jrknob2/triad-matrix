import 'package:flutter/material.dart';

import '../midi/midi_diagnostic_screen.dart';

class MidiDiagnosticAppBarAction extends StatelessWidget {
  const MidiDiagnosticAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'MIDI Input Diagnostic',
      icon: const Icon(Icons.usb_rounded),
      onPressed: () => openMidiDiagnostic(context),
    );
  }
}

Future<void> openMidiDiagnostic(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MidiDiagnosticScreen()));
}
