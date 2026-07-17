import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
import '../settings/app_settings_screen.dart';
import '../today/today_screen.dart';
import 'startup_splash_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Future<AppController> _controllerFuture = AppController.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _controllerFuture,
      builder: (BuildContext context, AsyncSnapshot<AppController> snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Coach')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load app settings: ${snapshot.error}'),
              ),
            ),
          );
        }
        final AppController? controller = snapshot.data;
        if (controller == null) {
          return const StartupSplashScreen();
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Coach'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppSettingsScreen(controller: controller),
                  ),
                ),
              ),
            ],
          ),
          body: const TodayScreen(),
        );
      },
    );
  }
}
