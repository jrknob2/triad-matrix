import 'package:flutter/material.dart';

import 'features/app/app_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppController controller = await AppController.create();
  runApp(TriadTrainerApp(controller: controller));
}

class TriadTrainerApp extends StatelessWidget {
  final AppController controller;

  const TriadTrainerApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: 'Triad Trainer',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF194B7A),
            ),
          ),
          home: controller.onboardingComplete
              ? AppShell(controller: controller)
              : OnboardingScreen(controller: controller),
        );
      },
    );
  }
}
