import 'package:flutter/material.dart';

import 'core/practice/practice_domain_v1.dart';
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
  late final Future<AppController> _controllerFuture = AppController.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppController>(
      future: _controllerFuture,
      builder: (BuildContext context, AsyncSnapshot<AppController> snapshot) {
        final AppController? controller = snapshot.data;
        if (controller == null) {
          return _buildMaterialApp(
            profile: UserProfileV1.initial,
            home: snapshot.hasError
                ? _StartupError(error: snapshot.error)
                : const StartupSplashScreen(),
          );
        }

        return AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, _) {
            return _buildMaterialApp(
              profile: controller.profile,
              home: AppShell(controller: controller),
            );
          },
        );
      },
    );
  }

  Widget _buildMaterialApp({
    required UserProfileV1 profile,
    required Widget home,
  }) {
    final Brightness resolvedBrightness = _resolvedBrightness(
      profile.themeMode,
    );
    final Color accentColor = Color(profile.accentColorValue);
    DrumcabularyTheme.configureRuntime(
      brightness: resolvedBrightness,
      accentColor: accentColor,
    );

    return MaterialApp(
      title: 'Drumcabulary',
      theme: DrumcabularyTheme.light,
      darkTheme: DrumcabularyTheme.drummerEdge,
      themeMode: _materialThemeMode(profile.themeMode),
      home: home,
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object? error;

  const _StartupError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coach')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load app settings: $error'),
        ),
      ),
    );
  }
}

Brightness _resolvedBrightness(AppThemeModeV1 mode) {
  return switch (mode) {
    AppThemeModeV1.light => Brightness.light,
    AppThemeModeV1.dark => Brightness.dark,
  };
}

ThemeMode _materialThemeMode(AppThemeModeV1 mode) {
  return switch (mode) {
    AppThemeModeV1.light => ThemeMode.light,
    AppThemeModeV1.dark => ThemeMode.dark,
  };
}
