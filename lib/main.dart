import 'package:flutter/material.dart';

import 'features/practice/practice_screen.dart';

void main() {
  runApp(const TriadTrainerApp());
}

class TriadTrainerApp extends StatelessWidget {
  const TriadTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triad Trainer',
      theme: ThemeData(useMaterial3: true),
      home: const PracticeScreen(),
    );
  }
}
