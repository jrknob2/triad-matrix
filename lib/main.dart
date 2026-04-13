import 'package:flutter/material.dart';

import 'features/app/app_shell.dart';
import 'features/app/drumcabulary_theme.dart';
import 'features/app/startup_splash_screen.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DrumcabularyApp());
}

class DrumcabularyApp extends StatefulWidget {
  const DrumcabularyApp({super.key});

  @override
  State<DrumcabularyApp> createState() => _DrumcabularyAppState();
}

class _DrumcabularyAppState extends State<DrumcabularyApp> {
  late final Future<AppController> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _createControllerWithSplashDelay();
  }

  Future<AppController> _createControllerWithSplashDelay() async {
    final Future<AppController> controllerFuture = AppController.create();
    await Future.wait<void>(<Future<void>>[
      Future<void>.delayed(const Duration(seconds: 3)),
      controllerFuture.then((_) {}),
    ]);
    return controllerFuture;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drumcabulary',
      theme: DrumcabularyTheme.light,
      home: FutureBuilder<AppController>(
        future: _startupFuture,
        builder: (BuildContext context, AsyncSnapshot<AppController> snapshot) {
          final AppController? controller = snapshot.data;
          if (controller == null) {
            return const StartupSplashScreen();
          }
          return AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, _) {
              return AppShell(controller: controller);
            },
          );
        },
      ),
    );
  }
}
