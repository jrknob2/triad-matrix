import 'package:flutter/material.dart';

import 'features/app/app_shell.dart';
import 'features/app/drumcabulary_theme.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppController controller = await AppController.create();
  runApp(DrumcabularyApp(controller: controller));
}

class DrumcabularyApp extends StatelessWidget {
  final AppController controller;

  const DrumcabularyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: 'Drumcabulary',
          theme: DrumcabularyTheme.light,
          home: AppShell(controller: controller),
        );
      },
    );
  }
}
