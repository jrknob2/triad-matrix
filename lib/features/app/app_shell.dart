import 'package:flutter/material.dart';

import 'midi_diagnostic_action.dart';
import '../today/today_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach'),
        actions: const <Widget>[MidiDiagnosticAppBarAction()],
      ),
      body: const TodayScreen(),
    );
  }
}
