import 'package:flutter/material.dart';

import 'features/app/app_shell.dart';
import 'state/app_controller.dart';

void main() {
  runApp(const TriadTrainerApp());
}

class TriadTrainerApp extends StatefulWidget {
  const TriadTrainerApp({super.key});

  @override
  State<TriadTrainerApp> createState() => _TriadTrainerAppState();
}

class _TriadTrainerAppState extends State<TriadTrainerApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Triad Trainer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF194B7A)),
      ),
      home: AppShell(controller: _controller),
    );
  }
}
