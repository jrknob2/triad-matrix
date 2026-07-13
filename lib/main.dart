import 'package:flutter/material.dart';

import 'features/app/app_shell.dart';
import 'features/app/drumcabulary_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DrumcabularyApp());
}

class DrumcabularyApp extends StatelessWidget {
  const DrumcabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drumcabulary',
      theme: DrumcabularyTheme.drummerEdge,
      home: const AppShell(),
    );
  }
}
