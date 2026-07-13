import 'package:flutter/material.dart';

import '../midi/midi_diagnostic_screen.dart';
import '../today/today_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach'),
        actions: <Widget>[
          IconButton(
            tooltip: 'MIDI Input Diagnostic',
            icon: const Icon(Icons.usb_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MidiDiagnosticScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const TodayScreen(),
    );
  }
}
